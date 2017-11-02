#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

print_status() {
    echo
    echo "## $1"
    echo
}

if [ $# -ne 4 ]; then
    echo "Execution format ./install.sh stakeaddr email fqdn region (eu, na or sea)"
    exit
fi

# Installation variables
stakeaddr=${1}
email=${2}
fqdn=${3}
region=${4}

testnet=1
rpcpassword=$(head -c 32 /dev/urandom | base64)

print_status "Installing the ZenCash node..."

echo "#########################"
echo "fqdn: $fqdn"
echo "email: $email"
echo "stakeaddr: $stakeaddr"
echo "#########################"

# Create swapfile if less then 4GB memory
totalm=$(free -m | awk '/^Mem:/{print $2}')
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
apt-get install -y docker.io apt-transport-https lsb-release curl fail2ban unattended-upgrades > /dev/null 2>&1

systemctl enable docker
systemctl start docker

print_status "Creating the docker mount directories..."
mkdir -p /mnt/zen/{config,data,zcash-params,certs}

print_status "Installing acme container service..."

cat <<EOF > /etc/systemd/system/acme-sh.service
[Unit]
Description=acme.sh container
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=10m
Restart=always
ExecStartPre=-/usr/bin/docker stop acme-sh
ExecStartPre=-/usr/bin/docker rm  acme-sh
# Always pull the latest docker image
ExecStartPre=/usr/bin/docker pull neilpang/acme.sh
ExecStart=/usr/bin/docker run --rm --net=host -v /mnt/zen/certs:/acme.sh --name acme-sh neilpang/acme.sh daemon
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable acme-sh
systemctl restart acme-sh

print_status "Waiting for acme-sh to come up..."
until docker exec -it acme-sh --list
do
  echo ".."
  sleep 15
done

print_status "Issusing cert for $fqdn..."
docker exec acme-sh --issue -d $fqdn  --standalone
# Note: error code 2 means cert already isssued
if [ $? -eq 1 ]; then
    print_status "Error provisioning certificate for domain.. exiting"
    exit 1
fi

print_status "Creating the zen configuration."
cat <<EOF > /mnt/zen/config/zen.conf
rpcport=18231
rpcallowip=127.0.0.0/24
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
tlscertpath=/mnt/zen/certs/$fqdn/$fqdn.cer
tlskeypath=/mnt/zen/certs/$fqdn/$fqdn.key
EOF

print_status "Creating the secnode config..."
mkdir -p /mnt/zen/secnode/
echo -n $email > /mnt/zen/secnode/email
echo -n $fqdn > /mnt/zen/secnode/fqdn
echo -n '127.0.0.1' > /mnt/zen/secnode/rpcallowip
echo -n '127.0.0.1' > /mnt/zen/secnode/rpcbind
echo -n '18231' > /mnt/zen/secnode/rpcport
echo -n 'user' > /mnt/zen/secnode/rpcuser
echo -n $rpcpassword > /mnt/zen/secnode/rpcpassword
echo -n 'ts1.eu,ts1.na,ts1.sea' > /mnt/zen/secnode/servers
echo -n "ts1.$region" > /mnt/zen/secnode/home
echo -n $region > /mnt/zen/secnode/region
echo -n 'http://devtracksys.secnodes.com' > /mnt/zen/secnode/serverurl
echo -n $stakeaddr > /mnt/zen/secnode/stakeaddr

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
ExecStart=/usr/bin/docker run --rm --net=host -p 9033:9033 -p 18231:18231 -v /mnt/zen:/mnt/zen --name zen-node whenlambomoon/zend:latest
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
ufw allow 19033/tcp
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
