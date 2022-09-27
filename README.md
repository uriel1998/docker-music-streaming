# docker-apache2-php7_4

A way to get php7.4 running by using a Docker container as a proxy that *should* 
be able to drop in behind your reverse proxy with (potentially) as little 
configuration as moving a configuration file, making a symbolic link, and 
typing `docker-compose up -d --build`.

## Contents
 1. [About](#1-about)
 2. [License](#2-license)
 3. [Prerequisites](#3-prerequisites)
 4. [Installation](#4-Installation)
 5. [Notes](#5-Notes)

***

## 1. About

I was not prepared to have something like half the web applications I have 
running on my home lab to pooch it when Debian upgraded PHP from 7.4 to 8.1. 

Yes, I was running a lot of them on "bare metal" - that is, they were not 
inside containers.

While I was able to find either upgraded versions or replacement programs, I 
realized there had to be another way that would just let me get a bunch of 
those web applications back up and running quickly.

Most of those sites were already running behind a reverse proxy anyway. So, I 
asked myself, what if I learned how to run Apache and PHP 7.4 inside *Docker*, 
and allowed my "main" bare metal setup to follow Debian's upgrade path? 

This is the result.

The container, which is based on Debian bullseye-slim, will load any sites 
configured in the `apache-sites` subdirectory, and serve files in the `www` 
subdirectory. It is accessible on port 8180 by default.

## 2. License

This project is licensed under the Apache License. For the full license, see `LICENSE`.

## 3. Prerequisites

This setup is *explicitly* meant to be run behind a reverse proxy, on a LAN that 
has a firewall at the router level. **Particularly** if you hook into the databases 
you had been running on the host.

Handling things like certificates should be done at the level of your reverse 
proxy.

Obviously, you need Docker. 

## 4. Installation

1. Clone or download this repository.

2. Move (from an existing Apache installation) or create configuration files for
each of the websites to serve into the subdirectory `apache-sites`. 

3. Make sure each of the Virtual Hosts is listening on *port 80*, e.g. `<VirtualHost *:80>`.

4. Put the contents of the websites into the subdirectory `www`. Symbolic links 
*should* work. The subdirectory `www` will be equivalent to `/var/www` inside the 
container.

5. Examine the tweaks to php.ini and modules loaded in Apache in `/build/run_httpd.sh`. 
If you wish to change these after the initial build, you will need to re-build 
the image (`docker-compose up --build -d`) instead of just bringing it up.

6. Bring up the container with `docker-compose up -d --build`. If you want to be 
difficult on yourself, see the `build.sh` and `run.sh` scripts.

7. Change the relevant proxy port for the reverse proxy to 8180. The specifics 
will vary depending on what your reverse proxy is. For example, if you're using 
nginx, the relevant *portion* of the config should look something like this:

```
   location / {
   include errorpages.conf;
   proxy_pass http://192.168.1.101:8180;
   proxy_set_header X-Real-IP $remote_addr;
   proxy_set_header Host $host;
   }
```

## 5. Notes

* Add additional mounts (e.g. for a music directory, and so on) to docker-compose.yaml
as needed. For example, to mount /media/music to /var/music inside the container, 
add the line `      - ./media/music:/var/music/` at the bottom of `docker-compose.yaml.`

* Note that you will probably have to change ownership on the served directories
(or at least some of them) to www-data:www-data (or 33:33), which is the UID/GID for 
apache on debian

* You may wish to also chmod to 6777 to preserve GID/UID of files written there.
chmod g+s ./ 

* If you need to change the sites that are served, you will need to bring the 
container down and back up again. There is no need to re-build the image in 
order to add or remove sites served by the container.

* It is very likely that you will need to change the permissions for the `www` 
subdirectory to be owned by `www-data`, which is the user for Apache in Debian. The 
UID and GID for user `www-data` are `33`, so you can set the permissions by 
typing 

`sudo chown -R 33:33 /the/full/path/to/www`

### Connecting to MySQL (and presumably other databases) On The Host

There are several steps you will need to take in order to let web applications 
talk to a database server running on the host. 

* Firewall - make sure your firewall allows from the docker IP ranges as well. Those 
are usually 172.*.*.*/16. You can find out the IP address of a running Docker 
process through `docker inspect [container ID] | grep IPAddress`. The less 
secure way - but significantly easier - is to allow access to port 3306 
(e.g., `sudo ufw allow in to any port 3306`) while blocking port access at 
your router's firewall.

* If you're connecting to an existing database on the host, make sure the 
*DATABASE* permissions allow for the user to not be on "localhost". Note the '%' 
modifier, e.g. 

```
CREATE USER 'myuser'@'%' IDENTIFIED BY 'mycomplicatedpassword';
GRANT ALL PRIVILEGES ON mydb.* TO 'myuser'@'%';
```

* Note that you may have to change the addresses that MySQL will bind to as well, 
following these instructions from [StackOverflow](https://stackoverflow.com/questions/16287559/mysql-adding-user-for-remote-access#37341046).
