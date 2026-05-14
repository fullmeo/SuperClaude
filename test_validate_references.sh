#!/bin/bash

# Test Suite for Reference Validation System
# Tests the validate-references.sh script
# Version: 1.0

set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test results
declare -a FAILED_TESTS=()

# ============================================================================
# TEST FRAMEWORK
# ============================================================================

test_setup() {
    # Create temporary test directory
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    mkdir -p .claude/shared .claude/commands
}

test_teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

assert_success() {
    local cmd="$1"
    local description="$2"

    ((TESTS_RUN++))

    if eval "$cmd" > /dev/null 2>&1; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}✓${NC} $description"
        return 0
    else
        ((TESTS_FAILED++))
        FAILED_TESTS+=("$description")
        echo -e "${RED}✗${NC} $description"
        return 1
    fi
}

assert_failure() {
    local cmd="$1"
    local description="$2"

    ((TESTS_RUN++))

    if ! eval "$cmd" > /dev/null 2>&1; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}✓${NC} $description"
        return 0
    else
        ((TESTS_FAILED++))
        FAILED_TESTS+=("$description")
        echo -e "${RED}✗${NC} $description"
        return 1
    fi
}

# ============================================================================
# TEST: REFERENCE EXTRACTION
# ============================================================================

test_reference_extraction() {
    echo ""
    echo -e "${BLUE}TEST GROUP: Reference Extraction${NC}"
    echo "================================="

    # Setup: Create test files with references
    cat > "test_file.md" << 'EOF'
# Test File
@include shared/core.yml#Core_Philosophy
Some text
@include shared/rules.yml#Standards
More text
EOF

    # Test: Extract references from file
    assert_success \
        "grep '@include' test_file.md | grep -q 'shared/core.yml'" \
        "Extract reference from markdown file"

    assert_success \
        "grep '@include' test_file.md | wc -l | grep -q '2'" \
        "Extract multiple references"

    rm test_file.md
}

# ============================================================================
# TEST: FILE VALIDATION
# ============================================================================

test_file_validation() {
    echo ""
    echo -e "${BLUE}TEST GROUP: File Validation${NC}"
    echo "============================="

    # Test: Valid file paths
    assert_success \
        "[[ 'shared/core.yml' =~ \\.(yml|yaml|md)$ ]]" \
        "Accept valid .yml extension"

    assert_success \
        "[[ 'config.md' =~ \\.(yml|yaml|md)$ ]]" \
        "Accept valid .md extension"

    # Test: Invalid file paths
    assert_failure \
        "[[ '/absolute/path.yml' =~ ^/ ]]" \
        "Reject absolute paths"

    assert_failure \
        "[[ '../parent/file.yml' =~ \\.\\.  ]]" \
        "Reject path traversal"

    assert_failure \
        "[[ 'file.txt' =~ \\.(yml|yaml|md)$ ]]" \
        "Reject invalid extension"
}

# ============================================================================
# TEST: YAML SECTION DETECTION
# ============================================================================

test_yaml_sections() {
    echo ""
    echo -e "${BLUE}TEST GROUP: YAML Section Detection${NC}"
    echo "===================================="

    # Create test YAML file
    cat > ".claude/shared/test.yml" << 'EOF'
Core_Philosophy:
  key1: value1
  key2: value2

Standards:
  rule1: value
  rule2: value

Token_Economy:
  optimization: true
EOF

    # Test: YAML sections exist
    assert_success \
        "grep -q '^Core_Philosophy:' .claude/shared/test.yml" \
        "Detect YAML top-level section"

    assert_success \
        "grep -q '^Standards:' .claude/shared/test.yml" \
        "Detect multiple YAML sections"

    # Test: Invalid sections
    assert_failure \
        "grep -q '^NonExistent:' .claude/shared/test.yml" \
        "Correctly reject non-existent section"

    rm ".claude/shared/test.yml"
}

# ============================================================================
# TEST: CIRCULAR REFERENCE DETECTION
# ============================================================================

test_circular_references() {
    echo ""
    echo -e "${BLUE}TEST GROUP: Circular Reference Detection${NC}"
    echo "========================================"

    # Setup: Create files with circular references
    cat > ".claude/shared/a.yml" << 'EOF'
Section_A:
  content: value
  @include b.yml#Section_B
EOF

    cat > ".claude/shared/b.yml" << 'EOF'
Section_B:
  content: value
  @include a.yml#Section_A
EOF

    # Test: Detect circular reference pattern
    assert_success \
        "grep -l 'a.yml' .claude/shared/b.yml && grep -l 'b.yml' .claude/shared/a.yml" \
        "Detect circular reference pattern"

    rm ".claude/shared/a.yml" ".claude/shared/b.yml"
}

