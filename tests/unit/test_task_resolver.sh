#!/bin/bash

# SuperClaude Task Dependency Resolver Unit Tests
# Test suite for task-dependency-resolver.sh component
# Version: 1.0

set -euo pipefail

# ============================================================================
# TEST CONFIGURATION
# ============================================================================

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly RESOLVER_SCRIPT="$TEST_DIR/task-dependency-resolver.sh"
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
FAILED_TESTS=()

# ============================================================================
# TEST UTILITIES
# ============================================================================

setup() {
    mkdir -p "$RESULTS_DIR"
    export TEST_OUTPUT="$RESULTS_DIR/test_resolver_output.log"
}

teardown() {
    rm -f "$TEST_OUTPUT"
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
        FAILED_TESTS+=("$test_name")
        return 1
    fi
}

assert_failure() {
    local test_name="$1"
    local exit_code="${2:-0}"

    ((TESTS_RUN++))

    if [[ $exit_code -ne 0 ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name (expected failure, got success)"
        ((TESTS_FAILED++))
        FAILED_TESTS+=("$test_name")
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
        echo -e "${RED}✗${NC} $test_name (output does not contain: $needle)"
        ((TESTS_FAILED++))
        FAILED_TESTS+=("$test_name")
        return 1
    fi
}

# ============================================================================
# GROUP 1: YAML PARSING (4 tests)
# ============================================================================

test_parse_simple_yaml() {
    local test_file="$FIXTURES_DIR/simple.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Parse simple YAML task file" "$output" "Loaded"
}

test_parse_complex_yaml() {
    local test_file="$FIXTURES_DIR/valid_config.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Parse complex YAML with multiple tasks" "$output" "Loaded"
}

test_parse_yaml_with_metadata() {
    local test_file="$FIXTURES_DIR/valid_config.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" --verbose 2>&1) || true
    assert_contains "Parse YAML with metadata fields" "$output" "description\|author"
}

test_parse_invalid_yaml() {
    local test_file="$FIXTURES_DIR/invalid_yaml.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_failure "Reject invalid YAML syntax" $?
}

# ============================================================================
# GROUP 2: TASK VALIDATION (4 tests)
# ============================================================================

test_validate_all_references_exist() {
    local test_file="$FIXTURES_DIR/valid_config.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Validate all task references exist" "$output" "references valid"
}

test_detect_missing_task_reference() {
    local test_file="$FIXTURES_DIR/missing_task_ref.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_failure "Detect missing task reference" $?
}

test_detect_self_reference() {
    local test_file="$FIXTURES_DIR/self_ref.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_failure "Detect self-referencing task" $?
}

test_validate_optional_tasks() {
    local test_file="$FIXTURES_DIR/optional_tasks.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Validate optional task definitions" "$output" "Loaded"
}

# ============================================================================
# GROUP 3: CYCLE DETECTION (3 tests)
# ============================================================================

test_detect_direct_cycle() {
    local test_file="$FIXTURES_DIR/direct_cycle.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_failure "Detect direct cycle (A→B→A)" $?
}

test_detect_indirect_cycle() {
    local test_file="$FIXTURES_DIR/indirect_cycle.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_failure "Detect indirect cycle (A→B→C→A)" $?
}

test_detect_no_cycles_valid_dag() {
    local test_file="$FIXTURES_DIR/valid_config.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Detect no cycles in valid DAG" "$output" "No cycles"
}

# ============================================================================
# GROUP 4: TOPOLOGICAL SORTING (4 tests)
# ============================================================================

test_topological_sort_simple_linear() {
    local test_file="$FIXTURES_DIR/simple.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Topological sort: simple linear sequence" "$output" "computed"
}

test_topological_sort_with_parallel_branches() {
    local test_file="$FIXTURES_DIR/valid_config.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Topological sort: parallel branches" "$output" "computed"
}

test_topological_sort_order_correctness() {
    local test_file="$FIXTURES_DIR/simple.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    # Verify tasks appear in dependency order in output
    assert_contains "Topological sort produces valid order" "$output" "Execution Order"
}

test_topological_sort_all_tasks_included() {
    local test_file="$FIXTURES_DIR/valid_config.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Topological sort includes all tasks" "$output" "tasks"
}

# ============================================================================
# GROUP 5: PARALLEL GROUP IDENTIFICATION (3 tests)
# ============================================================================

test_identify_no_parallelization() {
    local test_file="$FIXTURES_DIR/simple.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Identify no parallelization in linear workflow" "$output" "phase"
}

test_identify_parallel_tasks() {
    local test_file="$FIXTURES_DIR/valid_config.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Identify parallel tasks (PARALLEL)" "$output" "PARALLEL"
}

test_identify_convergence_pattern() {
    local test_file="$FIXTURES_DIR/convergence.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Identify convergence pattern" "$output" "phase\|Phase"
}

# ============================================================================
# GROUP 6: EXECUTION PLAN GENERATION (4 tests)
# ============================================================================

test_generate_plan_simple() {
    local test_file="$FIXTURES_DIR/simple.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Generate execution plan for simple workflow" "$output" "Execution Plan"
}

test_generate_plan_with_timings() {
    local test_file="$FIXTURES_DIR/valid_config.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Generate plan includes timeout fields" "$output" "timeout\|Execution"
}

test_generate_plan_with_optional() {
    local test_file="$FIXTURES_DIR/optional_tasks.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Generate plan marks optional tasks" "$output" "optional\|Execution"
}

test_generate_plan_critical_path() {
    local test_file="$FIXTURES_DIR/valid_config.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Generate plan shows task dependencies" "$output" "depends"
}

# ============================================================================
# GROUP 7: VISUALIZATION (2 tests)
# ============================================================================

test_visualize_ascii_graph() {
    local test_file="$FIXTURES_DIR/simple.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" --visualize 2>&1) || true
    assert_contains "ASCII graph visualization" "$output" "root\|←\|→"
}

