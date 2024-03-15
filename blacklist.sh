#!/bin/sh

HOST="$1"

echo "Updating packages..."
apt update
apt upgrade -y

echo "Install lua-nginx-redis"
apt install nginx-extras lua-nginx-redis -y

echo "Add blacklist lua script"
{
    echo "local redis_host               = \"$HOST\";"
    echo "local redis_port               = 6379;"
    echo "local redis_connection_timeout = 100;"
    echo "local redis_key                = \"ip_blacklist\";"
    echo "local cache_ttl                = 60;"
    echo "local ip                       = ngx.var.remote_addr;"
    echo "local ip_blacklist             = ngx.shared.ip_blacklist;"
    echo "local last_update_time         = ip_blacklist:get(\"last_update_time\");"
    echo ""
    echo "if last_update_time == nil or last_update_time < ( ngx.now() - cache_ttl ) then"
    echo "  local redis = require \"nginx.redis\";"
    echo "  local red = redis:new();"
    echo "  red:set_timeout(redis_connect_timeout);"
    echo "  local ok, err = red:connect(redis_host, redis_port);"
    echo "  if not ok then"
    echo "    ngx.log(ngx.DEBUG, \"Redis connection error while retrieving ip_blacklist: \" .. err);"
    echo "  else"
    echo "    local new_ip_blacklist, err = red:smembers(redis_key);"
    echo "    if err then"
    echo "      ngx.log(ngx.DEBUG, \"Redis read error while retrieving ip_blacklist: \" .. err);"
    echo "    else"
    echo "      ip_blacklist:flush_all();"
    echo "      for index, banned_ip in ipairs(new_ip_blacklist) do"
    echo "        ip_blacklist:set(banned_ip, true);"
    echo "      end"
    echo "      ip_blacklist:set(\"last_update_time\", ngx.now());"
    echo "    end"
    echo "  end"
    echo "end"
    echo ""
    echo "if ip_blacklist:get(ip) then"
    echo "  ngx.log(ngx.DEBUG, \"Banned IP detected and refused access: \" .. ip);"
    echo "  ngx.status = 200;"
    echo "  ngx.header.content_type = \"application/json; charset=utf-8\";"
    echo "  return ngx.print(\"{\"error\":{\"code\":0,\"message\":\\\"Forbidden\\\"}}\");"
    echo "end"
} > /etc/nginx/lua/ip-blacklist.lua