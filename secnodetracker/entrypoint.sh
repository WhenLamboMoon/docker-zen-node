#!/bin/bash

# link the secure node tracker config, bail if not present
if [ -f "/mnt/zen/secnode/config.json" ]; then
  echo "Secure node config found OK - linking..."
  ln -s /mnt/zen/secnode /home/node/secnodetracker/config > /dev/null 2>&1 || true
else
  echo "No secure node config found. exiting"
  exit 1
fi

# Copy the zencash params
cp -r /mnt/zen/zcash-params /mnt/zcash-params

# Fix the permissons
chown -R node:node /mnt/zen/secnode /mnt/zcash-params /home/node/secnodetracker
chmod g+rw /mnt/zen/secnode /home/node/secnodetracker
chmod -R 777 /home/node/secnodetracker/config

cd /home/node/secnodetracker
gosu node node app.js
