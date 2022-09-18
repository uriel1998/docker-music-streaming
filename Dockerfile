FROM debian:buster-slim
MAINTAINER Steven Saus (steven@faithcollapsing.com)

ARG ROMPR_VERSION=1.33
ENV DEBIAN_FRONTEND noninteractive

# Install packages
RUN apt-get update -y && \
    apt-get install -y curl mpd mpdscribble mpc detox snapclient wc bc \
    nginx php7.4-fpm php7.4-mysql php7.4-curl php7.4-gd php7.4-common unzip imagemagick \
    php7.4-json php7.4-xml php7.4-mbstring php7.4-sqlite3 icecast && \
    rm -rf /var/lib/apt/lists/*

RUN curl -k -L -o rompr.zip https://github.com/fatg3erman/RompR/releases/download/${ROMPR_VERSION}/rompr-${ROMPR_VERSION}.zip
RUN mkdir -p /app
RUN unzip -d /app rompr.zip && rm rompr.zip
RUN mkdir /app/rompr/prefs
RUN mkdir /app/rompr/albumart
RUN chown -R www-data:www-data /app/rompr
COPY nginx_default /etc/nginx/sites-available/default
RUN mkdir -p /run/php/
#Environment variables to configure php
RUN sed -ri -e  's/^allow_url_fopen =.*/allow_url_fopen = On/g' /etc/php/7.4/fpm/php.ini
RUN sed -ri -e  's/^memory_limit =.*/memory_limit = 128M/g' /etc/php/7.4/fpm/php.ini
RUN sed -ri -e  's/^max_execution_time =.*/max_execution_time = 1800/g' /etc/php/7.4/fpm/php.ini
RUN sed -ri -e  's/^post_max_size =.*/post_max_size = 256M/g' /etc/php/7.4/fpm/php.ini
RUN sed -ri -e  's/^upload_max_filesize =.*/upload_max_filesize = 8M/g' /etc/php/7.4/fpm/php.ini
RUN sed -ri -e  's/^max_file_uploads =.*/max_file_uploads = 50/g' /etc/php/7.4/fpm/php.ini
RUN sed -ri -e  's/^display_errors =.*/display_errors = On/g' /etc/php/7.4/fpm/php.ini
RUN sed -ri -e  's/^display_startup_errors =.*/display_startup_errors = On/g' /etc/php/7.4/fpm/php.ini

RUN echo "<?php phpinfo(); ?>" > /app/rompr/phpinfo.php
RUN update-rc.d php7.4-fpm defaults
COPY run-httpd /usr/local/bin/
RUN chmod 755 /usr/local/bin/run-httpd
EXPOSE 80
CMD ["/usr/local/bin/run-httpd"]

# build with 
# docker build -t docker-pulsesms .
# run with
# docker run -d docker-pulsesms
# docker ps
# docker kill 8defbf68cc79
# docker run -it docker-pulsesms /bin/bash
# will pull in various config files, then at runtime for dyn conversion
# in fact, maybe have a startpoint to check for those and recreate them out
# of the container a la like what roundcube did.
# docker run -d 
#-it 
#--name container 
#--mount type=bind,source=/nginxconfig,target=/etc/nginx 