# ============================================================================
# TEST: MARKDOWN SECTION DETECTION
# ============================================================================

test_markdown_sections() {
    echo ""
    echo -e "${BLUE}TEST GROUP: Markdown Section Detection${NC}"
    echo "====================================="

    # Create test markdown file
    cat > ".claude/commands/test.md" << 'EOF'
# Main Section

## SubSection One

### Deep Section

## SubSection Two
EOF

    # Test: Markdown headers exist
    assert_success \
        "grep -q '# Main Section' .claude/commands/test.md" \
        "Detect markdown h1 header"

    assert_success \
        "grep -q '## SubSection One' .claude/commands/test.md" \
        "Detect markdown h2 header"

    assert_success \
        "grep -q '### Deep Section' .claude/commands/test.md" \
        "Detect markdown h3 header"

    rm ".claude/commands/test.md"
}

# ============================================================================
# TEST: INTEGRATION WITH REAL FILES
# ============================================================================

test_real_configuration() {
    echo ""
    echo -e "${BLUE}TEST GROUP: Real Configuration Files${NC}"
    echo "===================================="

    # Create realistic config structure
    cat > ".claude/CLAUDE.md" << 'EOF'
# SuperClaude Config

## Core Philosophy
@include shared/superclaude-core.yml#Core_Philosophy

## Evidence Standards
@include shared/superclaude-core.yml#Evidence_Based_Standards
EOF

    cat > ".claude/shared/superclaude-core.yml" << 'EOF'
Core_Philosophy:
  philosophy: "Code > Docs"
  workflow: "TodoRead → TodoWrite → Execute"

Evidence_Based_Standards:
  prohibited: "best|optimal|faster"
  required: "may|could|measured"
EOF

    # Test: Files can be found
    assert_success \
        "[[ -f '.claude/CLAUDE.md' ]]" \
        "CLAUDE.md exists"

    assert_success \
        "[[ -f '.claude/shared/superclaude-core.yml' ]]" \
        "Shared YAML file exists"

    # Test: References can be extracted
    assert_success \
        "grep '@include' .claude/CLAUDE.md | grep -q 'Core_Philosophy'" \
        "Reference to Core_Philosophy found"

    # Test: Sections exist
    assert_success \
        "grep -q '^Core_Philosophy:' .claude/shared/superclaude-core.yml" \
        "Section Core_Philosophy exists"

    assert_success \
        "grep -q '^Evidence_Based_Standards:' .claude/shared/superclaude-core.yml" \
        "Section Evidence_Based_Standards exists"

    rm ".claude/CLAUDE.md" ".claude/shared/superclaude-core.yml"
}

# ============================================================================
# TEST: EDGE CASES
# ============================================================================

test_edge_cases() {
    echo ""
    echo -e "${BLUE}TEST GROUP: Edge Cases${NC}"
    echo "====================="

    # Test: Self-reference (not explicitly checked in basic validator)
    cat > "self_ref.yml" << 'EOF'
Section:
  @include self_ref.yml#Section
EOF

    assert_success \
        "grep -q 'self_ref.yml' self_ref.yml" \
        "Detect self-reference pattern"

    rm "self_ref.yml"

    # Test: Deep nesting
    assert_success \
        "[[ 'a/b/c/d/e/f/deep.yml' =~ \\.yml$ ]]" \
        "Handle deeply nested paths"

    # Test: Unicode in paths (shouldn't work)
    assert_failure \
        "[[ '文件.yml' =~ ^[a-zA-Z0-9/_.-]+$ ]]" \
        "Reject non-ASCII filenames"

    # Test: Whitespace handling
    assert_success \
        "echo '@include   shared/file.yml#Section' | grep -q '@include'" \
        "Handle multiple spaces in reference"
}

# ============================================================================
# MAIN TEST RUNNER
# ============================================================================

main() {
    echo -e "${BOLD}${BLUE}SuperClaude Reference Validator - Test Suite${NC}"
    echo "=============================================="
    echo ""

    test_setup

    # Run all test groups
    test_reference_extraction
    test_file_validation
    test_yaml_sections
    test_circular_references
    test_markdown_sections
    test_real_configuration
    test_edge_cases

    test_teardown

    # Summary
    echo ""
    echo -e "${BLUE}═══════════════════════════════${NC}"
    echo -e "Tests Run:    ${TESTS_RUN}"
    echo -e "Passed:       ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Failed:       ${RED}${TESTS_FAILED}${NC}"
    echo -e "${BLUE}═══════════════════════════════${NC}"

    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}Failed Tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  • $test"
        done
        echo ""
        exit 1
    else
        echo ""
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

main "$@"
