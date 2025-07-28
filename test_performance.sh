#!/bin/bash
######################## test_performance.sh
# Performance comparison between Ustats.sh and Ustats_enhanced.sh
####################################

echo "🚀 UPlanet Performance Comparison Test"
echo "======================================="

# Test parameters
TEST_LAT="43.60"
TEST_LON="1.44" 
TEST_DEG="10"

echo "Test parameters: LAT=$TEST_LAT, LON=$TEST_LON, DEG=$TEST_DEG"
echo ""

# Function to measure execution time
measure_time() {
    local script="$1"
    local params="$2"
    local description="$3"
    
    echo "Testing: $description"
    echo "Command: $script $params"
    
    # Clear any existing cache
    rm -f ~/.zen/tmp/Ustats*.json 2>/dev/null
    rm -rf ~/.zen/tmp/ustats_enhanced 2>/dev/null
    
    # Measure execution time
    local start_time=$(date +%s%N)
    local temp_output=$(mktemp)
    local temp_stderr=$(mktemp)
    $script $params >$temp_output 2>$temp_stderr
    local end_time=$(date +%s%N)
    
    # Get the result file from stdout (last line that looks like a path)
    local result_file=$(grep "^/" $temp_output | tail -1)
    [[ -z "$result_file" ]] && result_file=$(tail -1 $temp_output)
    
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    
    if [[ -f "$result_file" ]]; then
        local file_size=$(du -h "$result_file" | cut -f1)
        local json_valid=$(jq -e . "$result_file" >/dev/null 2>&1 && echo "✅ Valid" || echo "❌ Invalid")
        local entities=$(jq -r '(.NOSTR // [] | length) + (.PLAYERs // [] | length) + (.UMAPs // [] | length)' "$result_file" 2>/dev/null)
        
        echo "  ⏱️  Duration: ${duration_ms}ms"
        echo "  📁 File size: $file_size"
        echo "  📊 JSON: $json_valid"
        echo "  🎯 Entities: $entities"
        echo "  📂 Cache: $result_file"
    else
        echo "  ❌ FAILED - No output file generated"
        echo "  📝 Last output: $(tail -1 $temp_output 2>/dev/null || echo 'none')"
        echo "  ⚠️  Last error: $(tail -1 $temp_stderr 2>/dev/null || echo 'none')"
    fi
    
    # Cleanup
    rm -f "$temp_output" "$temp_stderr"
    
    echo ""
    return $duration_ms
}

# Test original Ustats.sh
if [[ -f "$HOME/.zen/Astroport.ONE/Ustats.sh" ]]; then
    measure_time "$HOME/.zen/Astroport.ONE/Ustats.sh" "$TEST_LAT $TEST_LON $TEST_DEG" "🐌 Original Ustats.sh"
    ORIGINAL_TIME=$?
else
    echo "⚠️  Original Ustats.sh not found, skipping comparison"
    ORIGINAL_TIME=0
fi

# Test fixed version - normal mode
measure_time "$HOME/.zen/Astroport.ONE/Ustats_fixed.sh" "$TEST_LAT $TEST_LON $TEST_DEG" "⚡ Fixed Ustats.sh (Normal Mode)"
ENHANCED_TIME=$?

# Test fixed version - debug mode
measure_time "$HOME/.zen/Astroport.ONE/Ustats_fixed.sh" "--debug-timing $TEST_LAT $TEST_LON $TEST_DEG" "🚀 Fixed Ustats.sh (Debug Mode)"
TURBO_TIME=$?

# Test global mode (no coordinates)
measure_time "$HOME/.zen/Astroport.ONE/Ustats_fixed.sh" "" "🌍 Fixed Ustats.sh (Global Mode)"
GLOBAL_TIME=$?

# Performance comparison
echo "📊 PERFORMANCE COMPARISON"
echo "========================"

if [[ $ORIGINAL_TIME -gt 0 ]]; then
    enhanced_improvement=$(( (ORIGINAL_TIME * 100) / ENHANCED_TIME ))
    turbo_improvement=$(( (ORIGINAL_TIME * 100) / TURBO_TIME ))
    
    echo "Original Ustats.sh:      ${ORIGINAL_TIME}ms"
    echo "Fixed (Normal):          ${ENHANCED_TIME}ms (${enhanced_improvement}% of original)"
    echo "Fixed (Debug):           ${TURBO_TIME}ms (${turbo_improvement}% of original)"
    echo ""
    echo "🎯 Performance Gains:"
    echo "  Normal Mode: $(( (ORIGINAL_TIME - ENHANCED_TIME) * 100 / ORIGINAL_TIME ))% faster"
    echo "  Turbo Mode:  $(( (ORIGINAL_TIME - TURBO_TIME) * 100 / ORIGINAL_TIME ))% faster"
else
    echo "Fixed (Normal):          ${ENHANCED_TIME}ms"
    echo "Fixed (Debug):           ${TURBO_TIME}ms"
    echo "Fixed (Global):          ${GLOBAL_TIME}ms"
    
    if [[ $TURBO_TIME -lt $ENHANCED_TIME ]]; then
        echo "🚀 Debug mode is $(( (ENHANCED_TIME - TURBO_TIME) * 100 / ENHANCED_TIME ))% faster than normal mode"
    fi
fi

echo ""
echo "🔧 FEATURES COMPARISON"
echo "====================="

echo "Fixed features:"
echo "  ✅ Intelligent multi-level caching"
echo "  ✅ Parallel processing ($(nproc) cores detected)"
echo "  ✅ Optimized distance calculations"
echo "  ✅ Fast coordinate filtering"  
echo "  ✅ Integrated data extraction (no external scripts)"
echo "  ✅ JSON validation and error handling"
echo "  ✅ Performance monitoring and timing"
echo "  ✅ Turbo mode with background indexing"
echo "  ✅ Geographic pre-filtering"
echo "  ✅ Batch processing optimizations"

echo ""
echo "💡 RECOMMENDATIONS"
echo "=================="
echo "For production use:"
echo "  • Use --turbo mode for maximum performance"
echo "  • Enable --debug-timing for performance monitoring"
echo "  • Cache files are stored in ~/.zen/tmp/ustats_enhanced/"
echo "  • Parallel job count auto-detected: $(nproc) cores"

# Check dependencies
echo ""
echo "🔍 DEPENDENCY CHECK"
echo "==================="

dependencies=("parallel" "jq" "bc" "awk")
missing_deps=()

for dep in "${dependencies[@]}"; do
    if command -v "$dep" >/dev/null 2>&1; then
        echo "  ✅ $dep"
    else
        echo "  ❌ $dep (MISSING)"
        missing_deps+=("$dep")
    fi
done

if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo ""
    echo "⚠️  Missing dependencies: ${missing_deps[*]}"
    echo "Install with: sudo apt-get install ${missing_deps[*]}"
fi

echo ""
echo "✅ Performance test completed!" 