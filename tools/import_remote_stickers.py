#!/usr/bin/env python3
"""Import selected MPD stickers from a remote MPD into the local Docker MPD.

The remote endpoint is given as ``password@host[:port]`` or ``host[:port]``.
Local connection defaults are read from the repository ``.env`` file next to
``compose.yaml`` unless overridden on the command line:

- ``MUSICSTACK_MPD_PASSWORD`` for the local MPD password
- ``MPD_CONTROL_PORT`` for the published local MPD port

Only these sticker names are imported:

- ``bpm``
- ``lastPlayed``
- ``lastSkipped``
- ``playCount``
- ``skipCount``

Remote ``playcount`` is normalized to local ``playCount``. If both
``playcount`` and ``playCount`` exist remotely, the larger value wins.
"""

from __future__ import annotations

import argparse
import sys
import socket
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple


class MPDError(RuntimeError):
    pass


@dataclass
class Endpoint:
    host: str
    port: int
    password: Optional[str]


def parse_dotenv(path: Path) -> Dict[str, str]:
    values: Dict[str, str] = {}
    if not path.exists():
        return values

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def find_default_dotenv() -> Path:
    script_path = Path(__file__).resolve()
    repo_root = script_path.parent.parent
    return repo_root / ".env"


def parse_remote_target(value: str, default_port: int) -> Endpoint:
    password: Optional[str] = None
    hostport = value
    if "@" in value:
        password, hostport = value.split("@", 1)

    if not hostport:
        raise ValueError("remote target is missing host")

    host = hostport
    port = default_port
    if ":" in hostport:
        host, raw_port = hostport.rsplit(":", 1)
        if not raw_port:
            raise ValueError("remote target has an empty port")
        port = int(raw_port)

    if not host:
        raise ValueError("remote target is missing host")

    return Endpoint(host=host, port=port, password=password or None)


