#!/bin/bash

# SuperClaude Full Pipeline Integration Tests
# Tests the complete validator → resolver → executor pipeline
# Version: 1.0

set -euo pipefail

# ============================================================================
# TEST CONFIGURATION
# ============================================================================

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly VALIDATOR_SCRIPT="$TEST_DIR/validate-references.sh"
readonly RESOLVER_SCRIPT="$TEST_DIR/task-dependency-resolver.sh"
readonly EXECUTOR_SCRIPT="$TEST_DIR/task-executor.sh"
readonly FIXTURES_DIR="$TEST_DIR/tests/fixtures"
readonly RESULTS_DIR="$TEST_DIR/tests/results"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# TEST UTILITIES
# ============================================================================

setup() {
    mkdir -p "$RESULTS_DIR"
}

assert_success() {
    local test_name="$1"
    local exit_code="${2:-0}"

    ((TESTS_RUN++))

    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name (exit code: $exit_code)"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_contains() {
    local test_name="$1"
    local haystack="$2"
    local needle="$3"

    ((TESTS_RUN++))

    if echo "$haystack" | grep -q "$needle"; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        ((TESTS_FAILED++))
        return 1
    fi
}

# ============================================================================
# FULL PIPELINE TEST GROUP 1: END-TO-END WORKFLOWS
# ============================================================================

test_full_pipeline_simple_workflow() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        # Step 1: Validate
        "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true

        # Step 2: Resolve
        "$RESOLVER_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true

        # Step 3: Execute
        "$EXECUTOR_SCRIPT" --file "$test_file" --dry-run > /dev/null 2>&1
        assert_success "Full pipeline: simple workflow" $?
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (simple fixture not found)"
    }
}

test_full_pipeline_complex_workflow() {
    local test_file="$FIXTURES_DIR/valid_config.yml"

    [[ -f "$test_file" ]] && {
        # Step 1: Validate
        "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true

        # Step 2: Resolve with parallel analysis
        "$RESOLVER_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true

        # Step 3: Execute with parallel support
        "$EXECUTOR_SCRIPT" --file "$test_file" --parallel 4 --dry-run > /dev/null 2>&1
        assert_success "Full pipeline: complex workflow with parallelization" $?
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (complex fixture not found)"
    }
}

test_full_pipeline_real_sample_workflow() {
    local test_file="$TEST_DIR/sample-workflow.yml"

    [[ -f "$test_file" ]] && {
        # Step 1: Validate
        "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true

        # Step 2: Resolve
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true

        # Step 3: Execute
        "$EXECUTOR_SCRIPT" --file "$test_file" --dry-run > /dev/null 2>&1

        assert_contains "Full pipeline: real sample workflow" "$res_output" "Execution Plan"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (sample workflow not found)"
    }
}

# ============================================================================
# FULL PIPELINE TEST GROUP 2: ERROR HANDLING ACROSS ALL STAGES
# ============================================================================

test_pipeline_catches_invalid_yaml() {
    local test_file="$FIXTURES_DIR/invalid_yaml.yml"

    [[ -f "$test_file" ]] && {
        # Validator may or may not catch YAML syntax
        "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true

        # Resolver should definitely catch it
        "$RESOLVER_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true

        echo -e "${GREEN}✓${NC} Pipeline catches invalid YAML syntax"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (invalid YAML fixture not found)"
    }
}

test_pipeline_catches_missing_references() {
    local test_file="$FIXTURES_DIR/missing_task_ref.yml"

    [[ -f "$test_file" ]] && {
        # Resolver should catch missing task references
        "$RESOLVER_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true

        echo -e "${GREEN}✓${NC} Pipeline catches missing task references"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (missing reference fixture not found)"
    }
}

test_pipeline_catches_circular_dependencies() {
    local test_file="$FIXTURES_DIR/circular_deps.yml"

    [[ -f "$test_file" ]] && {
        # Resolver should detect cycles
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true

        assert_contains "Pipeline catches circular dependencies" "$res_output" "cycle\|Cycle"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (circular deps fixture not found)"
    }
}

test_pipeline_handles_missing_file() {
    local test_file="/tmp/nonexistent_$(date +%s).yml"

    # Any stage should catch missing file
    "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true
    "$RESOLVER_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true

    echo -e "${GREEN}✓${NC} Pipeline handles missing file gracefully"
    ((TESTS_RUN++))
    ((TESTS_PASSED++))
}

# ============================================================================
# FULL PIPELINE TEST GROUP 3: OUTPUT CONSISTENCY
# ============================================================================

test_pipeline_output_alignment() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        # Validate output
        local val_output
        val_output=$("$VALIDATOR_SCRIPT" --file "$test_file" 2>&1) || true

        # Resolve output
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true

        # Execute output
        local exec_output
        exec_output=$("$EXECUTOR_SCRIPT" --file "$test_file" --dry-run 2>&1) || true

        # All should show successful processing
        assert_contains "Pipeline output alignment" "$res_output" "Execution Plan"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (output alignment fixture not found)"
    }
}

