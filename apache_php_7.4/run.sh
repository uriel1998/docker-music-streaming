#docker build -t local/apache2_php7_4 .

# make logfile directory if does not exist
if [ ! -d "${PWD}/logs" ];then
    mkdir -p "${PWD}/logs"
fi

docker run -it -p 8080:80 --mount type=bind,source=$PWD/apache-sites,target=/etc/apache2/sites-available --mount type=bind,source=$PWD/www,target=/var/www  --mount type=bind,source=$PWD/logs,target=/var/log/apache2/ local/apache2_php7_4  
