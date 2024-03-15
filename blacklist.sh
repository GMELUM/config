#!/bin/sh

USERNAME="$1"
PASSWORD="$2"
HOST="$3"
PORT="$4"

echo "Updating packages..."
apt update
apt upgrade -y

echo "Install lua-nginx-redis"
apt install nginx-extras lua-nginx-redis -y

if $PORT == "" then
    $PORT = 6379;
end

echo "Add blacklist lua script"
{
echo "local ip_blacklist             = ngx.shared.ip_blacklist;"
echo "local last_update_time         = ip_blacklist:get("last_update_time");"
echo ""
echo "if last_update_time == nil or last_update_time < ( ngx.now() - 60 ) then"
echo ""
echo "  local redis = require "nginx.redis";"
echo "  local red = redis:new();"
echo ""
echo "  red:set_timeout(redis_connect_timeout);"
echo ""
echo "  local ok, err = red:connect($HOST, $PORT);"
echo "  if not ok then"
echo "  else"
echo "    local ok, err = red:auth($USERNAME, $PASSWORD)"
echo "    if not ok then"
echo "    else"
echo "      local new_ip_blacklist, err = red:smembers("ip_blacklist");"
echo "      if err then"
echo "      else"
echo "        ip_blacklist:flush_all();"
echo "        for index, banned_ip in ipairs(new_ip_blacklist) do"
echo "          ip_blacklist:set(banned_ip, true);"
echo "        end"
echo "        ip_blacklist:set("last_update_time", ngx.now());"
echo "    end"
echo "    end"
echo "  end"
echo "end"
echo ""
echo "if ip_blacklist:get(ngx.var.remote_addr) then"
echo "  ngx.status = 200;"
echo "  ngx.header.content_type = \"application/json; charset=utf-8\";"
echo "  return ngx.print(\"{\\\"error\\\":{\\\"code\\\":0,\\\"message\\\":\\\"Forbidden\\\"}}\");"
echo "end"
echo ""
} > /etc/nginx/lua/ip-blacklist.lua