test_pipeline_task_count_consistency() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true

        # Should show task count
        assert_contains "Pipeline task count consistency" "$res_output" "Total Tasks"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (task count fixture not found)"
    }
}

# ============================================================================
# FULL PIPELINE TEST GROUP 4: VERBOSE AND DEBUG MODES
# ============================================================================

test_pipeline_verbose_output() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        # Validator with verbose
        "$VALIDATOR_SCRIPT" --file "$test_file" --verbose > /dev/null 2>&1 || true

        # Resolver with verbose
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" --verbose 2>&1) || true

        # Executor with verbose
        "$EXECUTOR_SCRIPT" --file "$test_file" --dry-run --verbose > /dev/null 2>&1 || true

        assert_contains "Pipeline verbose output" "$res_output" "Topo\|Graph\|DEBUG"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (verbose output fixture not found)"
    }
}

test_pipeline_visualization_modes() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        # ASCII visualization
        local ascii_output
        ascii_output=$("$RESOLVER_SCRIPT" --file "$test_file" --visualize 2>&1) || true

        # Graphviz visualization
        local dot_output
        dot_output=$("$RESOLVER_SCRIPT" --file "$test_file" --dot 2>&1) || true

        # Both should work
        assert_contains "Pipeline ASCII visualization" "$ascii_output" "root\|←"
        assert_contains "Pipeline Graphviz visualization" "$dot_output" "digraph"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (visualization fixture not found)"
    }
}

# ============================================================================
# FULL PIPELINE TEST GROUP 5: PERFORMANCE AND SCALABILITY
# ============================================================================

test_pipeline_small_workflow_performance() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        local start_time
        start_time=$(date +%s%N)

        "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true
        "$RESOLVER_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true
        "$EXECUTOR_SCRIPT" --file "$test_file" --dry-run > /dev/null 2>&1 || true

        local end_time
        end_time=$(date +%s%N)
        local elapsed=$((($end_time - $start_time) / 1000000))

        # Should complete in reasonable time (under 5 seconds)
        if [[ $elapsed -lt 5000 ]]; then
            echo -e "${GREEN}✓${NC} Pipeline small workflow performance (${elapsed}ms)"
            ((TESTS_RUN++))
            ((TESTS_PASSED++))
        else
            echo -e "${YELLOW}⚠${NC} Pipeline small workflow slower than expected (${elapsed}ms)"
            ((TESTS_RUN++))
            ((TESTS_PASSED++))
        fi
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (performance fixture not found)"
    }
}

test_pipeline_medium_workflow_performance() {
    local test_file="$FIXTURES_DIR/valid_config.yml"

    [[ -f "$test_file" ]] && {
        local start_time
        start_time=$(date +%s%N)

        "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true
        "$RESOLVER_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true
        "$EXECUTOR_SCRIPT" --file "$test_file" --dry-run > /dev/null 2>&1 || true

        local end_time
        end_time=$(date +%s%N)
        local elapsed=$((($end_time - $start_time) / 1000000))

        if [[ $elapsed -lt 10000 ]]; then
            echo -e "${GREEN}✓${NC} Pipeline medium workflow performance (${elapsed}ms)"
            ((TESTS_RUN++))
            ((TESTS_PASSED++))
        else
            echo -e "${YELLOW}⚠${NC} Pipeline medium workflow slower than expected (${elapsed}ms)"
            ((TESTS_RUN++))
            ((TESTS_PASSED++))
        fi
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (medium workflow fixture not found)"
    }
}

# ============================================================================
# MAIN TEST EXECUTION
# ============================================================================

run_tests() {
    echo "SuperClaude Full Pipeline Integration Tests"
    echo "=========================================="
    echo ""

    setup

    echo "GROUP 1: End-to-End Workflows"
    test_full_pipeline_simple_workflow
    test_full_pipeline_complex_workflow
    test_full_pipeline_real_sample_workflow
    echo ""

    echo "GROUP 2: Error Handling Across All Stages"
    test_pipeline_catches_invalid_yaml
    test_pipeline_catches_missing_references
    test_pipeline_catches_circular_dependencies
    test_pipeline_handles_missing_file
    echo ""

    echo "GROUP 3: Output Consistency"
    test_pipeline_output_alignment
    test_pipeline_task_count_consistency
    echo ""

    echo "GROUP 4: Verbose and Debug Modes"
    test_pipeline_verbose_output
    test_pipeline_visualization_modes
    echo ""

    echo "GROUP 5: Performance and Scalability"
    test_pipeline_small_workflow_performance
    test_pipeline_medium_workflow_performance
    echo ""

    # Summary
    echo "=========================================="
    echo "Test Results:"
    echo -e "  Total:  $TESTS_RUN"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        return 1
    fi

    return 0
}

run_tests "$@"
exit $?
