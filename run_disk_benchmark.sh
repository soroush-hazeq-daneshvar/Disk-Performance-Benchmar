#!/bin/bash
# Advanced Disk Performance Test with HTML Report

# Configuration
TEST_DIR=${1:-$PWD}
SIZE="2G"                          # Test file size
DURATION=60                        # Test duration in seconds
OUTPUT_HTML="disk_benchmark_$(date +%Y%m%d_%H%M%S).html"
declare -a TEST_RESULTS

# Safety checks
if [[ ! -d "$TEST_DIR" ]]; then
    echo "ERROR: Test directory $TEST_DIR does not exist"
    exit 1
fi

if [[ "$TEST_DIR" =~ ^/dev/ ]]; then
    echo "ERROR: Direct device testing not supported for safety"
    exit 1
fi

# Dependency check
for tool in fio ioping hdparm sar jq bc smartctl pv; do
    if ! command -v $tool &>/dev/null; then
        echo "ERROR: $tool not found. Run install script first."
        exit 1
    fi
done

# Get disk information
get_disk_info() {
    DISK_DEVICE=$(df -P "$TEST_DIR" | awk 'END{print $1}')
    if [[ "$DISK_DEVICE" == /dev/* ]]; then
        DISK_DEVICE=${DISK_DEVICE%%[0-9]*}  # Strip partition number
    fi
    DISK_MODEL=$(lsblk -d -o MODEL $DISK_DEVICE | tail -1)
    DISK_SIZE=$(lsblk -d -o SIZE $DISK_DEVICE | tail -1)
    DISK_TYPE=$(lsblk -d -o TRAN $DISK_DEVICE | tail -1)
    FS_TYPE=$(df -T "$TEST_DIR" | awk 'END{print $2}')
}

# Humanize numbers
humanize() {
    local value=$1
    # Check if value is a number (integer or float)
    if [[ -z "$value" || ! "$value" =~ ^[0-9]*\.?[0-9]+$ ]]; then
        echo "N/A"
        return
    fi
    if (( $(echo "$value > 1000000000" | bc -l) )); then
        echo "$(echo "scale=2; $value/1000000000" | bc) GB/s"
    elif (( $(echo "$value > 1000000" | bc -l) )); then
        echo "$(echo "scale=2; $value/1000000" | bc) MB/s"
    elif (( $(echo "$value > 1000" | bc -l) )); then
        echo "$(echo "scale=2; $value/1000" | bc) KB/s"
    else
        echo "$value B/s"
    fi
}

# Get test result by name
get_test_result() {
    local name="$1"
    for ((i=0; i<${#TEST_RESULTS[@]}; i+=5)); do
        if [ "${TEST_RESULTS[i]}" = "$name" ]; then
            echo "${TEST_RESULTS[i+3]}"
            return
        fi
    done
    echo ""
}

# Run test and capture output
run_test() {
    local name=$1
    local command=$2
    local metric=$3

    echo -e "\n\e[1;34m===== Running $name =====\e[0m"
    echo "Command: $command"

    start=$(date +%s.%N)
    output=$(eval "$command" 2>&1)
    exit_code=$?
    duration=$(echo "$(date +%s.%N) - $start" | bc)

    if [ $exit_code -ne 0 ]; then
        echo -e "\e[1;31mERROR: Test failed - $name\e[0m"
        echo "$output"
        result="ERROR"
    else
        result=$(echo "$output" | grep -oP "$metric" | head -1)
        # Clean result: remove newlines, commas, and carriage returns
        result=$(echo "$result" | tr -d '\n\r,' | sed 's/[^0-9.]//g')
        if [ -z "$result" ]; then
            result="N/A"
            echo -e "\e[1;33mWARNING: Metric not found in output\e[0m"
        fi
    fi

    TEST_RESULTS+=("$name" "$command" "$output" "$result" "$duration")
}

# Generate HTML report
generate_html() {
    cat > "$OUTPUT_HTML" <<HTML
<!DOCTYPE html>
<html>
<head>
    <title>Disk Performance Benchmark Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f4f6f7; }
        h1, h2 { color: #2c3e50; }
        .summary { background-color: #ffffff; padding: 20px; border-radius: 8px; }
        .results { margin-top: 30px; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #3498db; color: white; }
        tr:hover { background-color: #f5f5f5; }
        .test { margin-bottom: 30px; padding: 15px; border: 1px solid #ddd; border-radius: 5px; background: #fff; }
        .test-title { color: #2980b9; cursor: pointer; }
        .test-content { display: none; margin-top: 10px; }
        .metric { font-weight: bold; color: #27ae60; }
        pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow: auto; }
        .good { color: #27ae60; }
        .medium { color: #f39c12; }
        .poor { color: #e74c3c; }
        .summary-table { width: 70%; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #3498db, #2c3e50); color: white; padding: 20px; text-align: center; border-radius: 8px; }
    </style>
    <script>
        function toggleTest(element) {
            const content = element.nextElementSibling;
            content.style.display = content.style.display === 'block' ? 'none' : 'block';
        }
    </script>
</head>
<body>
    <div class="header">
        <h1>Disk Performance Benchmark Report</h1>
        <p>Generated on $(date)</p>
    </div>

    <div class="summary">
        <h2>System Summary</h2>
        <table>
            <tr><th>Parameter</th><th>Value</th></tr>
            <tr><td>Test Directory</td><td>$TEST_DIR</td></tr>
            <tr><td>Disk Device</td><td>$DISK_DEVICE</td></tr>
            <tr><td>Disk Model</td><td>$DISK_MODEL</td></tr>
            <tr><td>Disk Size</td><td>$DISK_SIZE</td></tr>
            <tr><td>Disk Type</td><td>$DISK_TYPE</td></tr>
            <tr><td>File System</td><td>$FS_TYPE</td></tr>
            <tr><td>Test File Size</td><td>$SIZE</td></tr>
            <tr><td>Test Duration</td><td>${DURATION}s</td></tr>
        </table>

        <h2>Performance Summary</h2>
        <table class="summary-table">
            <tr>
                <th>Test</th>
                <th>Metric</th>
                <th>Performance</th>
            </tr>
HTML

    for ((i=0; i<${#TEST_RESULTS[@]}; i+=5)); do
        name="${TEST_RESULTS[i]}"
        command="${TEST_RESULTS[i+1]}"
        output="${TEST_RESULTS[i+2]}"
        result="${TEST_RESULTS[i+3]}"
        duration="${TEST_RESULTS[i+4]}"
        
        class=""
        rating=""
        display_value=""
        value_for_comparison=""

        if [[ -z "$result" || "$result" == "N/A" || "$result" == "ERROR" ]]; then
            display_value="$result"
        else
            if [[ "$name" == *"Sequential"* || "$name" == "HDparm Buffered Read" ]]; then
                if [[ "$name" == "HDparm Buffered Read" ]]; then
                    # Convert MB/s to bytes/s
                    value_for_comparison=$(echo "$result * 1000000" | bc -l)
                else
                    value_for_comparison="$result"
                fi
                display_value=$(humanize $value_for_comparison)
                
                # Evaluate performance rating
                if (( $(echo "$value_for_comparison > 500000000" | bc -l) )); then class="good"; rating="Excellent"
                elif (( $(echo "$value_for_comparison > 200000000" | bc -l) )); then class="good"; rating="Good"
                elif (( $(echo "$value_for_comparison > 100000000" | bc -l) )); then class="medium"; rating="Average"
                else class="poor"; rating="Poor"; fi
            elif [[ "$name" == *"Latency"* ]]; then
                display_value="$result ms"
                if (( $(echo "$result < 1" | bc -l) )); then class="good"; rating="Excellent"
                elif (( $(echo "$result < 5" | bc -l) )); then class="good"; rating="Good"
                elif (( $(echo "$result < 10" | bc -l) )); then class="medium"; rating="Average"
                else class="poor"; rating="Poor"; fi
            elif [[ "$name" == "Disk Utilization (SAR)" ]]; then
                display_value="$result%"
                # Lower is better
                if (( $(echo "$result < 50" | bc -l) )); then class="good"; rating="Excellent"
                elif (( $(echo "$result < 70" | bc -l) )); then class="good"; rating="Good"
                elif (( $(echo "$result < 85" | bc -l) )); then class="medium"; rating="Average"
                else class="poor"; rating="Poor"; fi
            elif [[ "$name" == *"Random"* || "$name" == *"Mixed"* || "$name" == "Total IOPS (4K Random)" ]]; then
                display_value="$result IOPS"
                if (( $(echo "$result > 100000" | bc -l) )); then class="good"; rating="Excellent"
                elif (( $(echo "$result > 50000" | bc -l) )); then class="good"; rating="Good"
                elif (( $(echo "$result > 20000" | bc -l) )); then class="medium"; rating="Average"
                else class="poor"; rating="Poor"; fi
            else
                display_value="$result"
            fi
        fi

        cat >> "$OUTPUT_HTML" <<HTML
            <tr>
                <td>$name</td>
                <td><span class="metric">$display_value</span></td>
                <td><span class="$class">$rating</span></td>
            </tr>
HTML
    done

    cat >> "$OUTPUT_HTML" <<HTML
        </table>
    </div>

    <div class="results">
        <h2>Detailed Test Results</h2>
HTML

    for ((i=0; i<${#TEST_RESULTS[@]}; i+=5)); do
        name="${TEST_RESULTS[i]}"
        command="${TEST_RESULTS[i+1]}"
        output="${TEST_RESULTS[i+2]}"
        result="${TEST_RESULTS[i+3]}"
        duration="${TEST_RESULTS[i+4]}"

        # Escape HTML special characters in output
        output_escaped=${output//</&lt;}
        output_escaped=${output_escaped//>/&gt;}

        cat >> "$OUTPUT_HTML" <<HTML
        <div class="test">
            <h3 class="test-title" onclick="toggleTest(this)">$name (${duration}s)</h3>
            <div class="test-content">
                <p><strong>Command:</strong> <code>$command</code></p>
                <p><strong>Result:</strong> <span class="metric">$result</span></p>
                <pre>$output_escaped</pre>
            </div>
        </div>
HTML
    done

    cat >> "$OUTPUT_HTML" <<HTML
    </div>

    <div style="margin-top: 40px; text-align: center; color: #7f8c8d;">
        <p>Generated by Disk Performance Benchmark Suite | $(date +%Y)</p>
    </div>
</body>
</html>
HTML
}

# Start Testing
get_disk_info

run_test "HDparm Buffered Read" \
    "hdparm -Tt $DISK_DEVICE | grep 'buffered disk reads' | awk '{print \$(NF-1)}'" \
    "[0-9]+(\.[0-9]+)?"

run_test "I/O Latency (Ioping)" \
    "ioping -c 10 -W $TEST_DIR | grep 'min/avg/max' | awk -F'=' '{print \$2}' | awk '{print \$1}'" \
    "[0-9]+(\.[0-9]+)?"

run_test "FIO Sequential Read" \
    "fio --name=seq_read --directory=$TEST_DIR --rw=read --size=$SIZE --runtime=$DURATION --output-format=json | jq '.jobs[0].read.bw'" \
    "[0-9]+"

run_test "FIO Sequential Write" \
    "fio --name=seq_write --directory=$TEST_DIR --rw=write --size=$SIZE --runtime=$DURATION --output-format=json | jq '.jobs[0].write.bw'" \
    "[0-9]+"

run_test "FIO Random Read (4K)" \
    "fio --name=rand_read --directory=$TEST_DIR --rw=randread --bs=4k --size=$SIZE --runtime=$DURATION --output-format=json | jq '.jobs[0].read.iops'" \
    "[0-9]+"

run_test "FIO Random Write (4K)" \
    "fio --name=rand_write --directory=$TEST_DIR --rw=randwrite --bs=4k --size=$SIZE --runtime=$DURATION --output-format=json | jq '.jobs[0].write.iops'" \
    "[0-9]+"

run_test "FIO Mixed Workload (70/30 R/W)" \
    "fio --name=mixed_io --directory=$TEST_DIR --rw=randrw --rwmixread=70 --bs=4k --size=$SIZE --runtime=$DURATION --output-format=json | jq '.jobs[0].read.iops + .jobs[0].write.iops | tonumber'" \
    "[0-9]+"

run_test "Disk Utilization (SAR)" \
    "LANG=C sar -d -p 1 5 | awk '/Average/ && \$2!=\"DEV\" {print \$NF}' | head -1" \
    "[0-9]+(\.[0-9]+)?"

# Add Total IOPS test
rand_read_iops=$(get_test_result "FIO Random Read (4K)")
rand_write_iops=$(get_test_result "FIO Random Write (4K)")

if [[ "$rand_read_iops" =~ ^[0-9.]+$ && "$rand_write_iops" =~ ^[0-9.]+$ ]]; then
    total_iops=$(echo "$rand_read_iops + $rand_write_iops" | bc)
    total_iops_int=$(printf "%.0f" "$total_iops")
    TEST_RESULTS+=("Total IOPS (4K Random)" "Calculated from FIO Random Read and Write" "" "$total_iops_int" "0")
else
    TEST_RESULTS+=("Total IOPS (4K Random)" "Calculated from FIO Random Read and Write" "" "ERROR" "0")
fi

generate_html

echo -e "\n\e[1;32mBenchmark complete!\e[0m"
echo -e "HTML Report saved to \e[1;34m$OUTPUT_HTML\e[0m"