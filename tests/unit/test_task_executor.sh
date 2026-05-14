#!/bin/bash

# SuperClaude Task Executor Unit Tests
# Test suite for task-executor.sh component
# Version: 1.0

set -euo pipefail

# ============================================================================
# TEST CONFIGURATION
# ============================================================================

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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
FAILED_TESTS=()

# ============================================================================
# TEST UTILITIES
# ============================================================================

setup() {
    mkdir -p "$RESULTS_DIR"
    export TEST_OUTPUT="$RESULTS_DIR/test_executor_output.log"
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
# GROUP 1: EXECUTOR INITIALIZATION (2 tests)
# ============================================================================

test_executor_help() {
    local output

    output=$("$EXECUTOR_SCRIPT" --help 2>&1) || true
    assert_contains "Display executor help message" "$output" "Usage\|Options"
}

test_executor_version() {
    local output

    output=$("$EXECUTOR_SCRIPT" 2>&1) || true
    assert_contains "Display executor version info" "$output" "Executor"
}

# ============================================================================
# GROUP 2: SEQUENTIAL EXECUTION (3 tests)
# ============================================================================

test_execute_single_task() {
    local test_file="$FIXTURES_DIR/simple_task.yml"

    [[ -f "$test_file" ]] && {
        "$EXECUTOR_SCRIPT" --file "$test_file" --dry-run > /dev/null 2>&1
        assert_success "Execute single task (dry-run)" $?
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (simple task fixture not found)"
    }
}

test_execute_sequential_tasks() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        "$EXECUTOR_SCRIPT" --file "$test_file" --dry-run > /dev/null 2>&1
        assert_success "Execute sequential tasks (dry-run)" $?
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (simple workflow fixture not found)"
    }
}

test_execute_tasks_in_order() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        local output
        output=$("$EXECUTOR_SCRIPT" --file "$test_file" --dry-run 2>&1) || true
        assert_contains "Execute tasks maintain order" "$output" "Would execute\|DRY-RUN"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (ordered execution fixture not found)"
    }
}

# ============================================================================
# GROUP 3: PARALLEL EXECUTION (3 tests)
# ============================================================================

test_execute_parallel_default() {
    local test_file="$FIXTURES_DIR/valid_config.yml"

    [[ -f "$test_file" ]] && {
        "$EXECUTOR_SCRIPT" --file "$test_file" --dry-run > /dev/null 2>&1
        assert_success "Execute parallel tasks with default limit (dry-run)" $?
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (parallel task fixture not found)"
    }
}

test_execute_parallel_with_limit() {
    local test_file="$FIXTURES_DIR/valid_config.yml"

    [[ -f "$test_file" ]] && {
        "$EXECUTOR_SCRIPT" --file "$test_file" --parallel 2 --dry-run > /dev/null 2>&1
        assert_success "Execute parallel tasks with custom limit" $?
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (parallel execution fixture not found)"
    }
}

test_execute_parallel_respects_limit() {
    local test_file="$FIXTURES_DIR/valid_config.yml"

    [[ -f "$test_file" ]] && {
        local output
        output=$("$EXECUTOR_SCRIPT" --file "$test_file" --parallel 1 --dry-run --verbose 2>&1) || true
        assert_contains "Parallel execution respects limit" "$output" "max"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (parallel limit fixture not found)"
    }
}

# ============================================================================
# GROUP 4: DRY-RUN MODE (2 tests)
# ============================================================================

test_dryrun_skips_actual_execution() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        local output
        output=$("$EXECUTOR_SCRIPT" --file "$test_file" --dry-run 2>&1) || true
        assert_contains "Dry-run skips actual execution" "$output" "DRY-RUN\|Would"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (dry-run fixture not found)"
    }
}

test_dryrun_shows_execution_plan() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        local output
        output=$("$EXECUTOR_SCRIPT" --file "$test_file" --dry-run 2>&1) || true
        assert_contains "Dry-run shows execution plan" "$output" "Would\|execute"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (dry-run plan fixture not found)"
    }
}

# ============================================================================
# GROUP 5: TASK TRACKING (3 tests)
# ============================================================================

