FROM ubuntu:16.04

# Used only for triggering a rebuild
LABEL zend="2.0.19"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install ca-certificates curl wget apt-transport-https lsb-release libgomp1 jq \
    && echo 'deb https://zencashofficial.github.io/repo/ '$(lsb_release -cs)' main' | tee --append /etc/apt/sources.list.d/zen.list \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv 219F55740BBF7A1CE368BA45FB7053CE4991B669 \
    && gpg --export 219F55740BBF7A1CE368BA45FB7053CE4991B669 | apt-key add - \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install zen \
    && latestBaseurl="$(curl -s https://api.github.com/repos/tianon/gosu/releases | grep browser_download_url | head -n 1 | cut -d '"' -f 4 | sed 's:/[^/]*$::')" \
    && dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
    && curl -o /usr/local/bin/gosu -SL "$latestBaseurl/gosu-$dpkgArch" \
    && curl -o /usr/local/bin/gosu.asc -SL "$latestBaseurl/gosu-$dpkgArch.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Default p2p communication port, can be changed via $OPTS (e.g. docker run -e OPTS="-port=9876")
# or via a "port=9876" line in zen.conf.
#Defaults are 9033/19033 (Testnet)
EXPOSE 9033
EXPOSE 19033

# Default rpc communication port, can be changed via $OPTS (e.g. docker run -e OPTS="-rpcport=8765")
# or via a "rpcport=8765" line in zen.conf. This port should never be mapped to the outside world
# via the "docker run -p/-P" command.
#Defaults are 8231/18231 (Testnet)
EXPOSE 8231
EXPOSE 18231

# Data volumes, if you prefer mounting a host directory use "-v /path:/mnt/zen" command line
# option (folder ownership will be changed to the same UID/GID as provided by the docker run command)
VOLUME ["/mnt/zen"]

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["zend"]
