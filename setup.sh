#!/bin/sh

: "${NUM_CPU_CORES:=4}"

# Install dependencies for mcrouter
sudo apt update
sudo apt install -y php-zip build-essential pkg-config autoconf automake libevent-dev

# Install mcrouter
sudo apt install -y mcrouter

# Extract and build memcached
tar -xzf memcached-1.6.19.tar.gz
cd memcached-1.6.19 || exit 1
./configure
make -j "$NUM_CPU_CORES" || exit 1
cd ..

# Extract and build memtier
tar -xzf memtier_benchmark-1.4.0.tar.gz
cd memtier_benchmark-1.4.0 || exit 1
autoreconf -ivf
./configure
make -j "$NUM_CPU_CORES" || exit 1
cd ..

# Create mcrouter cluster configuration
cat > cluster.json <<'EOF'
{
  "pools": {
    "A": {
      "servers": [
        "10.0.0.1:11211",
        "10.0.0.2:11211",
        "10.0.0.3:11211",
        "10.0.0.4:11211",
        "10.0.0.5:11211"
      ]
    }
  },
  "route": "PoolRoute|A"
}
EOF

echo "Setup complete. You can now run ./run.sh"
