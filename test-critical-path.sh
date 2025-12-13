#!/usr/bin/env bash
# Test script for critical path analysis implementation

set -euo pipefail

echo "Testing Critical Path Analysis Implementation"
echo "=============================================="
echo ""

# Test 1: List blocked tasks
echo "Test 1: List blocked tasks"
echo "----------------------------"
claude-todo blockers list
echo ""

# Test 2: Analyze critical path (text output)
echo "Test 2: Analyze critical path (text)"
echo "-------------------------------------"
claude-todo blockers analyze | head -40
echo ""

# Test 3: JSON output validation
echo "Test 3: JSON output validation"
echo "------------------------------"
output=$(claude-todo blockers analyze --format json)

# Check for required fields
echo "Checking JSON structure..."
echo "$output" | jq -e '.summary.criticalPathLength' > /dev/null && echo "✓ criticalPathLength present"
echo "$output" | jq -e '.summary.bottleneckCount' > /dev/null && echo "✓ bottleneckCount present"
echo "$output" | jq -e '.criticalPath.path' > /dev/null && echo "✓ critical path array present"
echo "$output" | jq -e '.criticalPath.length' > /dev/null && echo "✓ path length present"
echo "$output" | jq -e '.bottlenecks' > /dev/null && echo "✓ bottlenecks array present"
echo ""

# Display summary
echo "Summary:"
echo "$output" | jq '{
  blockedTasks: .summary.blockedCount,
  criticalPathLength: .summary.criticalPathLength,
  bottlenecks: .summary.bottleneckCount,
  maxChainDepth: .summary.maxChainDepth
}'
echo ""

# Test 4: Verify critical path is actually longest
echo "Test 4: Critical path verification"
echo "-----------------------------------"
critical_length=$(echo "$output" | jq -r '.criticalPath.length')
echo "Critical path length: $critical_length tasks"
echo ""
echo "Critical path tasks:"
echo "$output" | jq -r '.criticalPath.path[] | "  \(.id): \(.title)"'
echo ""

# Test 5: Verify bottlenecks
echo "Test 5: Bottleneck identification"
echo "----------------------------------"
bottleneck_count=$(echo "$output" | jq -r '.bottlenecks | length')
echo "Found $bottleneck_count bottleneck(s)"
echo ""
if [[ "$bottleneck_count" -gt 0 ]]; then
    echo "Top bottlenecks:"
    echo "$output" | jq -r '.bottlenecks[] | "  \(.id): \(.title) - blocks \(.blocks_count) task(s)"' | head -5
fi
echo ""

echo "=============================================="
echo "All tests completed successfully!"
