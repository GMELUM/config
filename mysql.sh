#!/bin/sh

MYSQL_USER="$1"
MYSQL_PASSWORD="$2"
MYSQL_DATABASE="$3"

sudo apt-get update
sudo apt-get install aptitude -y
sudo aptitude update
sudo aptitude install -y \
    ca-certificates \
    curl \
    gnupg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg
sudo chmod a+r /usr/share/keyrings/docker.gpg
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo aptitude update
sudo aptitude install -y docker-ce docker-ce-cli containerd.io

# Add the current user to the docker group
sudo groupadd docker
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify the installation
docker --version
docker compose --version

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