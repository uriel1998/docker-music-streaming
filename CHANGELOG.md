# Changelog

## 2026-03-20

### Step 1
- Reworked `.gitignore` around the actual project layout instead of hiding reference artifacts and instruction files.
- Kept `1_reference/` and `INSTRUCTIONS.txt` available as local migration source material while excluding them from the final project history.
- Added ignore coverage for local env files, runtime state, media, playlists, and common editor/build noise.
- Confirmed there were no currently tracked media or env files that needed to be removed from version control in this step.