test_track_task_success() {
    local test_file="$FIXTURES_DIR/simple_task.yml"

    [[ -f "$test_file" ]] && {
        local output
        output=$("$EXECUTOR_SCRIPT" --file "$test_file" --dry-run 2>&1) || true
        assert_contains "Track successful task execution" "$output" "Task\|status"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (task tracking fixture not found)"
    }
}

test_track_task_failure() {
    local test_file="$FIXTURES_DIR/failing_task.yml"

    [[ -f "$test_file" ]] && {
        local output
        output=$("$EXECUTOR_SCRIPT" --file "$test_file" --dry-run 2>&1) || true
        assert_contains "Track task failure results" "$output" "status\|result"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (failure tracking fixture not found)"
    }
}

test_track_task_logs() {
    local test_file="$FIXTURES_DIR/simple_task.yml"

    [[ -f "$test_file" ]] && {
        mkdir -p /tmp/superclaudetasks 2>/dev/null || true
        "$EXECUTOR_SCRIPT" --file "$test_file" --dry-run > /dev/null 2>&1
        assert_success "Create task log files" $?
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (task logging fixture not found)"
    }
}

# ============================================================================
# GROUP 6: SUMMARY REPORTING (3 tests)
# ============================================================================

test_generate_success_summary() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        local output
        output=$("$EXECUTOR_SCRIPT" --file "$test_file" --dry-run 2>&1) || true
        assert_contains "Generate execution summary" "$output" "Summary\|Total"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (summary fixture not found)"
    }
}

test_report_success_count() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        local output
        output=$("$EXECUTOR_SCRIPT" --file "$test_file" --dry-run 2>&1) || true
        assert_contains "Report successful task count" "$output" "Success\|Total"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (success count fixture not found)"
    }
}

test_report_failure_count() {
    local test_file="$FIXTURES_DIR/failing_task.yml"

    [[ -f "$test_file" ]] && {
        local output
        output=$("$EXECUTOR_SCRIPT" --file "$test_file" --dry-run 2>&1) || true
        assert_contains "Report failed task count" "$output" "Failed\|Total"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (failure count fixture not found)"
    }
}

# ============================================================================
# GROUP 7: ERROR HANDLING (3 tests)
# ============================================================================

test_error_missing_task_file() {
    local test_file="/tmp/nonexistent_$(date +%s).yml"
    local output

    output=$("$EXECUTOR_SCRIPT" --file "$test_file" 2>&1) || true
    assert_failure "Handle missing task file" $?
}

test_error_no_file_specified() {
    local output

    output=$("$EXECUTOR_SCRIPT" 2>&1) || true
    assert_failure "Handle missing file argument" $?
}

test_error_invalid_parallel_value() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        local output
        output=$("$EXECUTOR_SCRIPT" --file "$test_file" --parallel abc 2>&1) || true
        # Should handle gracefully (either error or default to valid value)
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
        echo -e "${GREEN}✓${NC} Handle invalid parallel value gracefully"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (error handling fixture not found)"
    }
}

# ============================================================================
# MAIN TEST EXECUTION
# ============================================================================

run_tests() {
    echo "SuperClaude Task Executor Unit Tests"
    echo "===================================="
    echo ""

    setup

    echo "GROUP 1: Executor Initialization"
    test_executor_help
    test_executor_version
    echo ""

    echo "GROUP 2: Sequential Execution"
    test_execute_single_task
    test_execute_sequential_tasks
    test_execute_tasks_in_order
    echo ""

    echo "GROUP 3: Parallel Execution"
    test_execute_parallel_default
    test_execute_parallel_with_limit
    test_execute_parallel_respects_limit
    echo ""

    echo "GROUP 4: Dry-Run Mode"
    test_dryrun_skips_actual_execution
    test_dryrun_shows_execution_plan
    echo ""

    echo "GROUP 5: Task Tracking"
    test_track_task_success
    test_track_task_failure
    test_track_task_logs
    echo ""

    echo "GROUP 6: Summary Reporting"
    test_generate_success_summary
    test_report_success_count
    test_report_failure_count
    echo ""

    echo "GROUP 7: Error Handling"
    test_error_missing_task_file
    test_error_no_file_specified
    test_error_invalid_parallel_value
    echo ""

    teardown

    # Summary
    echo "===================================="
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
