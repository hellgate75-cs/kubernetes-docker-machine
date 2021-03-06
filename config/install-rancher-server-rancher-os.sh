#!/bin/sh
sudo sh -c "echo \"docker run --rm curlimages/curl \$ @\" > /usr/bin/curl && chmod +x /usr/bin/curl && sed -i 's/$ @/\\\$@/g' /usr/bin/curl && curl --help "

docker rm -f rancher-data 2>&1 > /dev/null
docker volume rm rancher_server_my_sql_data 2>&1 > /dev/null
docker volume rm rancher_server_my_sql_log 2>&1 > /dev/null
docker volume rm rancher_server_cattle 2>&1 > /dev/null
docker volume create rancher_server_my_sql_data 2>&1 > /dev/null
docker volume create rancher_server_my_sql_log 2>&1 > /dev/null
docker volume create rancher_server_cattle 2>&1 > /dev/null
docker create -v rancher_server_my_sql_data:/var/lib/mysql -v rancher_server_my_sql_log:/var/log/mysql -v rancher_server_cattle:/var/lib/cattle --name rancher-data rancher/server:latest 2>&1 > /dev/null
docker run --cidfile=/home/docker/.rancher-cid -d --restart=unless-stopped --volumes-from rancher-data -p 8080:8080 -p 8081:8081 -p 8088:8088 -p 9345:9345 -p 9000:9000 -p 3306:3306 -it --user root:root --privileged --name rancher-server rancher/server:latest
#sudo sh -c "echo \"docker run --rm curlimages/curl \$ @\" > /usr/bin/curl && chmod +x /usr/bin/curl && sed -i 's/$ @/\\\$@/g' /usr/bin/curl && curl --help "
