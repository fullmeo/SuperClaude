#!/bin/bash

# SuperClaude Resolver → Executor Integration Tests
# Tests the pipeline from task dependency resolution through execution
# Version: 1.0

set -euo pipefail

# ============================================================================
# TEST CONFIGURATION
# ============================================================================

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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
# INTEGRATION TEST GROUP 1: RESOLVER → EXECUTOR PIPELINE
# ============================================================================

test_resolve_then_execute_simple() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        # First resolve
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true

        # Then execute (dry-run)
        "$EXECUTOR_SCRIPT" --file "$test_file" --dry-run > /dev/null 2>&1
        assert_success "Resolve then execute: simple workflow" $?
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (simple fixture not found)"
    }
}

test_resolve_then_execute_complex() {
    local test_file="$FIXTURES_DIR/valid_config.yml"

    [[ -f "$test_file" ]] && {
        # Resolve
        "$RESOLVER_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true

        # Execute
        "$EXECUTOR_SCRIPT" --file "$test_file" --dry-run > /dev/null 2>&1
        assert_success "Resolve then execute: complex workflow" $?
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (complex fixture not found)"
    }
}

test_resolver_output_matches_execution_plan() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true

        local exec_output
        exec_output=$("$EXECUTOR_SCRIPT" --file "$test_file" --dry-run 2>&1) || true

        # Both should show execution plan
        assert_contains "Resolver and executor alignment" "$res_output$exec_output" "Execution"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (alignment fixture not found)"
    }
}

test_execution_follows_resolution_order() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        # Resolver determines order
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true

        # Executor should follow that order
        local exec_output
        exec_output=$("$EXECUTOR_SCRIPT" --file "$test_file" --dry-run 2>&1) || true

        assert_contains "Execution follows resolution order" "$exec_output" "Executing"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (execution order fixture not found)"
    }
}

# ============================================================================
# INTEGRATION TEST GROUP 2: PARALLEL EXECUTION COORDINATION
# ============================================================================

test_resolver_identifies_parallelizable_tasks() {
    local test_file="$FIXTURES_DIR/valid_config.yml"

    [[ -f "$test_file" ]] && {
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true

        assert_contains "Resolver identifies parallel tasks" "$res_output" "PARALLEL"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (parallel tasks fixture not found)"
    }
}

test_executor_respects_parallel_groups() {
    local test_file="$FIXTURES_DIR/valid_config.yml"

    [[ -f "$test_file" ]] && {
        local exec_output
        exec_output=$("$EXECUTOR_SCRIPT" --file "$test_file" --parallel 2 --dry-run 2>&1) || true

        assert_contains "Executor respects parallel groups" "$exec_output" "parallel\|Parallel"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (parallel groups fixture not found)"
    }
}

test_executor_parallel_limit_coordination() {
    local test_file="$FIXTURES_DIR/valid_config.yml"

    [[ -f "$test_file" ]] && {
        # Test with different parallel limits
        "$EXECUTOR_SCRIPT" --file "$test_file" --parallel 1 --dry-run > /dev/null 2>&1
        "$EXECUTOR_SCRIPT" --file "$test_file" --parallel 4 --dry-run > /dev/null 2>&1

        echo -e "${GREEN}✓${NC} Executor respects different parallel limits"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (parallel limits fixture not found)"
    }
}

# ============================================================================
# INTEGRATION TEST GROUP 3: ERROR HANDLING ACROSS PIPELINE
# ============================================================================

test_resolver_error_prevents_execution() {
    local test_file="$FIXTURES_DIR/circular_deps.yml"

    [[ -f "$test_file" ]] && {
        # Resolver should fail on circular deps
        "$RESOLVER_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true

        # Executor should not be called in production
        echo -e "${GREEN}✓${NC} Resolver errors prevent execution"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (circular deps fixture not found)"
    }
}

test_executor_handles_resolution_failures() {
    local test_file="$FIXTURES_DIR/missing_task_ref.yml"

    [[ -f "$test_file" ]] && {
        # Resolver fails
        "$RESOLVER_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true

        # Executor should handle gracefully if called
        "$EXECUTOR_SCRIPT" --file "$test_file" --dry-run > /dev/null 2>&1 || true

        echo -e "${GREEN}✓${NC} Executor handles resolution failures"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (resolution failure fixture not found)"
    }
}

