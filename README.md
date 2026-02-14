# 4675-memcached-pts

## Requirements
* Ubuntu 16.04 is required to run this project.
* While it is possible to use WSL, running on a native Ubuntu installation is recommended if you want to simulate network latency.

## Running the Benchmark

1. Run the setup script:

   ```
   ./setup.sh
   ```

2. Run the benchmark script:

   ```
   ./run.sh
   ```

3. When prompted, choose a workload option (1–5).

## Output Files

After the benchmark completes successfully, the following files will be generated:

* A `.log` file containing all recorded statistics
* A `.txt` file for each `set`, `get`, and combined instruction latency distribution
* A `.hgrm` file for each `set`, `get`, and combined instruction latency distribution

You can use the `.txt` files to generate plots using the following tool:

[https://hdrhistogram.github.io/HdrHistogram/plotFiles.html](https://hdrhistogram.github.io/HdrHistogram/plotFiles.html)
