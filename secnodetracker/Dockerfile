FROM node:8

ENV TINI_VERSION v0.16.1
ENV NODE_ENV production
ENV ZENCONF /mnt/zen/config/zen.conf
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

RUN latestBaseurl="$(curl -s https://api.github.com/repos/tianon/gosu/releases | grep browser_download_url | head -n 1 | cut -d '"' -f 4 | sed 's:/[^/]*$::')" \
&& dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
&& curl -o /usr/local/bin/gosu -SL "$latestBaseurl/gosu-$dpkgArch" \
&& curl -o /usr/local/bin/gosu.asc -SL "$latestBaseurl/gosu-$dpkgArch.asc" \
&& export GNUPGHOME="$(mktemp -d)" \
&& echo "disable-ipv6" >> $GNUPGHOME/dirmngr.conf \
&& gpg --no-tty --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
&& gpg --no-tty --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
&& chmod +x /usr/local/bin/gosu \
&& gosu nobody true \

WORKDIR /home/node/

RUN cd /home/node/ \
    && git clone https://github.com/ZencashOfficial/secnodetracker.git \
    && cd secnodetracker \
    && npm install

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/tini", "--", "/usr/local/bin/entrypoint.sh"]
