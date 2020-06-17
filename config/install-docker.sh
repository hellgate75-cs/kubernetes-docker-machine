#!/bin/sh
apt-get update && \
apt-get install -y sudo curl
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common &&\
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update &&\
sudo apt-get install -y docker-ce docker-ce-cli containerd.io &&\
apt-get autoremove && rm -rf /var/lib/apt/lists/*
docker version
DOCKER_PATH="$(dirname "$(which docker)")"
ln -s $DOCKER_PATH/system-docker $(which docker)