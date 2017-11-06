#!/bin/bash

# link the secure node tracker config, bail if not present
if [ -f "/mnt/zen/secnode/stakeaddr" ]; then
  echo "Secure node config found OK - linking..."
  ln -s /mnt/zen/secnode /home/node/secnodetracker/config > /dev/null 2>&1 || true
else
  echo "No secure node config found. exiting"
  exit 1
fi

# Fix ownership of the created files/folders
chown -R node:node /home/node /mnt/zen /mnt/zcash-params

cd secnodetracker
gosu node node app.js
