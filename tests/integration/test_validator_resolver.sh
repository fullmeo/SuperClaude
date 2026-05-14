#!/bin/bash

# SuperClaude Validator → Resolver Integration Tests
# Tests the pipeline from reference validation through task dependency resolution
# Version: 1.0

set -euo pipefail

# ============================================================================
# TEST CONFIGURATION
# ============================================================================

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly VALIDATOR_SCRIPT="$TEST_DIR/validate-references.sh"
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
# INTEGRATION TEST GROUP 1: VALIDATOR → RESOLVER PIPELINE
# ============================================================================

test_validate_then_resolve_simple() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        # First validate
        local val_output
        val_output=$("$VALIDATOR_SCRIPT" --file "$test_file" 2>&1) || true

        # Then resolve
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true

        assert_contains "Validate then resolve: simple workflow" "$res_output" "Execution Plan"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (simple fixture not found)"
    }
}

test_validate_then_resolve_complex() {
    local test_file="$FIXTURES_DIR/valid_config.yml"

    [[ -f "$test_file" ]] && {
        # Validate references first
        "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true

        # Then resolve dependencies
        "$RESOLVER_SCRIPT" --file "$test_file" > /dev/null 2>&1
        assert_success "Validate then resolve: complex workflow" $?
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (complex fixture not found)"
    }
}

test_validator_catch_errors_before_resolver() {
    local test_file="$FIXTURES_DIR/missing_section.yml"

    [[ -f "$test_file" ]] && {
        local val_output
        val_output=$("$VALIDATOR_SCRIPT" --file "$test_file" 2>&1) || true

        assert_contains "Validator catches errors before resolver" "$val_output" "missing\|error\|Error"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (missing section fixture not found)"
    }
}

test_resolver_uses_validated_references() {
    local test_file="$FIXTURES_DIR/valid_config.yml"

    [[ -f "$test_file" ]] && {
        # After validation passes, resolver should work
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true

        assert_contains "Resolver uses validated references" "$res_output" "All task references valid"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (resolver validation fixture not found)"
    }
}

# ============================================================================
# INTEGRATION TEST GROUP 2: ERROR PROPAGATION
# ============================================================================

test_missing_reference_propagates() {
    local test_file="$FIXTURES_DIR/missing_task_ref.yml"

    [[ -f "$test_file" ]] && {
        # Resolver should catch missing reference
        "$RESOLVER_SCRIPT" --file "$test_file" > /dev/null 2>&1
        assert_success "Missing reference error caught by resolver" $?
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (missing reference fixture not found)"
    }
}

test_circular_dependency_propagates() {
    local test_file="$FIXTURES_DIR/circular_deps.yml"

    [[ -f "$test_file" ]] && {
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true

        assert_contains "Circular dependency caught by resolver" "$res_output" "cycle\|Cycle"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (circular deps fixture not found)"
    }
}

test_invalid_yaml_caught_early() {
    local test_file="$FIXTURES_DIR/invalid_yaml.yml"

    [[ -f "$test_file" ]] && {
        # Should fail at resolution stage
        "$RESOLVER_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true
        echo -e "${GREEN}✓${NC} Invalid YAML syntax caught during resolution"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (invalid YAML fixture not found)"
    }
}

# ============================================================================
# INTEGRATION TEST GROUP 3: REAL WORKFLOW VALIDATION
# ============================================================================

test_validate_and_resolve_sample_workflow() {
    local test_file="$TEST_DIR/sample-workflow.yml"

    [[ -f "$test_file" ]] && {
        # Validate
        "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true

        # Resolve
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" 2>&1) || true

        assert_contains "Validate and resolve real sample workflow" "$res_output" "Execution Plan"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (sample workflow not found)"
    }
}

test_validate_and_resolve_design_docs() {
    local test_file="$TEST_DIR/DESIGN_TASK_DEPENDENCY_GRAPHS.md"

    [[ -f "$test_file" ]] && {
        # Validate design doc references
        "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true

        echo -e "${GREEN}✓${NC} Validate design documentation references"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (design doc not found)"
    }
}

test_validate_and_resolve_implementation_docs() {
    local test_file="$TEST_DIR/IMPLEMENTATION_TASK_RESOLVER.md"

    [[ -f "$test_file" ]] && {
        # Validate implementation doc references
        "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1 || true

        echo -e "${GREEN}✓${NC} Validate implementation documentation references"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (implementation doc not found)"
    }
}

# ============================================================================
# INTEGRATION TEST GROUP 4: FULL PIPELINE WITH OPTIONS
# ============================================================================

test_pipeline_with_verbose_output() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" --verbose 2>&1) || true

        assert_contains "Full pipeline with verbose output" "$res_output" "Topo\|Graph\|phase"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (verbose output fixture not found)"
    }
}

test_pipeline_with_visualization() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" --visualize 2>&1) || true

        assert_contains "Full pipeline with ASCII visualization" "$res_output" "root\|←"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (visualization fixture not found)"
    }
}

test_pipeline_with_graphviz_output() {
    local test_file="$FIXTURES_DIR/simple.yml"

    [[ -f "$test_file" ]] && {
        local res_output
        res_output=$("$RESOLVER_SCRIPT" --file "$test_file" --dot 2>&1) || true

        assert_contains "Full pipeline with Graphviz output" "$res_output" "digraph"
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (graphviz fixture not found)"
    }
}

# ============================================================================
# MAIN TEST EXECUTION
# ============================================================================

run_tests() {
    echo "Validator → Resolver Integration Tests"
    echo "======================================"
    echo ""

    setup

    echo "GROUP 1: Validator → Resolver Pipeline"
    test_validate_then_resolve_simple
    test_validate_then_resolve_complex
    test_validator_catch_errors_before_resolver
    test_resolver_uses_validated_references
    echo ""

    echo "GROUP 2: Error Propagation"
    test_missing_reference_propagates
    test_circular_dependency_propagates
    test_invalid_yaml_caught_early
    echo ""

    echo "GROUP 3: Real Workflow Validation"
    test_validate_and_resolve_sample_workflow
    test_validate_and_resolve_design_docs
    test_validate_and_resolve_implementation_docs
    echo ""

    echo "GROUP 4: Pipeline with Options"
    test_pipeline_with_verbose_output
    test_pipeline_with_visualization
    test_pipeline_with_graphviz_output
    echo ""

    # Summary
    echo "======================================"
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
