#!/bin/sh

USER_NAME="server"
USER_HOMEDIR="/home/server"
USER_SHELL="/bin/bash"
USER_SSH_KEY="$1"

EMAIL="$2"
DOMAIN="$3"
SUBDOMAIN="$4"
IP_PEER_SECONDS="100"
PEER_SECONDS="20000r/s"
BURST_PEER_SECONDS="40000"
PROXY="http://localhost:18300/"
GOLANG_VERSION="1.21.3"

echo "Updating packages..."
apt update
apt upgrade -y

echo "Remove Print log..."
echo "" > /etc/motd

echo "Created user..."
useradd -m -d $USER_HOMEDIR -s $USER_SHELL -p "" $USER_NAME

echo "Configure user..."
mkdir -p $USER_HOMEDIR/.ssh
echo $USER_SSH_KEY >> $USER_HOMEDIR/.ssh/authorized_keys
chmod 700 $USER_HOMEDIR/.ssh
chmod 600 $USER_HOMEDIR/.ssh/authorized_keys
chown -R $USER_NAME:$USER_NAME $USER_HOMEDIR/.ssh

echo "Configuring SSH..."
sed -i 's/^PermitRootLogin.*/PermitRootLogin without-password/g' /etc/ssh/sshd_config
sed -i 's/#? *PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#? *ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#? *UsePAM .*/UsePAM no/' /etc/ssh/sshd_config
sed -i 's/#? *PrintLastLog .*/PrintLastLog no/' /etc/ssh/sshd_config

echo "Configuring network..."
sysctl -w net.ipv4.tcp_syncookies=1
sysctl -w net.ipv4.tcp_max_syn_backlog=40000
sysctl -w net.ipv4.tcp_synack_retries=1
sysctl -w net.ipv4.tcp_fin_timeout=30
sysctl -w net.ipv4.tcp_keepalive_probes=5
sysctl -w net.ipv4.tcp_keepalive_intvl=15
sysctl -w net.core.netdev_max_backlog=20000
sysctl -w net.core.somaxconn=20000

echo "Configuring iptables v4..."
iptables -N syn_flood
iptables -A INPUT -p tcp --syn -j syn_flood
iptables -A syn_flood -m limit --limit 500/s --limit-burst 2000 -j RETURN
iptables -A syn_flood -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
iptables -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
iptables -A INPUT -p tcp --tcp-flags ACK,FIN FIN -j DROP
iptables -A INPUT -p tcp --iptables-flags ACK,PSH PSH -j DROP
iptables -A INPUT -p tcp --tcp-flags ACK,URG URG -j DROP
iptables -A INPUT -p tcp --dport 21 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p icmp -j DROP
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -j DROP
iptables-save >/etc/iptables/rules.v4

echo "Configuring iptables v6..."
ip6tables -A INPUT -j DROP
ip6tables -A FORWARD -j DROP
ip6tables-save >/etc/iptables/rules.v6

echo "Installing Curl..."
apt install curl -y

echo "Install Snapd..."
apt install snapd -y

echo "Installing Nginx..."
apt install nginx -y

echo "Installing Certbot..."
add-apt-repository ppa:certbot/certbot -y
apt-get update
apt install python-certbot-nginx -y

echo "Installing Git..."
apt install git-all -y

echo "Installing Golang..."
curl -O https://dl.google.com/go/go$GOLANG_VERSION.linux-amd64.tar.gz
tar xvf go$GOLANG_VERSION.linux-amd64.tar.gz
chown -R root:root ./go
mv go /usr/local
echo "export GOPATH=$HOME/work" >>~/.profile
echo "export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin" >>~/.profile
source ~/.profile

echo "Cloning Nginx configuration files..."
rm -rf /etc/nginx
git clone https://github.com/GMELUM/vps.nginx.conf /etc/nginx

echo "Creating Nginx configuration file..."
echo "limit_conn_zone \$binary_remote_addr zone=addr:10m;" >/etc/nginx/domains/$DOMAIN.conf
echo "limit_conn addr $IP_PEER_SECONDS;" >>/etc/nginx/domains/$DOMAIN.conf
echo "limit_req_zone \$binary_remote_addr zone=req_limit:10m rate=$PEER_SECONDS;" >>/etc/nginx/domains/$DOMAIN.conf
echo "limit_req zone=req_limit burst=$BURST_PEER_SECONDS;" >>/etc/nginx/domains/$DOMAIN.conf
echo "server {" >>/etc/nginx/domains/$DOMAIN.conf
echo "  listen 80;" >>/etc/nginx/domains/$DOMAIN.conf
echo "  server_name $SUBDOMAIN"."$DOMAIN;" >>/etc/nginx/domains/$DOMAIN.conf
echo "  location / {" >>/etc/nginx/domains/$DOMAIN.conf
echo "    proxy_pass $PROXY;" >>/etc/nginx/domains/$DOMAIN.conf
echo " }" >>/etc/nginx/domains/$DOMAIN.conf
echo "}" >>/etc/nginx/domains/$DOMAIN.conf

echo "Start Nginx..."
systemctl start nginx

echo "Chekout DNS"
while true; do
    result=$(dig +short $SUBDOMAIN"."$DOMAIN)
    current_ip=$(wget -O - -q icanhazip.com)

    match=0
    for ip in $result; do
        if [ $ip = $current_ip ]; then
            match=1
            break
        fi
    done

    if [ $match = 1 ]; then
        break
    fi

    echo "The corresponding DNS record could not be found. Checked again in 10 seconds..."
    sleep 10
done

echo "Creating ssl certificate with Certbot..."
certbot --nginx -n -d $SUBDOMAIN"."$DOMAIN

echo "Restart Nginx..."
systemctl restart nginx

echo "Creating cron file..."
echo "15 3 * * * /usr/bin/certbot renew --quiet" >/etc/cron.d/letsencrypt_renew
chown root:root /etc/cron.d/letsencrypt_renew
chmod 0644 /etc/cron.d/letsencrypt_renew

systemctl restart sshd
