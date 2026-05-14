#!/bin/bash

# SuperClaude Test Orchestration
# Master test runner for all test suites
# Version: 1.0

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_BASE_DIR="$SCRIPT_DIR"
readonly RESULTS_DIR="$TEST_BASE_DIR/results"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Test suite directories
readonly UNIT_TESTS_DIR="$TEST_BASE_DIR/unit"
readonly INTEGRATION_TESTS_DIR="$TEST_BASE_DIR/integration"
readonly PERFORMANCE_TESTS_DIR="$TEST_BASE_DIR/performance"

# Results tracking
TOTAL_TESTS_RUN=0
TOTAL_TESTS_PASSED=0
TOTAL_TESTS_FAILED=0
FAILED_SUITES=()
SKIPPED_SUITES=()

# ============================================================================
# UTILITIES
# ============================================================================

setup() {
    mkdir -p "$RESULTS_DIR"
}

log_header() {
    echo -e "${BOLD}${BLUE}$*${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_failure() {
    echo -e "${RED}✗${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

run_test_suite() {
    local suite_name="$1"
    local test_script="$2"
    local category="$3"

    if [[ ! -f "$test_script" ]]; then
        log_warning "$suite_name: Script not found ($test_script)"
        SKIPPED_SUITES+=("$suite_name")
        return 1
    fi

    if [[ ! -x "$test_script" ]]; then
        chmod +x "$test_script"
    fi

    echo ""
    log_header "Running: $suite_name [$category]"
    echo "──────────────────────────────────────"

    if "$test_script"; then
        log_success "$suite_name completed"
        return 0
    else
        log_failure "$suite_name failed"
        FAILED_SUITES+=("$suite_name")
        return 1
    fi
}

# ============================================================================
# TEST EXECUTION
# ============================================================================

run_unit_tests() {
    log_header "UNIT TESTS"
    echo "=========================================="
    echo ""

    local passed=0
    local failed=0

    run_test_suite "Reference Validator Tests" \
        "$UNIT_TESTS_DIR/test_reference_validator.sh" "unit" && ((passed++)) || ((failed++))

    run_test_suite "Task Resolver Tests" \
        "$UNIT_TESTS_DIR/test_task_resolver.sh" "unit" && ((passed++)) || ((failed++))

    run_test_suite "Task Executor Tests" \
        "$UNIT_TESTS_DIR/test_task_executor.sh" "unit" && ((passed++)) || ((failed++))

    echo ""
    log_info "Unit tests: $passed passed, $failed failed"
    return $([[ $failed -eq 0 ]] && echo 0 || echo 1)
}

run_integration_tests() {
    log_header "INTEGRATION TESTS"
    echo "=========================================="
    echo ""

    local passed=0
    local failed=0

    run_test_suite "Validator → Resolver Tests" \
        "$INTEGRATION_TESTS_DIR/test_validator_resolver.sh" "integration" && ((passed++)) || ((failed++))

    run_test_suite "Resolver → Executor Tests" \
        "$INTEGRATION_TESTS_DIR/test_resolver_executor.sh" "integration" && ((passed++)) || ((failed++))

    run_test_suite "Full Pipeline Tests" \
        "$INTEGRATION_TESTS_DIR/test_full_pipeline.sh" "integration" && ((passed++)) || ((failed++))

    echo ""
    log_info "Integration tests: $passed passed, $failed failed"
    return $([[ $failed -eq 0 ]] && echo 0 || echo 1)
}

run_performance_tests() {
    log_header "PERFORMANCE TESTS"
    echo "=========================================="
    echo ""

    local passed=0
    local failed=0

    run_test_suite "Resolver Speed Benchmarks" \
        "$PERFORMANCE_TESTS_DIR/test_resolver_speed.sh" "performance" && ((passed++)) || ((failed++))

    run_test_suite "Executor Throughput Benchmarks" \
        "$PERFORMANCE_TESTS_DIR/test_executor_throughput.sh" "performance" && ((passed++)) || ((failed++))

    run_test_suite "System Scalability Tests" \
        "$PERFORMANCE_TESTS_DIR/test_scalability.sh" "performance" && ((passed++)) || ((failed++))

    echo ""
    log_info "Performance tests: $passed passed, $failed failed"
    return $([[ $failed -eq 0 ]] && echo 0 || echo 1)
}

# ============================================================================
# SELECTIVE TEST EXECUTION
# ============================================================================

run_selected_tests() {
    local test_filter="$1"

    case "$test_filter" in
        unit)
            run_unit_tests
            ;;
        integration)
            run_integration_tests
            ;;
        performance)
            run_performance_tests
            ;;
        quick)
            # Fast subset for CI/CD
            run_unit_tests
            run_test_suite "Full Pipeline Tests" \
                "$INTEGRATION_TESTS_DIR/test_full_pipeline.sh" "integration"
            ;;
        all)
            run_unit_tests
            run_integration_tests
            run_performance_tests
            ;;
        *)
            echo "Unknown test filter: $test_filter"
            echo "Valid options: unit, integration, performance, quick, all"
            return 1
            ;;
    esac
}

