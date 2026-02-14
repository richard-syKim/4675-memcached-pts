#!/bin/sh

MEMCACHED_USER=${MEMCACHED_USER:-nobody}
NUM_CPU_CORES=${NUM_CPU_CORES:-4}
LOG_FILE="benchmark_results_$(date +%Y%m%d_%H%M%S).log"

cleanup() {
    if ! grep -qi microsoft /proc/version; then
        sudo tc qdisc del dev lo root 2>/dev/null
    fi
    
    # Remove loopback IPs
    for i in 1 2 3 4 5; do
        sudo ip addr del 10.0.0.$i/32 dev lo 2>/dev/null
    done

    # Kill background processes
    kill $MEM_PIDS 2>/dev/null

    kill "$MCR"
    wait "$MCR" 2>/dev/null
}

trap cleanup EXIT

# Prompt user for benchmark ratio
echo "Choose which Write:Read ratio you wish to benchmark:"
echo "1) 1:100"
echo "2) 1:10"
echo "3) 1:5"
echo "4) 1:1"
echo "5) 5:1"
read -rp "Enter choice (1-5): " choice

case "$choice" in
    1) RATIO="1:100" ;;
    2) RATIO="1:10" ;;
    3) RATIO="1:1" ;;
    4) RATIO="1:1" ;;
    5) RATIO="5:1" ;;
    *) echo "Invalid choice"; exit 1 ;;
esac


# Add artificial latency + jitter
if grep -qi microsoft /proc/version; then
    echo "WSL detected — skipping tc netem (unsupported kernel)"
else
    sudo modprobe sch_netem
    sudo tc qdisc add dev lo root netem delay 1ms 0.2ms distribution normal
fi


# Start memcached nodes
cd memcached-1.6.19 || exit 1
for i in 1 2 3 4 5; do
    sudo ip addr add 10.0.0.$i/32 dev lo
done

for i in 1 2 3 4 5; do
    ./memcached -u $MEMCACHED_USER -l 10.0.0.$i -p 11211 -t $NUM_CPU_CORES &
    MEM_PIDS="$MEM_PIDS $!"
done

sleep 5
cd ..

# Start mcrouter
mcrouter --config-file=cluster.json --port=5000 --num-proxies=1 &
MCR=$!

sleep 6

# Run memtier benchmark
cd memtier_benchmark-1.4.0 || exit 1

# printf "stats\r\n" | nc -q 1 10.0.0.1 11211 | grep evictions

WARMUP_TIME=${WARMUP_TIME:-30}

echo "Warming up cache for ${WARMUP_TIME}s (SET only)..."

./memtier_benchmark \
  --protocol=memcache_text \
  --server=127.0.0.1 \
  --port=5000 \
  --clients=1 \
  --pipeline=16 \
  --test-time="$WARMUP_TIME" \
  --key-maximum=500000 \
  --ratio=1:0 \
  --hide-histogram > /dev/null

echo "Warmup complete."
sleep 3


echo "Running benchmark with ratio $RATIO..."
./memtier_benchmark \
  --protocol=memcache_text \
  --server=127.0.0.1 \
  --port=5000 \
  --clients=1 \
  --pipeline=128 \
  --delay=500 \
  --test-time=60 \
  --key-maximum=500000 \
  --ratio="$RATIO" \
  --hdr-file-prefix="../hdr_$(date +%Y%m%d_%H%M%S)" \
  | tee "../$LOG_FILE"

echo "Benchmark complete. Results saved to $LOG_FILE"

# printf "stats\r\n" | nc -q 1 10.0.0.1 11211 | grep evictions

exit 0