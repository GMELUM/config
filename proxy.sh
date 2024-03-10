#!/bin/sh

EMAIL="$1"
DOMAIN="$2"

echo "Running the proxy setup script..."

echo "Updating packages..."
apt update
apt upgrade -y

echo "Configuring SSH..."
sed -i 's/^PermitRootLogin.*/PermitRootLogin without-password/g' /etc/ssh/sshd_config
sed -i 's/#? *PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#? *ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#? *UsePAM .*/UsePAM no/' /etc/ssh/sshd_config
sed -i 's/#? *PrintLastLog .*/PrintLastLog no/' /etc/ssh/sshd_config

echo "Install Dig"
apt install dnsutils -y

echo "Installing Curl..."
apt install curl -y

echo "Installing Nginx..."
apt install nginx -y

echo "Install plugin nginx..."
apt install libnginx-mod-stream

echo "Installing Certbot..."
add-apt-repository ppa:certbot/certbot -y
apt-get update
apt install certbot python3-certbot-nginx -y

echo "Install iptables..."
apt install iptables -y
mkdir -p /etc/iptables/

echo "Configuring network..."
sysctl -w net.ipv4.icmp_echo_ignore_all = 1
sysctl -w net.ipv4.tcp_syncookies=1
sysctl -w net.ipv4.tcp_max_syn_backlog=40000
sysctl -w net.ipv4.tcp_synack_retries=1
sysctl -w net.ipv4.tcp_fin_timeout=30
sysctl -w net.ipv4.tcp_keepalive_probes=5
sysctl -w net.ipv4.tcp_keepalive_intvl=15
sysctl -w net.core.netdev_max_backlog=20000
sysctl -w net.core.somaxconn=20000

echo "Configuring iptables v4..."
iptables -F
iptables -X

iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

iptables -N syn_flood
iptables -N port-scanning

iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
iptables -A INPUT -p tcp ! --tcp-flags FIN,SYN,RST,ACK SYN -m conntrack --ctstate NEW -j DROP
iptables -A INPUT -p tcp -m conntrack --ctstate NEW -m tcpmss ! --mss 536:65535 -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,RST FIN,RST -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,ACK FIN -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags ACK,URG URG -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,ACK FIN -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags PSH,ACK PSH -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG FIN,SYN,RST,PSH,ACK,URG -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG FIN,PSH,URG -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG FIN,SYN,PSH,URG -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG FIN,SYN,RST,ACK,URG -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -m multiport --dports 80,443 -m connlimit --connlimit-above 30 --connlimit-mask 32 --connlimit-saddr -j DROP

iptables -A port-scanning -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK RST -m limit --limit 1/sec --limit-burst 2 -j RETURN
iptables -A port-scanning -j DROP

iptables-save >/etc/iptables/rules.v4

echo "Configuring iptables v6..."
ip6tables -A INPUT -j DROP
ip6tables -A FORWARD -j DROP

ip6tables-save >/etc/iptables/rules.v6

echo "Update Nginx configuration file..."
{
    echo "user www-data;"
    echo "worker_processes auto;"
    echo "pid /run/nginx.pid;"
    echo ""
    echo "include /etc/nginx/modules-enabled/*;"
    echo ""
    echo "events {"
    echo "	worker_connections 768;"
    echo "}"
    echo ""
    echo "stream {"
    echo "  include /etc/nginx/stream/*.conf;"
    echo "}"
    echo ""
    echo "http {"
    echo "  charset utf-8;"
    echo "  include mime.types;"
    echo "  default_type application/octet-stream;"
    echo "  sendfile on;"
    echo "  sendfile_max_chunk 5m;"
    echo "  ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;"
    echo "  ssl_prefer_server_ciphers on;"
    echo "  resolver 1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4;"
    echo "  client_body_timeout 5s;"
    echo "  client_header_timeout 5s;"
    echo "  client_max_body_size 5m;"
    echo "  tcp_nopush on;"
    echo "  tcp_nodelay on;"
    echo "  access_log off;"
    echo "  types_hash_bucket_size 64;"
    echo "  types_hash_max_size 4096;"
    echo "  server_tokens off;"
    echo "  gzip off;"
    echo "  keepalive_timeout 30;"
    echo "  send_timeout 2;"
    echo "  reset_timedout_connection on;"
    echo "  proxy_buffering off;"
    echo "  include /etc/nginx/sites-enabled/*;"
    echo "}"
} >/etc/nginx/nginx.conf

echo "Update default Nginx configuration file..."
{
    echo "server {"
    echo "  listen 80;"
    echo "  server_name _;"
    echo "  location ^~ /.well-known/acme-challenge/ {"
    echo "      default_type "text/plain";"
    echo "      root         /var/www/html;"
    echo "      break;"
    echo "  }"
    echo "  location = /.well-known/acme-challenge/ {"
    echo "      return 404;"
    echo "  }"
    echo "  location / {"
    echo "    return 301 https://\$host\$request_uri;"
    echo "  }"
    echo "}"
} >/etc/nginx/sites-enabled/default

echo "Creating Nginx configuration file..."
{
    echo "server {"
    echo "  listen 80;"
    echo "  server_name $DOMAIN;"
    echo "}"
} >/etc/nginx/sites-enabled/$DOMAIN.conf

echo "Start Nginx..."
systemctl start nginx

echo "Chekout DNS"
while true; do
    result=$(dig +short $DOMAIN)
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
certbot certonly --nginx  -n -d $DOMAIN --agree-tos --email $EMAIL

echo "Update Nginx configuration file..."
{
    echo "limit_conn_zone \$binary_remote_addr zone=conn_user:10m;"
    echo "limit_conn_zone \$server_name zone=conn_global:10m;"
    echo ""
    echo "limit_req_zone \$binary_remote_addr zone=req_user:10m rate=50r/s;"
    echo "limit_req_zone \$server_name zone=req_global:10m rate=20000r/s;"
    echo ""
    echo "server {"
    echo "  listen 80;"
    echo "  server_name $DOMAIN;"
    echo ""
    echo "  if (\$host = $DOMAIN) {"
    echo "    return 301 https://\$host\$request_uri;"
    echo "  }"
    echo ""
    echo "  return 404;"
    echo "}"
    echo ""
    echo "server {"
    echo "  listen 443 ssl;"
    echo "  server_name $DOMAIN;"
    echo ""
    echo "  ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;"
    echo "  ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;"
    echo "  include /etc/letsencrypt/options-ssl-nginx.conf;"
    echo "  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;"
    echo ""
    echo "  limit_conn conn_user 10;"
    echo "  limit_conn conn_global 20000;"
    echo ""
    echo "  limit_req zone=req_user burst=100;"
    echo "  limit_req zone=req_global burst=40000;"
    echo ""
    echo "  location / {"
    echo "  }"
    echo ""
    echo "}"
} >/etc/nginx/sites-enabled/$DOMAIN.conf

echo "Restart Nginx..."
systemctl restart nginx

echo "Creating cron file..."
echo "15 3 * * * /usr/bin/certbot renew --quiet" >/etc/cron.d/letsencrypt_renew
chown root:root /etc/cron.d/letsencrypt_renew
chmod 0644 /etc/cron.d/letsencrypt_renew

systemctl restart sshd