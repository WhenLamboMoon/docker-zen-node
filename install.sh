#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

print_status() {
    echo
    echo "## $1"
    echo
}

if [ $# -lt 4 ]; then
    echo "Execution format ./install.sh stakeaddr email fqdn region nodetype"
    exit
fi

# Installation variables
stakeaddr=${1}
email=${2}
fqdn=${3}
region=${4}

if [ -z "$5" ]; then
  nodetype="secure"
else
  nodetype=${5}
fi

testnet=0
rpcpassword=$(head -c 32 /dev/urandom | base64)

print_status "Installing the ZenCash node..."

echo "#########################"
echo "fqdn: $fqdn"
echo "email: $email"
echo "stakeaddr: $stakeaddr"
echo "#########################"

# Create swapfile if less then 4GB memory
totalmem=$(free -m | awk '/^Mem:/{print $2}')
totalswp=$(free -m | awk '/^Swap:/{print $2}')
totalm=$(($totalmem + $totalswp))
if [ $totalm -lt 4000 ]; then
  print_status "Server memory is less then 4GB..."
  if ! grep -q '/swapfile' /etc/fstab ; then
    print_status "Creating a 4GB swapfile..."
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
  fi
fi

# Populating Cache
print_status "Populating apt-get cache..."
apt-get update

print_status "Installing packages required for setup..."
apt-get install -y docker.io apt-transport-https lsb-release curl fail2ban unattended-upgrades ufw dnsutils > /dev/null 2>&1

systemctl enable docker
systemctl start docker

print_status "Creating the docker mount directories..."
mkdir -p /mnt/zen/{config,data,zcash-params,certs}

print_status "Removing acme container service..."
rm /etc/systemd/system/acme-sh.service

print_status "Disable apache2 if enabled, to free Port 80..."
systemctl disable apache2
systemctl stop apache2

print_status "Installing certbot..."
add-apt-repository ppa:certbot/certbot -y
apt-get update -y
apt-get install certbot -y

print_status "Issusing cert for $fqdn..."
certbot certonly -n --agree-tos --register-unsafely-without-email --standalone -d $fqdn

chmod -R 755 /etc/letsencrypt/

echo \
"[Unit]
Description=zenupdate.service

[Service]
Type=oneshot
ExecStart=/usr/bin/certbot -q renew --deploy-hook 'systemctl restart zen-node && systemctl restart zen-secnodetracker && docker rmi $(docker images --quiet --filter "dangling=true")'
PrivateTmp=true" | tee /lib/systemd/system/zenupdate.service

echo \
"[Unit]
Description=Run zenupdate unit daily @ 06:00:00 (UTC)

[Timer]
OnCalendar=*-*-* 06:00:00
Unit=zenupdate.service
Persistent=true

[Install]
WantedBy=timers.target" | tee /lib/systemd/system/zenupdate.timer

systemctl daemon-reload
systemctl stop certbot.timer
systemctl disable certbot.timer

systemctl start zenupdate.timer
systemctl enable zenupdate.timer

print_status "Creating the zen configuration."
cat <<EOF > /mnt/zen/config/zen.conf
rpcport=18231
rpcallowip=127.0.0.1
rpcworkqueue=512
server=1
# Docker doesn't run as daemon
daemon=0
listen=1
txindex=1
logtimestamps=1
### testnet config
testnet=$testnet
rpcuser=user
rpcpassword=$rpcpassword
tlscertpath=/etc/letsencrypt/live/$fqdn/cert.pem
tlskeypath=/etc/letsencrypt/live/$fqdn/privkey.pem
#
port=9033
EOF

print_status "Trying to determine public ip addresses..."
publicips=$(dig $fqdn A $fqdn AAAA +short)
while read -r line; do
    echo "externalip=$line" >> /mnt/zen/config/zen.conf
done <<< "$publicips"

print_status "Creating the secnode config..."

if [ $nodetype = "super" ]; then
  servers=xns
else
  servers=ts
fi

mkdir -p /mnt/zen/secnode/
cat << EOF > /mnt/zen/secnode/config.json
{
 "active": "$nodetype",
 "$nodetype": {
  "nodetype": "$nodetype",
  "nodeid": null,
  "servers": [
   "${servers}2.eu",
   "${servers}1.eu",
   "${servers}3.eu",
   "${servers}4.eu",
   "${servers}4.na",
   "${servers}3.na",
   "${servers}2.na",
   "${servers}1.na"
  ],
  "stakeaddr": "$stakeaddr",
  "email": "$email",
  "fqdn": "$fqdn",
  "ipv": "4",
  "region": "$region",
  "home": "${servers}1.$region",
  "category": "none"
 }
}
EOF

print_status "Installing zend service..."
cat <<EOF > /etc/systemd/system/zen-node.service
[Unit]
Description=Zen Daemon Container
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=10m
Restart=always
ExecStartPre=-/usr/bin/docker stop zen-node
ExecStartPre=-/usr/bin/docker rm  zen-node
# Always pull the latest docker image
ExecStartPre=/usr/bin/docker pull whenlambomoon/zend:latest
ExecStart=/usr/bin/docker run --rm --net=host -p 9033:9033 -p 18231:18231 -v /mnt/zen:/mnt/zen -v /etc/letsencrypt/:/etc/letsencrypt/ --name zen-node whenlambomoon/zend:latest
[Install]
WantedBy=multi-user.target
EOF

print_status "Installing secnodetracker service..."
cat <<EOF > /etc/systemd/system/zen-secnodetracker.service
[Unit]
Description=Zen Secnodetracker Container
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=10m
Restart=always
ExecStartPre=-/usr/bin/docker stop zen-secnodetracker
ExecStartPre=-/usr/bin/docker rm  zen-secnodetracker
# Always pull the latest docker image
ExecStartPre=/usr/bin/docker pull whenlambomoon/secnodetracker:latest
#ExecStart=/usr/bin/docker run --init --rm --net=host -v /mnt/zen:/mnt/zen --name zen-secnodetracker whenlambomoon/secnodetracker:latest
ExecStart=/usr/bin/docker run --rm --net=host -v /mnt/zen:/mnt/zen --name zen-secnodetracker whenlambomoon/secnodetracker:latest
[Install]
WantedBy=multi-user.target
EOF

print_status "Enabling and starting container services..."
systemctl daemon-reload
systemctl enable zen-node
systemctl restart zen-node

systemctl enable zen-secnodetracker
systemctl restart zen-secnodetracker

print_status "Enabling basic firewall services..."
ufw default allow outgoing
ufw default deny incoming
ufw allow ssh/tcp
ufw limit ssh/tcp
ufw allow http/tcp
ufw allow https/tcp
ufw allow 9033/tcp
#ufw allow 19033/tcp
ufw --force enable

print_status "Enabling fail2ban services..."
systemctl enable fail2ban
systemctl start fail2ban

print_status "Waiting for node to fetch params ..."
until docker exec -it zen-node /usr/local/bin/gosu user zen-cli getinfo
do
  echo ".."
  sleep 30
done

if [[ $(docker exec -it zen-node /usr/local/bin/gosu user zen-cli z_listaddresses | wc -l) -eq 2 ]]; then
  print_status "Generating shield address for node... you will need to send 1 ZEN to this address:"
  docker exec -it zen-node /usr/local/bin/gosu user zen-cli z_getnewaddress

  print_status "Restarting secnodetracker"
  systemctl restart zen-secnodetracker
else
  print_status "Node already has shield address... you will need to send 1 ZEN to this address:"
  docker exec -it zen-node /usr/local/bin/gosu user zen-cli z_listaddresses
fi

print_status "Install Finished"
echo "Please wait until the blocks are up to date..."

## TODO: Post the shield address back to our API
