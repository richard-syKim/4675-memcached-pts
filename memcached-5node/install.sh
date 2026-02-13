#!/bin/sh

# Extract memcached
tar -xzf memcached-1.6.19.tar.gz
cd memcached-1.6.19 || exit 1
# Allow run as root
patch -p0 <<'EOF'
--- memcached.c.orig	2022-08-19 13:51:28.705427565 -0400
+++ memcached.c	2022-08-19 13:52:03.426871004 -0400
@@ -5810,7 +5810,7 @@
     }
 
     /* lose root privileges if we have them */
-    if (getuid() == 0 || geteuid() == 0) {
+    if (false) {
         if (username == 0 || *username == '\0') {
             fprintf(stderr, "can't run as root without the -u switch\n");
             exit(EX_USAGE);
EOF
./configure
make -j $NUM_CPU_CORES || exit 1

cd ..

# Extract memtier
tar -xzf memtier_benchmark-1.4.0.tar.gz
cd memtier_benchmark-1.4.0 || exit 1

autoreconf -ivf
./configure
make -j $NUM_CPU_CORES || exit 1

cd ..
# mcrouter config
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

cat > memcached-5node <<'EOF'
#!/bin/sh

cleanup() {
    # sudo tc qdisc del dev lo root 2>/dev/null

     for i in 1 2 3 4 5; do
          sudo ip addr del 10.0.0.$i/32 dev lo 2>/dev/null
     done
     
     kill $MEM1 $MEM2 $MEM3 $MEM4 $MEM5 $MCR 2>/dev/null
}

trap cleanup EXIT

cd memcached-1.6.19 || exit 1

# Add loopback IPs
for i in 1 2 3 4 5; do
    sudo ip addr add 10.0.0.$i/32 dev lo
done

# Add artificial latency + jitter
# sudo tc qdisc add dev lo root netem delay 1ms 0.2ms distribution normal

# Start 5 memcached nodes
./memcached -l 10.0.0.1 -p 11211 -t $NUM_CPU_CORES & MEM1=$!
./memcached -l 10.0.0.2 -p 11211 -t $NUM_CPU_CORES & MEM2=$!
./memcached -l 10.0.0.3 -p 11211 -t $NUM_CPU_CORES & MEM3=$!
./memcached -l 10.0.0.4 -p 11211 -t $NUM_CPU_CORES & MEM4=$!
./memcached -l 10.0.0.5 -p 11211 -t $NUM_CPU_CORES & MEM5=$!

sleep 5

cd ..

# Start mcrouter on port 5000
mcrouter \
  --config-file=cluster.json \
  --port=5000 \
  --num-proxies=1 &

MCR=$!

sleep 6

cd memtier_benchmark-1.4.0 || exit 1

# Benchmark THROUGH mcrouter
./memtier_benchmark \
  --protocol=memcache_text \
  --server=127.0.0.1 \
  --port=5000 \
  --hide-histogram \
  "$@" > "$LOG_FILE"

# wait
for i in 1 2 3 4 5; do
     sudo ip addr del 10.0.0.$i/32 dev lo 2>/dev/null
done

kill $MEM1 $MEM2 $MEM3 $MEM4 $MEM5 $MCR 2>/dev/null
EOF

chmod +x memcached-5node

exit 0
