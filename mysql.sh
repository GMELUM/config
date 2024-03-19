#!/bin/sh

MYSQL_USER="$1"
MYSQL_PASSWORD="$2"
MYSQL_DATABASE="$3"

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Create docker-compose script"
{
    echo "version: '3.8'"
    echo ""
    echo "services:"
    echo ""
    echo "  mysql:"
    echo "    image: mysql:latest"
    echo "    restart: always"
    echo "    environment:"
    echo "      MYSQL_ROOT_PASSWORD: $MYSQL_PASSWORD"
    echo "      MYSQL_DATABASE: $MYSQL_DATABASE"
    echo "      MYSQL_USER: $MYSQL_USER"
    echo "      MYSQL_PASSWORD: $MYSQL_PASSWORD"
    echo "    ports:"
    echo "      - "3306:3306""
    echo "    volumes:"
    echo "      - /root/mysql/volume:/var/lib/mysql"
    echo "    command:"
    echo "      - \"--max_connections=500\""
    echo "      - \"--bind-address=0.0.0.0\""
} > /root/mysql

echo "Start mysql"
cd /root/mysql
docker-compose up -d