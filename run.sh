#!/bin/bash

##############################################################################
#
# If for some reason you don't want to use docker-compose, you can use this to
# run the image by itself.
#
############################################################################## 

docker run -it -p 8180:80 --mount type=bind,source=$PWD/apache-sites,target=/etc/apache2/sites-available --mount type=bind,source=$PWD/www,target=/var/www local/apache2_php7_4  
