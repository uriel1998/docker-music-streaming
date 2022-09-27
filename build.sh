#!/bin/bash

##############################################################################
#
# If for some reason you don't want to use docker-compose, you can use this to
# build the docker image by itself.
#
############################################################################## 

docker build -t local/apache2_php7_4 .