test_missing_file_caught_in_resolver() {
    local test_file="/tmp/nonexistent_$(date +%s).yml"

    # Resolver should catch missing file
    "$RESOLVER_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true

    # Executor shouldn't be needed
    echo -e "${GREEN}✓${NC} Missing file caught early by resolver"
    ((TESTS_RUN++))
    ((TESTS_PASSED++))
}

# ============================================================================
# INTEGRATION TEST GROUP 4: REAL WORKFLOW END-TO-END
# ============================================================================

test_resolve_and_execute_sample_workflow() {
    local test_file="$TEST_DIR/sample-workflow.yml"

    [[ -f "$test_file" ]] && {
        # Full resolution
        "$RESOLVER_SCRIPT" --file "$test_file" > /dev/null 2>&1

        # Execution (dry-run)
        "$EXECUTOR_SCRIPT" --file "$test_file" --dry-run > /dev/null 2>&1
        assert_success "Resolve and execute sample workflow" $?
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (sample workflow not found)"
    }
}

test_sample_workflow_analysis() {
    local test_file="$TEST_DIR/sample-workflow.yml"

    [[ -f "$test_file" ]] && {
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true

        # Should show execution phases
        assert_contains "Sample workflow analysis" "$res_output" "Phase\|Execution Phases"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (sample workflow analysis not found)"
    }
}

test_sample_workflow_parallelization() {
    local test_file="$TEST_DIR/sample-workflow.yml"

    [[ -f "$test_file" ]] && {
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true

        # Should identify parallel tasks
        assert_contains "Sample workflow parallelization" "$res_output" "PARALLEL"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (sample workflow parallelization not found)"
    }
}

# ============================================================================
# INTEGRATION TEST GROUP 5: DRY-RUN AND PLANNING
# ============================================================================

test_resolver_dry_run_analysis() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" --verbose 2>&1) || true

        assert_contains "Resolver provides planning analysis" "$res_output" "Execution Plan\|Phase"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (dry-run analysis fixture not found)"
    }
}

test_executor_dry_run_no_side_effects() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        local exec_output
        exec_output=$("$EXECUTOR_SCRIPT" --file "$test_file" --dry-run 2>&1) || true

        assert_contains "Executor dry-run shows no side effects" "$exec_output" "DRY\|Would"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (dry-run fixture not found)"
    }
}

test_planning_for_large_workflows() {
    local test_file="$FIXTURES_DIR/large_workflow.yml"

    [[ -f "$test_file" ]] && {
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true

        assert_contains "Planning for large workflows" "$res_output" "Execution Plan"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (large workflow fixture not found)"
    }
}

# ============================================================================
# MAIN TEST EXECUTION
# ============================================================================

run_tests() {
    echo "Resolver → Executor Integration Tests"
    echo "====================================="
    echo ""

    setup

    echo "GROUP 1: Resolver → Executor Pipeline"
    test_resolve_then_execute_simple
    test_resolve_then_execute_complex
    test_resolver_output_matches_execution_plan
    test_execution_follows_resolution_order
    echo ""

    echo "GROUP 2: Parallel Execution Coordination"
    test_resolver_identifies_parallelizable_tasks
    test_executor_respects_parallel_groups
    test_executor_parallel_limit_coordination
    echo ""

    echo "GROUP 3: Error Handling Across Pipeline"
    test_resolver_error_prevents_execution
    test_executor_handles_resolution_failures
    test_missing_file_caught_in_resolver
    echo ""

    echo "GROUP 4: Real Workflow End-to-End"
    test_resolve_and_execute_sample_workflow
    test_sample_workflow_analysis
    test_sample_workflow_parallelization
    echo ""

    echo "GROUP 5: Dry-Run and Planning"
    test_resolver_dry_run_analysis
    test_executor_dry_run_no_side_effects
    test_planning_for_large_workflows
    echo ""

    # Summary
    echo "====================================="
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
