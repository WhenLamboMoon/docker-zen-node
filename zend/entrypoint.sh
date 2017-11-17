#!/bin/bash
set -e

# Add local user
# Either use the LOCAL_USER_ID if passed in at runtime or
# fallback
USER_ID=${LOCAL_USER_ID:-9001}
GRP_ID=${LOCAL_GRP_ID:-9001}

getent group user > /dev/null 2>&1 || groupadd -g $GRP_ID user
id -u user > /dev/null 2>&1 || useradd --shell /bin/bash -u $USER_ID -g $GRP_ID -o -c "" -m user

LOCAL_UID=$(id -u user)
LOCAL_GID=$(getent group user | cut -d ":" -f 3)

if [ ! "$USER_ID" == "$LOCAL_UID" ] || [ ! "$GRP_ID" == "$LOCAL_GID" ]; then
    echo "Warning: User with differing UID "$LOCAL_UID"/GID "$LOCAL_GID" already exists, most likely this container was started before with a different UID/GID. Re-create it to change UID/GID."
fi

echo "Starting with UID/GID : "$(id -u user)"/"$(getent group user | cut -d ":" -f 3)

export HOME=/home/user

# Must have a zen config file
if [ ! -f "/mnt/zen/config/zen.conf" ]; then
  echo "No config found. Exiting."
  exit 1
else
  if [ ! -L $HOME/.zen ]; then
    ln -s /mnt/zen/config $HOME/.zen > /dev/null 2>&1 || true
  fi
fi

# zcash-params can be symlinked in from an external volume or created locally
if [ -d "/mnt/zen/zcash-params" ]; then
  if [ ! -L $HOME/.zcash-params ]; then
    echo "Symlinking external zcash-params volume..."
    ln -s /mnt/zen/zcash-params $HOME/.zcash-params > /dev/null 2>&1 || true
  fi
else
  echo "Using local zcash-params folder"
  mkdir -p $HOME/.zcash-params > /dev/null 2>&1 || true
fi

# data folder can be an external volume or created locally
if [ ! -d "/mnt/zen/data" ]; then
  echo "Using local data folder"
  mkdir -p /mnt/zen/data > /dev/null 2>&1 || true
else
  echo "Using external data volume"
fi

# Copy in any additional SSL trusted CA
if [ -d "/mnt/zen/certs" ]; then
  domain="$(cat /mnt/zen/secnode/fqdn)"
  if [ -f /mnt/zen/certs/$domain/ca.cer ]; then
    echo "Copying additional trusted SSL certificates"
    cp /mnt/zen/certs/$domain/ca.cer /usr/local/share/ca-certificates/ca.crt > /dev/null 2>&1 || true
    update-ca-certificates --fresh
  fi
fi

# Fix ownership of the created files/folders
chown -R user:user /home/user /mnt/zen

/usr/local/bin/gosu user zen-fetch-params

echo "Starting $@ .."
if [[ "$1" == zend ]]; then
    exec /usr/local/bin/gosu user /bin/bash -c "$@ $OPTS"
fi

exec /usr/local/bin/gosu user "$@"
