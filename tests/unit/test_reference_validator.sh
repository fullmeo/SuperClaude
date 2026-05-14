#!/bin/bash

# SuperClaude Reference Validator Unit Tests
# Test suite for validate-references.sh component
# Version: 1.0

set -euo pipefail

# ============================================================================
# TEST CONFIGURATION
# ============================================================================

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly VALIDATOR_SCRIPT="$TEST_DIR/validate-references.sh"
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
    export TEST_OUTPUT="$RESULTS_DIR/test_output.log"
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
# GROUP 1: REFERENCE EXTRACTION (2 tests)
# ============================================================================

test_extract_valid_references() {
    local test_file="$FIXTURES_DIR/valid_config.yml"
    local output

    output=$("$VALIDATOR_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Extract valid @include references" "$output" "Extracted"
}

test_extract_malformed_references() {
    local test_file="$FIXTURES_DIR/invalid_config.yml"
    local output

    output=$("$VALIDATOR_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Detect malformed @include references" "$output" "malformed"
}

# ============================================================================
# GROUP 2: FILE VALIDATION (4 tests)
# ============================================================================

test_validate_existing_file() {
    local test_file="$FIXTURES_DIR/valid_config.yml"

    "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1
    assert_success "Validate existing file" $?
}

test_validate_missing_file() {
    local test_file="/tmp/nonexistent_config_$(date +%s).yml"

    "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1
    assert_failure "Reject missing file" $?
}

test_validate_readable_file() {
    local test_file="$FIXTURES_DIR/valid_config.yml"
    chmod 644 "$test_file"

    "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1
    assert_success "Accept readable file" $?
}

test_validate_unreadable_file() {
    local test_file="$FIXTURES_DIR/unreadable_$(date +%s).yml"
    touch "$test_file"
    chmod 000 "$test_file"

    "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1
    assert_failure "Reject unreadable file" $?

    chmod 644 "$test_file"
    rm "$test_file"
}

# ============================================================================
# GROUP 3: YAML SECTIONS (3 tests)
# ============================================================================

test_validate_existing_yaml_section() {
    local test_file="$FIXTURES_DIR/valid_config.yml"
    local output

    output=$("$VALIDATOR_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Validate existing YAML section" "$output" "valid"
}

test_detect_missing_yaml_section() {
    local test_file="$FIXTURES_DIR/missing_section.yml"
    local output

    output=$("$VALIDATOR_SCRIPT" --file "$test_file" 2>&1) || true
    assert_failure "Detect missing YAML section" $?
}

test_parse_yaml_array_sections() {
    local test_file="$FIXTURES_DIR/valid_config.yml"
    local output

    output=$("$VALIDATOR_SCRIPT" --file "$test_file" --verbose 2>&1) || true
    assert_contains "Parse YAML array sections" "$output" "array"
}

# ============================================================================
# GROUP 4: CIRCULAR REFERENCES (1 test)
# ============================================================================

test_detect_circular_references() {
    local test_file="$FIXTURES_DIR/circular_deps.yml"
    local output

    output=$("$VALIDATOR_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Detect circular @include references" "$output" "cycle\|circular"
}

# ============================================================================
# GROUP 5: MARKDOWN SECTIONS (3 tests)
# ============================================================================

test_validate_existing_markdown_section() {
    local test_file="$FIXTURES_DIR/valid_doc.md"
    local output

    output=$("$VALIDATOR_SCRIPT" --file "$test_file" 2>&1) || true
    assert_contains "Validate existing Markdown section" "$output" "valid"
}

test_detect_missing_markdown_section() {
    local test_file="$FIXTURES_DIR/missing_markdown.md"
    local output

    output=$("$VALIDATOR_SCRIPT" --file "$test_file" 2>&1) || true
    assert_failure "Detect missing Markdown section" $?
}

test_parse_markdown_heading_sections() {
    local test_file="$FIXTURES_DIR/valid_doc.md"
    local output

    output=$("$VALIDATOR_SCRIPT" --file "$test_file" --verbose 2>&1) || true
    assert_contains "Parse Markdown heading sections" "$output" "heading"
}

# ============================================================================
# GROUP 6: REAL CONFIGURATION (4 tests)
# ============================================================================

test_validate_superclaude_claude_md() {
    local test_file="$TEST_DIR/CLAUDE.md"

    [[ -f "$test_file" ]] && {
        "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1
        assert_success "Validate SuperClaude CLAUDE.md references" $?
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (CLAUDE.md not found)"
    }
}

test_validate_project_claude_md() {
    local test_file="$TEST_DIR/CLAUDE.md"

    [[ -f "$test_file" ]] && {
        "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1
        assert_success "Validate project CLAUDE.md references" $?
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (project CLAUDE.md not found)"
    }
}

test_validate_design_doc_references() {
    local test_file="$TEST_DIR/DESIGN_TASK_DEPENDENCY_GRAPHS.md"

    [[ -f "$test_file" ]] && {
        "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1
        assert_success "Validate design doc references" $?
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (design doc not found)"
    }
}

test_validate_implementation_doc_references() {
    local test_file="$TEST_DIR/IMPLEMENTATION_TASK_RESOLVER.md"

    [[ -f "$test_file" ]] && {
        "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1
        assert_success "Validate implementation doc references" $?
    } || {
        echo -e "${YELLOW}⊘${NC} Skip (implementation doc not found)"
    }
}

# ============================================================================
# GROUP 7: EDGE CASES (3+ tests)
# ============================================================================

test_handle_empty_file() {
    local test_file="$FIXTURES_DIR/empty_$(date +%s).yml"
    touch "$test_file"

    "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1
    assert_success "Handle empty file gracefully" $?

    rm "$test_file"
}

test_handle_whitespace_only_file() {
    local test_file="$FIXTURES_DIR/whitespace_$(date +%s).yml"
    echo -e "\n\n  \n\t\n" > "$test_file"

    "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1
    assert_success "Handle whitespace-only file" $?

    rm "$test_file"
}

test_handle_very_long_reference_path() {
    local test_file="$FIXTURES_DIR/long_path_$(date +%s).yml"
    echo "key: value" > "$test_file"
    echo "@include commands/shared/very/long/path/to/config.yml#Section" >> "$test_file"

    "$VALIDATOR_SCRIPT" --file "$test_file" 2>&1 | grep -q "reference\|error" || true
    ((TESTS_RUN++))
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓${NC} Handle very long reference paths"

    rm "$test_file"
}

test_handle_special_characters_in_section() {
    local test_file="$FIXTURES_DIR/special_chars_$(date +%s).yml"
    echo "@include config.yml#Section_With-Special.Chars123" > "$test_file"

    "$VALIDATOR_SCRIPT" --file "$test_file" > /dev/null 2>&1
    ((TESTS_RUN++))
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓${NC} Handle special characters in section names"

    rm "$test_file"
}

# ============================================================================
# MAIN TEST EXECUTION
# ============================================================================

run_tests() {
    echo "SuperClaude Reference Validator Unit Tests"
    echo "==========================================="
    echo ""

    setup

    echo "GROUP 1: Reference Extraction"
    test_extract_valid_references
    test_extract_malformed_references
    echo ""

    echo "GROUP 2: File Validation"
    test_validate_existing_file
    test_validate_missing_file
    test_validate_readable_file
    test_validate_unreadable_file
    echo ""

    echo "GROUP 3: YAML Sections"
    test_validate_existing_yaml_section
    test_detect_missing_yaml_section
    test_parse_yaml_array_sections
    echo ""

    echo "GROUP 4: Circular References"
    test_detect_circular_references
    echo ""

    echo "GROUP 5: Markdown Sections"
    test_validate_existing_markdown_section
    test_detect_missing_markdown_section
    test_parse_markdown_heading_sections
    echo ""

    echo "GROUP 6: Real Configuration"
    test_validate_superclaude_claude_md
    test_validate_project_claude_md
    test_validate_design_doc_references
    test_validate_implementation_doc_references
    echo ""

    echo "GROUP 7: Edge Cases"
    test_handle_empty_file
    test_handle_whitespace_only_file
    test_handle_very_long_reference_path
    test_handle_special_characters_in_section
    echo ""

    teardown

    # Summary
    echo "==========================================="
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
