## Benchmark Script Documentation

### Overview

The Disk Performance Benchmark Suite provides comprehensive storage testing with HTML reporting. It consists of:

1.  Installation script (`install_disk_benchmark.sh`)
    
2.  Benchmark script (`run_disk_benchmark.sh`)
    
3.  TuneUp script (`ubuntu_tuneup.sh`)
    

### Installation Script (`install_disk_benchmark.sh`)

#### Purpose:

Installs required benchmarking tools and dependencies.

#### Parameters:

None (run with root privileges)

#### Usage:

```
sudo ./install_disk_benchmark.sh
```

#### Installs:

- fio (Flexible I/O Tester)
    
- ioping (I/O latency measurement)
    
- hdparm (Hard disk parameters)
    
- sysstat (System performance tools)
    
- jq (JSON processor)
    
- bc (Arithmetic calculator)
    
- smartmontools (SMART disk monitoring)
    
- html2text (HTML to text converter)
    

### Benchmark Script (`run_disk_benchmark.sh`)

#### Purpose:

Executes comprehensive disk performance tests and generates HTML report.

#### Parameters:

1.  `[TEST_DIR]` (Optional): Directory to test (default: current directory)

#### Usage:

```
# Test current directory
./run_disk_benchmark.sh

# Specify test directory
./run_disk_benchmark.sh /path/to/test_directory
```

#### Tests Performed:

1.  **HDparm Sequential Read**: Measures raw device read speed
    
2.  **I/O Latency (Ioping)**: Measures response time for random requests
    
3.  **FIO Sequential Read**: Sustained large file read performance
    
4.  **FIO Sequential Write**: Sustained large file write performance
    
5.  **FIO Random Read (4K)**: Small block random read IOPS
    
6.  **FIO Random Write (4K)**: Small block random write IOPS
    
7.  **FIO Mixed Workload (70/30 R/W)**: Simulated real-world workload
    
8.  **Disk Utilization (SAR)**: Measures disk busy percentage
    

#### Output:

- HTML report with timestamp in filename (e.g., `disk_benchmark_20250721_143022.html`)
    
- Color-coded performance ratings (Excellent/Good/Average/Poor)
    

### Tuneup Script (`ubuntu_tuneup.sh`)

#### Purpose:

Tuneup disk performance and configuration.

#### Parameters:

None

#### Usage:

```
sudo ./ubuntu_tuneup.sh
```

#### Tuneup Performed:

1.  System overview
    
2.  Hardware inventory
    
3.  Disk health (SMART)
    
4.  Filesystem configuration
    
5.  I/O scheduler settings
    
6.  Running I/O processes
    
7.  Quick performance tests
    
8.  Kernel I/O parameters
    

#### Output:

- Text log file with timestamp (e.g., `disk_troubleshoot_20250721_143022.log`)

* * *

## Performance Rating Guide

### Sequential Speeds (Read/Write)

| Rating | HDD | SATA SSD | NVMe SSD |
| --- | --- | --- | --- |
| Excellent | \>200 MB/s | \>500 MB/s | \>3000 MB/s |
| Good | 100-200 MB/s | 300-500 MB/s | 1500-3000 MB/s |
| Average | 50-100 MB/s | 150-300 MB/s | 800-1500 MB/s |
| Poor | <50 MB/s | <150 MB/s | <800 MB/s |

### Random IOPS (4K)

| Rating | HDD | SATA SSD | NVMe SSD |
| --- | --- | --- | --- |
| Excellent | \>200 | \>80,000 | \>500,000 |
| Good | 100-200 | 30,000-80,000 | 200,000-500,000 |
| Average | 50-100 | 10,000-30,000 | 50,000-200,000 |
| Poor | <50 | <10,000 | <50,000 |

### Latency

| Rating | HDD | SSD |
| --- | --- | --- |
| Excellent | <5 ms | <0.1 ms |
| Good | 5-10 ms | 0.1-0.5 ms |
| Average | 10-20 ms | 0.5-1 ms |
| Poor | \>20 ms | \>1 ms |

* * *

## Troubleshooting Guide

### Common Issues and Solutions:

1.  **Low Sequential Speeds**:
    
    - Check disk health: `sudo smartctl -a /dev/sdX`
        
    - Verify connection type: USB 2.0 vs USB 3.0 vs SATA
        
    - Test raw device: `sudo hdparm -Tt /dev/sdX`
        
    - Check for disk errors: `dmesg | grep -i error`
        
2.  **High Latency**:
    
    - Check for disk queue: `iostat -dx 2`
        
    - Identify heavy processes: `sudo iotop -o`
        
    - Adjust I/O scheduler: `echo deadline > /sys/block/sdX/queue/scheduler`
        
    - Reduce swappiness: `sysctl vm.swappiness=10`
        
3.  **Test Failures**:
    
    - Ensure sufficient space: `df -h`
        
    - Run as root: `sudo ./run_disk_benchmark.sh`
        
    - Check filesystem: `fsck /dev/sdX`
        
    - Verify dependencies: `./install_disk_benchmark.sh`
        
4.  **Inconsistent Results**:
    
    - Close background applications
        
    - Disable swap: `swapoff -a`
        
    - Repeat tests 3 times
        
    - Test during low-usage periods
        

### Script Maintenance:

- Update package list: `sudo apt update`
    
- Upgrade tools: `sudo apt upgrade fio ioping hdparm`
    
- Check for updates: [FIO GitHub](https://github.com/axboe/fio)
    
- Report issues: Include HTML report and troubleshoot log
