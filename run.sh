#!/bin/sh

: "${MEMCACHED_USER:=nobody}"
: "${NUM_CPU_CORES:=4}"
LOG_FILE="benchmark_results_$(date +%Y%m%d_%H%M%S).log"

cleanup() {
    # Remove loopback IPs
    for i in 1 2 3 4 5; do
        sudo ip addr del 10.0.0.$i/32 dev lo 2>/dev/null
    done

    # Kill background processes
    kill $MEM1 $MEM2 $MEM3 $MEM4 $MEM5 $MCR 2>/dev/null
}

trap cleanup EXIT

# Prompt user for benchmark ratio
echo "Choose which Write:Read ratio you wish to benchmark:"
echo "1) 1:100"
echo "2) 1:10"
echo "3) 1:1"
echo "4) 5:1"
read -rp "Enter choice (1-4): " choice

case "$choice" in
    1) RATIO="1:100" ;;
    2) RATIO="1:10" ;;
    3) RATIO="1:1" ;;
    4) RATIO="5:1" ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

# Start memcached nodes
cd memcached-1.6.19 || exit 1
for i in 1 2 3 4 5; do
    sudo ip addr add 10.0.0.$i/32 dev lo
done

for i in 1 2 3 4 5; do
    ./memcached -u "$MEMCACHED_USER" -l 10.0.0.$i -p 11211 -t "$NUM_CPU_CORES" &
done

MEM1=$!
MEM2=$!
MEM3=$!
MEM4=$!
MEM5=$!

sleep 5
cd ..

# Start mcrouter
mcrouter --config-file=cluster.json --port=5000 --num-proxies=1 &
MCR=$!

sleep 6

# Run memtier benchmark
cd memtier_benchmark-1.4.0 || exit 1
echo "Running benchmark with ratio $RATIO..."
./memtier_benchmark \
  --protocol=memcache_text \
  --server=127.0.0.1 \
  --port=5000 \
  --clients=1 \
  --pipeline=16 \
  --test-time=60 \
  --ratio="$RATIO" | tee "../$LOG_FILE"

echo "Benchmark complete. Results saved to $LOG_FILE"
