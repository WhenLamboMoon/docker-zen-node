FROM node:8

ENV TINI_VERSION v0.16.1
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

USER node
WORKDIR /home/node/

RUN git clone https://github.com/ZencashOfficial/secnodetracker.git \
    && cd secnodetracker \
    && npm install

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/tini", "--", "/usr/local/bin/entrypoint.sh"]
