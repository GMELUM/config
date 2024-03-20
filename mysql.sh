#!/bin/sh

MYSQL_USER="$1"
MYSQL_PASSWORD="$2"
MYSQL_DATABASE="$3"

AWS_ENDPOINT="$4"
AWS_REGION="$5"
AWS_SECRET_ACCESS_KEY="$6"
AWS_ACCESS_KEY_ID="$7"
AWS_BUCKET="$8"

INTERVAL="$9"

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

apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

mkdir -p /root/mysql
mkdir -p /root/mysql/volume

echo "Create docker-compose script"
{
    echo "version: '3.8'"
    echo ""
    echo "services:"
    echo ""
    echo "  mysql:"
    echo "    image: mysql:latest"
    echo "    container_name: mysql"
    echo "    restart: always"
    echo "    environment:"
    echo "      MYSQL_ROOT_PASSWORD: $MYSQL_PASSWORD"
    echo "      MYSQL_DATABASE: $MYSQL_DATABASE"
    echo "      MYSQL_USER: $MYSQL_USER"
    echo "      MYSQL_PASSWORD: $MYSQL_PASSWORD"
    echo "      MYSQL_ROOT_HOST: \"%\""
    echo "    ports:"
    echo "      - "3306:3306""
    echo "    expose:"
    echo "      - 3306"
    echo "    volumes:"
    echo "      - /root/mysql/volume:/var/lib/mysql"
    echo "    command:"
    echo "      ["
    echo "        \"--bind-address=0.0.0.0\","
    echo "        \"--max_connections=1000\","
    echo "        \"--log_bin_trust_function_creators=1\""
    echo "      ]"
    echo ""
    echo "  mysql-master-backup:"
    echo "    image: databack/mysql-backup"
    echo "    container_name: mysql-backup"
    echo "    restart: always"
    echo "    environment:"
    echo "      SINGLE_DATABASE: true"
    echo "      DB_SERVER: mysql"
    echo "      DB_PORT: 3306"
    echo "      DB_USER: root"
    echo "      DB_PASS: $MYSQL_PASSWORD"
    echo "      DB_NAMES: $MYSQL_DATABASE"
    echo "      DB_DUMP_FREQ: $INTERVAL"
    echo "      DB_DUMP_TARGET: \"s3://$AWS_BUCKET/dumps/$MYSQL_DATABASE\""
    echo "      AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID"
    echo "      AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY"
    echo "      AWS_REGION: $AWS_REGION"
    echo "      AWS_ENDPOINT_URL: $AWS_ENDPOINT"
    echo "      COMPRESSION: bzip2"
    echo "    command: dump"
} > ~/docker-compose.yaml

echo "Start script"
docker compose up -d