def mpd_quote(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


class MPDClient:
    def __init__(self, endpoint: Endpoint, timeout: float = 30.0) -> None:
        self.endpoint = endpoint
        self.timeout = timeout
        self.sock: Optional[socket.socket] = None
        self.reader = None
        self.writer = None

    def __enter__(self) -> "MPDClient":
        self.sock = socket.create_connection(
            (self.endpoint.host, self.endpoint.port), timeout=self.timeout
        )
        self.reader = self.sock.makefile("r", encoding="utf-8", newline="\n")
        self.writer = self.sock.makefile("w", encoding="utf-8", newline="\n")
        greeting = self.reader.readline().rstrip("\n")
        if not greeting.startswith("OK MPD "):
            raise MPDError(f"unexpected MPD greeting: {greeting!r}")
        if self.endpoint.password:
            self.command(f"password {mpd_quote(self.endpoint.password)}")
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        try:
            if self.writer is not None:
                self.writer.close()
            if self.reader is not None:
                self.reader.close()
        finally:
            if self.sock is not None:
                self.sock.close()

    def command(self, line: str) -> List[str]:
        if self.writer is None or self.reader is None:
            raise MPDError("MPD connection is not open")

        self.writer.write(line)
        self.writer.write("\n")
        self.writer.flush()

        output: List[str] = []
        while True:
            response = self.reader.readline()
            if response == "":
                raise MPDError("unexpected EOF from MPD")
            response = response.rstrip("\n")
            if response == "OK":
                return output
            if response.startswith("ACK "):
                raise MPDError(response)
            output.append(response)

    def sticker_find(self, name: str) -> Dict[str, str]:
        lines = self.command(f"sticker find song {mpd_quote('')} {mpd_quote(name)}")
        results: Dict[str, str] = {}
        current_file: Optional[str] = None
        prefix = f"{name}="
        for line in lines:
            if line.startswith("file: "):
                current_file = line[6:]
            elif current_file and line.startswith("sticker: "):
                payload = line[9:]
                if payload.startswith(prefix):
                    results[current_file] = payload[len(prefix) :]
        return results

    def sticker_set(self, uri: str, name: str, value: str) -> None:
        self.command(
            " ".join(
                [
                    "sticker",
                    "set",
                    "song",
                    mpd_quote(uri),
                    mpd_quote(name),
                    mpd_quote(value),
                ]
            )
        )

    def sticker_delete(self, uri: str, name: str) -> None:
        try:
            self.command(
                " ".join(
                    ["sticker", "delete", "song", mpd_quote(uri), mpd_quote(name)]
                )
            )
        except MPDError as exc:
            if "no such sticker" not in str(exc).lower():
                raise


def numeric_value(value: str) -> Optional[float]:
    try:
        return float(value)
    except ValueError:
        return None


def choose_playcount(values: Iterable[str]) -> str:
    chosen: Optional[str] = None
    chosen_numeric: Optional[float] = None

    for value in values:
        if chosen is None:
            chosen = value
            chosen_numeric = numeric_value(value)
            continue

        value_numeric = numeric_value(value)
        if value_numeric is not None and chosen_numeric is not None:
            if value_numeric > chosen_numeric:
                chosen = value
                chosen_numeric = value_numeric
            continue

        if value_numeric is not None and chosen_numeric is None:
            chosen = value
            chosen_numeric = value_numeric
            continue

        if value_numeric is None and chosen_numeric is None and value > chosen:
            chosen = value

    if chosen is None:
        raise ValueError("no playCount candidates were provided")
    return chosen


def collect_remote_stickers(remote: MPDClient) -> Dict[str, Dict[str, str]]:
    grouped: Dict[str, Dict[str, str]] = defaultdict(dict)
    for key in ("bpm", "lastPlayed", "lastSkipped", "playCount", "playcount", "skipCount"):
        for uri, value in remote.sticker_find(key).items():
            grouped[uri][key] = value

    normalized: Dict[str, Dict[str, str]] = {}
    for uri, stickers in grouped.items():
        result: Dict[str, str] = {}
        for key in ("bpm", "lastPlayed", "lastSkipped", "skipCount"):
            if key in stickers:
                result[key] = stickers[key]

        playcount_candidates = [
            stickers[key] for key in ("playCount", "playcount") if key in stickers
        ]
        if playcount_candidates:
            result["playCount"] = choose_playcount(playcount_candidates)

        if result:
            normalized[uri] = result

    return normalized


def import_stickers(
    local: MPDClient,
    remote_data: Dict[str, Dict[str, str]],
    dry_run: bool,
) -> Tuple[int, int]:
    imported = 0
    failed = 0

    total = len(remote_data)

    def render_progress(current: int) -> None:
        if total == 0:
            return
        width = 32
        filled = int(width * current / total)
        bar = "#" * filled + "-" * (width - filled)
        print(
            f"\r[{bar}] {current}/{total} songs",
            end="",
            file=sys.stderr,
            flush=True,
        )

    for index, uri in enumerate(sorted(remote_data), start=1):
        stickers = remote_data[uri]
        try:
            if "playCount" in stickers and not dry_run:
                local.sticker_delete(uri, "playcount")

            for key, value in stickers.items():
                if dry_run:
                    print(f"would set {uri!r} {key}={value!r}")
                else:
                    local.sticker_set(uri, key, value)
            imported += 1
        except MPDError as exc:
            failed += 1
            print(f"failed for {uri!r}: {exc}")
        finally:
            render_progress(index)

    if total:
        print(file=sys.stderr)

    return imported, failed


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Copy selected stickers from a remote MPD into the local Docker MPD."
        ),
        epilog=(
            "Examples:\n"
            "  python3 tools/import_remote_stickers.py 'secret@old-mpd-host'\n"
            "  python3 tools/import_remote_stickers.py 'secret@old-mpd-host:6601' --dry-run\n"
            "  python3 tools/import_remote_stickers.py 'old-mpd-host' --local-port 6600"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "remote_target",
        help="Remote MPD in the form password@host[:port] or host[:port]",
    )
    parser.add_argument(
        "--local-host",
        default="127.0.0.1",
        help="Host for the local Docker MPD service (default: 127.0.0.1)",
    )
    parser.add_argument(
        "--local-port",
        type=int,
        help="Port for the local Docker MPD service (default: from .env MPD_CONTROL_PORT or 6600)",
    )
    parser.add_argument(
        "--local-password",
        help="Password for the local Docker MPD service (default: from .env MUSICSTACK_MPD_PASSWORD)",
    )
    parser.add_argument(
        "--remote-port",
        type=int,
        default=6600,
        help="Default remote MPD port when the positional target omits one (default: 6600)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the sticker writes without changing the local MPD",
    )
    parser.add_argument(
        "--dotenv",
        default=str(find_default_dotenv()),
        help="Path to the .env file for local MPD defaults (default: repo .env)",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    dotenv = parse_dotenv(Path(args.dotenv))
    local_port = args.local_port or int(dotenv.get("MPD_CONTROL_PORT", "6600"))
    local_password = args.local_password
    if local_password is None:
        local_password = dotenv.get("MUSICSTACK_MPD_PASSWORD") or None

    remote_endpoint = parse_remote_target(args.remote_target, args.remote_port)
    local_endpoint = Endpoint(
        host=args.local_host,
        port=local_port,
        password=local_password,
    )

    with MPDClient(remote_endpoint) as remote, MPDClient(local_endpoint) as local:
        remote_data = collect_remote_stickers(remote)
        imported, failed = import_stickers(local, remote_data, args.dry_run)

    print(
        f"processed {len(remote_data)} songs with matching stickers; "
        f"imported={imported}, failed={failed}"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
