#!/bin/bash

cd ~
sudo apt-get install \
      build-essential pkg-config libc6-dev m4 g++-multilib \
      autoconf libtool ncurses-dev unzip git python python-zmq \
      zlib1g-dev wget bsdmainutils automake curl


# build daemon patched with indexing support
git clone https://github.com/bzedge/bzedge-insight-patched.git
cd bzedge-insight-patched

chmod +x zcutil/build.sh depends/config.guess depends/config.sub autogen.sh share/genbuild.sh src/leveldb/build_detect_platform

# fetch key
./zcutil/fetch-params.sh

# Build. Use -j8 or -j$(nproc) if you have CPUs and RAM.
cd bzedge/
./zcutil/build.sh -j4


# install npm and use node v8
cd ~
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash
nvm install 8.11.4

# install pm2 to take care of node processes
npm install -g pm2
pm2 install pm2-logrotate
sudo su -c "env PATH=$PATH:/home/$USER/.nvm/versions/node/v8.11.4/bin pm2 startup ubuntu -u $USER --hp /home/$USER"
mkdir -p /home/$USER/pm2-apps



# install ZeroMQ libraries
sudo apt-get -y install libzmq3-dev

# install bzedge version of bitcore
git clone https://github.com/BZEdge/bitcore-node-bzedge.git
cd bitcore-node-bzedge
npm install 

# create bitcore node
cd bin
./bitcore-node create bzedge
cd bzedge

# install insight api/ui
git clone https://github.com/shmocs/insight-api-bzedge.git
git clone https://github.com/shmocs/insight-ui-bzedge.git
../bitcore-node install insight-api-bzedge
../bitcore-node install insight-ui-bzedge

# create bitcore config file for bitcore
cat << EOF > bitcore-node.json
{
  "network": "mainnet",
  "port": 3001,
  "services": [
    "bitcoind",
    "insight-api-bzedge",
    "insight-ui-bzedge",
    "web"
  ],
  "servicesConfig": {
    "bitcoind": {
      "spawn": {
        "datadir": "/home/$USER/.bzedge",
        "exec": "/home/$USER/bzedge-insight-patched/src/bitcoinzd"
      }
    },
    "insight-ui-bzedge": {
      "routePrefix": "",
      "apiPrefix": "api"
    },
    "insight-api-bzedge": {
      "routePrefix": "api"
    }
  }
}
EOF

# create [daemon].conf
cat << EOF > data/bzedge.conf
server=1
whitelist=127.0.0.1

txindex=1
addressindex=1
timestampindex=1
spentindex=1

zmqpubrawtx=tcp://127.0.0.1:28333
zmqpubhashblock=tcp://127.0.0.1:28333

rpcallowip=127.0.0.1
rpcuser=bitcoin
rpcpassword=local321
uacomment=bitcore
showmetrics=0
maxconnections=1000
EOF

echo "Start the block explorer, open in your browser http://server_ip:3001"
echo "../bitcore-node start"