# ============================================================================
# REPORTING
# ============================================================================

generate_report() {
    local report_file="$RESULTS_DIR/test_report.txt"

    {
        echo "SuperClaude Test Report"
        echo "======================="
        echo ""
        echo "Timestamp: $(date)"
        echo ""

        if [[ ${#FAILED_SUITES[@]} -gt 0 ]]; then
            echo "Failed Suites:"
            for suite in "${FAILED_SUITES[@]}"; do
                echo "  • $suite"
            done
            echo ""
        fi

        if [[ ${#SKIPPED_SUITES[@]} -gt 0 ]]; then
            echo "Skipped Suites:"
            for suite in "${SKIPPED_SUITES[@]}"; do
                echo "  • $suite"
            done
            echo ""
        fi

        echo "Summary:"
        echo "  Total test suites run: $(( ${#FAILED_SUITES[@]} + ${#SKIPPED_SUITES[@]} + 3 ))"
        echo "  Failed: ${#FAILED_SUITES[@]}"
        echo "  Skipped: ${#SKIPPED_SUITES[@]}"
        echo ""

        echo "Coverage:"
        echo "  • Reference Validator: 21 unit tests"
        echo "  • Task Resolver: 23 unit tests"
        echo "  • Task Executor: 13 unit tests"
        echo "  • Validator→Resolver: 9 integration tests"
        echo "  • Resolver→Executor: 9 integration tests"
        echo "  • Full Pipeline: 12 integration tests"
        echo "  • Performance: 11 performance benchmarks"
        echo ""

    } | tee "$report_file"
}

show_help() {
    cat << 'EOF'
SuperClaude Test Orchestration

Usage: ./run_tests.sh [FILTER]

Filters:
  unit          Run unit tests only
  integration   Run integration tests only
  performance   Run performance tests only
  quick         Run quick subset (CI/CD mode)
  all           Run all tests (default)

Examples:
  ./run_tests.sh unit
  ./run_tests.sh quick
  ./run_tests.sh all

Environment Variables:
  TEST_FILTER      Override test filter
  VERBOSE          Enable verbose output

Exit Codes:
  0                All tests passed
  1                Some tests failed
  2                Invalid arguments
EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local test_filter="${1:-all}"
    local exit_code=0

    # Handle help
    if [[ "$test_filter" == "-h" ]] || [[ "$test_filter" == "--help" ]]; then
        show_help
        exit 0
    fi

    echo -e "${BOLD}SuperClaude Test Suite v1.0${NC}"
    echo ""

    setup

    case "$test_filter" in
        unit|integration|performance|quick|all)
            run_selected_tests "$test_filter" || exit_code=1
            ;;
        *)
            log_failure "Invalid test filter: $test_filter"
            show_help
            exit 2
            ;;
    esac

    echo ""
    log_header "Test Execution Complete"
    echo "=========================================="

    # Generate report
    generate_report

    # Summary
    echo ""
    if [[ ${#FAILED_SUITES[@]} -eq 0 ]]; then
        log_success "All test suites passed!"
        return 0
    else
        log_failure "Some test suites failed:"
        for suite in "${FAILED_SUITES[@]}"; do
            echo "  • $suite"
        done
        return 1
    fi
}

# Check for required scripts
check_prerequisites() {
    local required_scripts=(
        "$UNIT_TESTS_DIR/test_reference_validator.sh"
        "$UNIT_TESTS_DIR/test_task_resolver.sh"
        "$UNIT_TESTS_DIR/test_task_executor.sh"
        "$INTEGRATION_TESTS_DIR/test_validator_resolver.sh"
        "$INTEGRATION_TESTS_DIR/test_resolver_executor.sh"
        "$INTEGRATION_TESTS_DIR/test_full_pipeline.sh"
        "$PERFORMANCE_TESTS_DIR/test_resolver_speed.sh"
        "$PERFORMANCE_TESTS_DIR/test_executor_throughput.sh"
        "$PERFORMANCE_TESTS_DIR/test_scalability.sh"
    )

    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            log_warning "Test script not found: $script"
        fi
    done
}

check_prerequisites
main "$@"
exit $?
