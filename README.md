# docker-music-streaming


I've written a couple of guides on how to get whole-house audio and streaming 
by using `mpd`, `snapcast`, and other FOSS projects. I've previously described 
it as a [weekend project](https://ideatrash.net/2021/08/further-adventures-in-whole-house-audio.html), but by using Docker, it's a trivial setup.

Included are:

- [mpd](https://www.musicpd.org/) for music playing and remote streaming
- [snapcast](https://github.com/badaix/snapcast) (and snapweb) for whole-house streaming
- [mpdscribble](https://www.musicpd.org/clients/mpdscribble/) for scrobbling to last.fm / libre.fm
- [minidlna](https://sourceforge.net/p/minidlna/wiki/Home/) for upnp serving
- [RompR web interface](https://fatg3erman.github.io/RompR/) (for controlling the whole thing)
- Nginx proxy fragment
- music directory and configurations accessible from host (at least at spinup)


## Contents
 1. [About](#1-about)
 2. [License](#2-license)
 3. [Prerequisites](#3-prerequisites)
 4. [Installation](#4-Installation)
 5. [Notes](#5-Notes)

***

## 1. About

This is intended to be dropped behind a reverse proxy. Setting up docker, 
docker-compose, and the reverse proxy is beyond the scope of this document. 
Likewise, handling SSL certificates should be done at the level of the host.

Many, *many* thanks to [Toward Data Science](https://towardsdatascience.com/run-multiple-services-in-single-docker-container-using-supervisor-b2ed53e3d1c0) whose post pointed me to how to get several things running 
together.

## 2. License

This project is licensed under the Apache License. For the full license, see `LICENSE`.

## 3. Prerequisites

Docker and docker-compose

If you have `minidlna` running on the host, you cannot *also* have it running 
in the container due to port conflicts.

## 4. Installation

1. Clone or download this repository.

2. Change into the directory you put these files into. Create a symbolic link to 
your already existing music directory (no need to move it!) by typing 

`ln -s /path/to/mymusic ./music`

substituting `/path/to/mymusic` with the path to your music collection.

3. *Optional* Add your last.fm / libre.fm login for `mpdscribble` in 
`config/mpdscribble.conf`.

4. *Optional* If you wish to change the password for MPD, it's in `config/mpd.conf`. By default, 
it is set to `mycomplicatedpassword`. If you change the password, you will also 
have to change it for `mpdscribble` and each of the `run-*` scripts in  `./build`. 

5. Bring up the container with `docker-compose up -d --build`. Get a drink or 
stretch or something, it'll take a while. 

6. Point your browser at `http://localhost:8880` **Note that it is http, not httpS.** You should see RompR's main interface. Click the gear icon, then click `Edit Players`. 

![Edit Players](https://raw.githubusercontent.com/uriel1998/docker-music-streaming/master/setup1.png "Click the gear, then edit player")

Then add the password - by default, `mycomplicatedpassword` - to the password field.

![Add Password](https://raw.githubusercontent.com/uriel1998/docker-music-streaming/master/setup2.png "Add password")

Then click the blinking "Update Music Collection Now" button. Stretch again. Avoid 
repetitive stress injuries. Also, if you have a large collection, this may take a 
**while**.

7. At this point you should have a fully-functional installation. You get to 
RompR by pointing your browser at `http://localhost:8880`. You can access the stream at 
`http://localhost:8881` with pretty much anything that can handle MP3s. Snapcast should 
auto-discover using avahi, and you can access the Snapweb interface at `http://localhost:1780`.

8. *Optional-ish* Change the relevant proxy port for the reverse proxy to 8880, and for the stream to 8881. The specifics  will vary depending on what your reverse proxy is. For 
example, if you're using nginx, the relevant *portion* of the config should look something like this:

```
server {
    server_name example.com;
    location /mpd.mp3 {
        proxy_pass http://localhost:8881;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Host $host;     
    }
    location / {
        proxy_pass http://192.168.1.101:8880;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Host $host;
    }
}
```

## 5. Notes

* There are several d-bus mounts that are required for avahi to talk to the 
rest of the network outside the Docker container. [This is pretty much the only 
way](https://stackoverflow.com/questions/30646943/how-to-avahi-browse-from-a-docker-container) (without installing additional software outside the container) to get avahi 
to work.

* This repository contains a prebuilt version of [snapweb](https://github.com/badaix/snapweb),
because the Debian package apparently does *not* contain it by default, and making it from source requires TypeScript, which requires NPM, and man, these images are *already* too 
big... but if you don't trust my build, or want to substitute one of your own, 
literally just replace `build/snapweb` with what you build yourself.

* You *may* need to bring the container down and then back up to get it to 
recognize changes to the music directory on the host.

* This Docker image is *UNOPTIMIZED*. I'm sure it pulls in *way* more than is 
actually needed, but my focus here was getting a MVP that worked essentially out 
of the box.
