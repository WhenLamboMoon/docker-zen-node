FROM node:8

USER node
WORKDIR /home/node/

RUN git clone https://github.com/ZencashOfficial/secnodetracker.git \
    && cd secnodetracker \
    && npm install

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
