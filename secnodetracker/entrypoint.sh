#!/bin/bash

# link the secure node tracker config, bail if not present
if [ -f "/mnt/zen/secnode/stakeaddr" ]; then
  echo "Secure node config found OK - linking..."
  ln -s /mnt/zen/secnode /home/node/secnodetracker/config > /dev/null 2>&1 || true
else
  echo "No secure node config found. exiting"
  exit 1
fi

cd secnodetracker
node app.js
