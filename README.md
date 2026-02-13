# 4675-memcached-pts

## Requirements
- Linux (specifically v18.04 due to mcrouter)
supo apt update
sudo apt install php-zip build-essential pkg-config autoconf automake

- Phoronix Test Suite installed (need to manually install as older linux version)
wget https://phoronix-test-suite.com/releases/phoronix-test-suite-10.8.4.tar.gz
tar -xvf phoronix-test-suite-10.8.4.tar.gz
cd phoronix-test-suite
sudo ./install-sh

- mcrouter installed
sudo apt-get install mcrouter


chmod +x run.sh

## Install
cp -r memcached-5node ~/.phoronix-test-suite/test-profiles/local/

## Run
phoronix-test-suite benchmark local/memcached-5node