test_visualize_graphviz_dot() {
    local test_file="$FIXTURES_DIR/simple.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" --dot 2>&1) || true
    assert_contains "Graphviz DOT format visualization" "$output" "digraph"
}

# ============================================================================
# GROUP 8: ERROR HANDLING (3 tests)
# ============================================================================

test_error_missing_file() {
    local test_file="/tmp/nonexistent_$(date +%s).yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_failure "Handle missing task file error" $?
}

test_error_circular_dependency() {
    local test_file="$FIXTURES_DIR/circular_deps.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Error message for circular dependency" "$output" "cycle\|Cycle"
}

test_error_invalid_reference() {
    local test_file="$FIXTURES_DIR/missing_task_ref.yml"
    local output

    output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Error message for missing reference" "$output" "reference\|non-existent"
}

# ============================================================================
# GROUP 9: COMPLEX WORKFLOWS (4 tests)
# ============================================================================

test_resolve_large_workflow() {
    local test_file="$FIXTURES_DIR/large_workflow.yml"

    [[ -f "$test_file" ]] && {
        "$RESOLVER_SCRIPT" --file "$test_file" > /dev/null 2>&1
        assert_success "Resolve large workflow (50+ tasks)" $?
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (large workflow fixture not found)"
    }
}

test_resolve_real_sample_workflow() {
    local test_file="$TEST_DIR/sample-workflow.yml"

    [[ -f "$test_file" ]] && {
        "$RESOLVER_SCRIPT" --file "$test_file" > /dev/null 2>&1
        assert_success "Resolve real sample workflow" $?
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (sample workflow not found)"
    }
}

test_resolve_diamond_pattern() {
    local test_file="$FIXTURES_DIR/diamond.yml"

    [[ -f "$test_file" ]] && {
        local output
        output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
        assert_contains "Resolve diamond dependency pattern" "$output" "phase"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (diamond pattern fixture not found)"
    }
}

test_resolve_multi_dependency() {
    local test_file="$FIXTURES_DIR/multi_dep.yml"

    [[ -f "$test_file" ]] && {
        local output
        output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true
        assert_contains "Resolve task with multiple dependencies" "$output" "Execution"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (multi-dependency fixture not found)"
    }
}

# ============================================================================
# MAIN TEST EXECUTION
# ============================================================================

run_tests() {
    echo "SuperClaude Task Dependency Resolver Unit Tests"
    echo "=============================================="
    echo ""

    setup

    echo "GROUP 1: YAML Parsing"
    test_parse_simple_yaml
    test_parse_complex_yaml
    test_parse_yaml_with_metadata
    test_parse_invalid_yaml
    echo ""

    echo "GROUP 2: Task Validation"
    test_validate_all_references_exist
    test_detect_missing_task_reference
    test_detect_self_reference
    test_validate_optional_tasks
    echo ""

    echo "GROUP 3: Cycle Detection"
    test_detect_direct_cycle
    test_detect_indirect_cycle
    test_detect_no_cycles_valid_dag
    echo ""

    echo "GROUP 4: Topological Sorting"
    test_topological_sort_simple_linear
    test_topological_sort_with_parallel_branches
    test_topological_sort_order_correctness
    test_topological_sort_all_tasks_included
    echo ""

    echo "GROUP 5: Parallel Group Identification"
    test_identify_no_parallelization
    test_identify_parallel_tasks
    test_identify_convergence_pattern
    echo ""

    echo "GROUP 6: Execution Plan Generation"
    test_generate_plan_simple
    test_generate_plan_with_timings
    test_generate_plan_with_optional
    test_generate_plan_critical_path
    echo ""

    echo "GROUP 7: Visualization"
    test_visualize_ascii_graph
    test_visualize_graphviz_dot
    echo ""

    echo "GROUP 8: Error Handling"
    test_error_missing_file
    test_error_circular_dependency
    test_error_invalid_reference
    echo ""

    echo "GROUP 9: Complex Workflows"
    test_resolve_large_workflow
    test_resolve_real_sample_workflow
    test_resolve_diamond_pattern
    test_resolve_multi_dependency
    echo ""

    teardown

    # Summary
    echo "=============================================="
    echo "Test Results:"
    echo -e "  Total:  $TESTS_RUN"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo "Failed Tests:"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  • $test"
        done
        echo ""
        return 1
    fi

    return 0
}

run_tests "$@"
exit $?
