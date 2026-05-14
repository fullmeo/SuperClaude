#!/bin/bash

# SuperClaude Reference Validation System
# Validates @include references in configuration files
# Version: 1.0
# License: MIT

set -o pipefail

# ============================================================================
# CONSTANTS & COLORS
# ============================================================================

readonly VALIDATOR_VERSION="1.0"
readonly SCRIPT_NAME="$(basename "$0")"

# Color detection
if [[ -t 1 ]] && [[ "$(tput colors 2>/dev/null)" -ge 8 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly BOLD='\033[1m'
    readonly NC='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly BOLD=''
    readonly NC=''
fi

# Limits
readonly MAX_RECURSION_DEPTH=10
readonly MAX_FILES=500

# ============================================================================
# CONFIGURATION
# ============================================================================

VERBOSE=false
REPORT_MODE=false
AUTO_FIX=false
EXIT_CODE=0

declare -a VALID_REFS=()
declare -a ERROR_REFS=()
declare -a WARNING_REFS=()

declare -A ERROR_TYPE=()
declare -A ERROR_MSG=()
declare -A ERROR_FILE=()
declare -A ERROR_LINE=()

declare -A GRAPH=()  # Adjacency list for dependencies
declare -A VISITED=()
declare -A RECURSION_STACK=()
declare -a CYCLES=()

TOTAL_REFS=0
VALID_COUNT=0
ERROR_COUNT=0
WARNING_COUNT=0
VALIDATION_TIME=0

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log_verbose() {
    [[ "$VERBOSE" == true ]] && echo "  ℹ $*" >&2
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*"
}

debug() {
    [[ "$VERBOSE" == true ]] && echo "  [DEBUG] $*" >&2
}

# ============================================================================
# REFERENCE EXTRACTION
# ============================================================================

extract_references() {
    local file="$1"
    local -a refs=()

    if [[ ! -f "$file" ]]; then
        log_verbose "Skipping non-existent file: $file"
        return 1
    fi

    # Match @include path/to/file.ext#SectionName
    while IFS= read -r line; do
        if [[ "$line" =~ @include[[:space:]]+([^#[:space:]]+)#([^[:space:]]+) ]]; then
            refs+=("${BASH_REMATCH[1]}#${BASH_REMATCH[2]}")
        fi
    done < "$file"

    printf '%s\n' "${refs[@]}"
}

get_file_from_reference() {
    local ref="$1"
    echo "${ref%#*}"
}

get_section_from_reference() {
    local ref="$1"
    echo "${ref##*#}"
}

# ============================================================================
# FILE VALIDATION
# ============================================================================

file_exists_and_readable() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    if [[ ! -r "$file" ]]; then
        return 1
    fi

    return 0
}

is_valid_file_path() {
    local path="$1"

    # Check for absolute paths (not allowed)
    if [[ "$path" =~ ^/ ]]; then
        return 1
    fi

    # Check extension
    if [[ ! "$path" =~ \.(yml|yaml|md)$ ]]; then
        return 1
    fi

    # Check for path traversal attempts
    if [[ "$path" =~ \.\. ]]; then
        return 1
    fi

    return 0
}

# ============================================================================
# YAML SECTION VALIDATION
# ============================================================================

get_yaml_sections() {
    local file="$1"
    local -a sections=()

    if [[ ! "${file}" =~ \.yml$ ]]; then
        return 1
    fi

    # Extract top-level YAML keys (sections)
    while IFS= read -r line; do
        # Match top-level keys (no leading whitespace)
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*):[[:space:]]*$ ]]; then
            sections+=("${BASH_REMATCH[1]}")
        fi
    done < "$file"

    printf '%s\n' "${sections[@]}"
}

get_markdown_sections() {
    local file="$1"
    local -a sections=()

    if [[ ! "${file}" =~ \.md$ ]]; then
        return 1
    fi

    # Extract markdown headers (# Header Name)
    while IFS= read -r line; do
        if [[ "$line" =~ ^#+[[:space:]]+([^#]+)$ ]]; then
            local header="${BASH_REMATCH[1]}"
            # Convert to snake_case for comparison
            header="${header// /_}"
            sections+=("$header")
        fi
    done < "$file"

    printf '%s\n' "${sections[@]}"
}

section_exists() {
    local file="$1"
    local section="$2"

    if [[ "${file}" =~ \.yml$ ]] || [[ "${file}" =~ \.yaml$ ]]; then
        while IFS= read -r sec; do
            [[ "$sec" == "$section" ]] && return 0
        done < <(get_yaml_sections "$file")
        return 1
    elif [[ "${file}" =~ \.md$ ]]; then
        while IFS= read -r sec; do
            [[ "$sec" == "$section" ]] && return 0
        done < <(get_markdown_sections "$file")
        return 1
    fi

    return 1
}

# ============================================================================
# YAML SYNTAX VALIDATION
# ============================================================================

validate_yaml_syntax() {
    local file="$1"

    if [[ ! "${file}" =~ \.yml$ ]]; then
        return 0
    fi

    # Basic YAML validation: check for common syntax errors

    # Check for unmatched brackets/braces
    local open_braces=$(grep -o '{' "$file" | wc -l)
    local close_braces=$(grep -o '}' "$file" | wc -l)
    if [[ $open_braces -ne $close_braces ]]; then
        return 1
    fi

    local open_brackets=$(grep -o '\[' "$file" | wc -l)
    local close_brackets=$(grep -o '\]' "$file" | wc -l)
    if [[ $open_brackets -ne $close_brackets ]]; then
        return 1
    fi

    # Check for invalid indentation (tabs not allowed, common error)
    if grep -q $'\t' "$file"; then
        return 1
    fi

    return 0
}

# ============================================================================
# GRAPH BUILDING
# ============================================================================

build_dependency_graph() {
    log_info "Building dependency graph..."

    local -a config_files=()
    mapfile -t config_files < <(find . -maxdepth 10 -type f \( -name "*.md" -o -name "*.yml" \) 2>/dev/null | head -n "$MAX_FILES")

    for file in "${config_files[@]}"; do
        file="${file#./}"  # Remove leading ./
        log_verbose "Scanning: $file"

        local -a refs=()
        mapfile -t refs < <(extract_references "$file")

        if [[ ${#refs[@]} -gt 0 ]]; then
            GRAPH["$file"]="${refs[*]}"
            log_verbose "  Found ${#refs[@]} references"
        fi
    done

    log_success "Graph built ($(echo "${!GRAPH[@]}" | wc -w) files with references)"
}

# ============================================================================
# CIRCULAR DEPENDENCY DETECTION (DFS)
# ============================================================================

dfs_visit() {
    local node="$1"
    local depth="$2"

    if [[ $depth -gt $MAX_RECURSION_DEPTH ]]; then
        log_warning "Max recursion depth exceeded at: $node"
        return 1
    fi

    VISITED["$node"]=1
    RECURSION_STACK["$node"]=1

    debug "Visiting: $node (depth: $depth)"

    local refs=("${GRAPH[$node]}")
    for ref in $refs; do
        local ref_file=$(get_file_from_reference "$ref")

        if [[ ! -v VISITED["$ref_file"] ]]; then
            dfs_visit "$ref_file" $((depth + 1))
        elif [[ "${RECURSION_STACK[$ref_file]}" == "1" ]]; then
            # Found a cycle
            CYCLES+=("$node -> $ref_file")
            debug "Cycle detected: $node -> $ref_file"
        fi
    done

    unset RECURSION_STACK["$node"]
}

detect_circular_references() {
    log_info "Detecting circular dependencies..."

    for file in "${!GRAPH[@]}"; do
        if [[ ! -v VISITED["$file"] ]]; then
            dfs_visit "$file" 0
        fi
    done

    if [[ ${#CYCLES[@]} -gt 0 ]]; then
        log_warning "Found ${#CYCLES[@]} circular reference(s)"
        return 1
    fi

    log_success "No circular dependencies detected"
    return 0
}

# ============================================================================
# REFERENCE VALIDATION
# ============================================================================

validate_references() {
    log_info "Validating references..."

    local -a all_files=()
    mapfile -t all_files < <(find . -maxdepth 10 -type f \( -name "*.md" -o -name "*.yml" \) 2>/dev/null | sed 's|^\./||')

    for file in "${all_files[@]}"; do
        local -a refs=()
        mapfile -t refs < <(extract_references "$file")

        for ref in "${refs[@]}"; do
            ((TOTAL_REFS++))

            local ref_file=$(get_file_from_reference "$ref")
            local ref_section=$(get_section_from_reference "$ref")

            log_verbose "Validating: $ref (in $file)"

            # 1. Check file path validity
            if ! is_valid_file_path "$ref_file"; then
                ERROR_TYPE["$ref"]="invalid_path"
                ERROR_MSG["$ref"]="Invalid file path: $ref_file"
                ERROR_FILE["$ref"]="$file"
                ERROR_LINE["$ref"]="?"
                ERROR_REFS+=("$ref")
                ((ERROR_COUNT++))
                continue
            fi

            # 2. Check file exists
            if ! file_exists_and_readable "$ref_file"; then
                ERROR_TYPE["$ref"]="missing_file"
                ERROR_MSG["$ref"]="File not found: $ref_file"
                ERROR_FILE["$ref"]="$file"
                ERROR_LINE["$ref"]="?"
                ERROR_REFS+=("$ref")
                ((ERROR_COUNT++))
                continue
            fi

            # 3. Check YAML syntax
            if ! validate_yaml_syntax "$ref_file"; then
                ERROR_TYPE["$ref"]="invalid_yaml"
                ERROR_MSG["$ref"]="Invalid YAML syntax in: $ref_file"
                ERROR_FILE["$ref"]="$file"
                ERROR_LINE["$ref"]="?"
                ERROR_REFS+=("$ref")
                ((ERROR_COUNT++))
                continue
            fi

            # 4. Check section exists
            if ! section_exists "$ref_file" "$ref_section"; then
                ERROR_TYPE["$ref"]="missing_section"
                ERROR_MSG["$ref"]="Section [$ref_section] not found in: $ref_file"
                ERROR_FILE["$ref"]="$file"
                ERROR_LINE["$ref"]="?"
                ERROR_REFS+=("$ref")
                ((ERROR_COUNT++))
                continue
            fi

            # All checks passed
            VALID_REFS+=("$ref")
            ((VALID_COUNT++))
        done
    done

    log_success "Validated $TOTAL_REFS references"

    if [[ $ERROR_COUNT -gt 0 ]]; then
        return 1
    fi
    return 0
}

# ============================================================================
# ORPHANED SECTION DETECTION
# ============================================================================

find_orphaned_sections() {
    log_info "Checking for orphaned sections..."

    local -a all_files=()
    mapfile -t all_files < <(find . -maxdepth 10 -type f \( -name "*.yml" -o -name "*.md" \) 2>/dev/null | sed 's|^\./||')

    # Collect all referenced sections
    declare -A referenced_sections=()
    for ref in "${VALID_REFS[@]}"; do
        local section=$(get_section_from_reference "$ref")
        referenced_sections["$section"]=1
    done

    # Check for unreferenced sections
    for file in "${all_files[@]}"; do
        local -a sections=()
        if [[ "$file" =~ \.yml$ ]]; then
            mapfile -t sections < <(get_yaml_sections "$file")
        elif [[ "$file" =~ \.md$ ]]; then
            mapfile -t sections < <(get_markdown_sections "$file")
        fi

        for section in "${sections[@]}"; do
            if [[ ! -v referenced_sections["$section"] ]]; then
                WARNING_REFS+=("$file#$section")
                ((WARNING_COUNT++))
                log_verbose "Orphaned section: $file#$section"
            fi
        done
    done

    if [[ $WARNING_COUNT -gt 0 ]]; then
        log_warning "Found $WARNING_COUNT orphaned section(s)"
    else
        log_success "No orphaned sections found"
    fi
}

# ============================================================================
# REPORT GENERATION
# ============================================================================

get_line_number() {
    local file="$1"
    local ref_string="$2"

    # Find line number containing the reference
    grep -n "$ref_string" "$file" 2>/dev/null | head -1 | cut -d: -f1
}

generate_report() {
    echo ""
    echo -e "${BOLD}${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${BLUE}│          REFERENCE VALIDATION REPORT                     │${NC}"
    echo -e "${BOLD}${BLUE}├─────────────────────────────────────────────────────────┤${NC}"
    echo ""

    # Timestamp
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Validator Version: $VALIDATOR_VERSION"
    echo "Project: $(pwd)"
    echo ""

    # Errors
    if [[ $ERROR_COUNT -gt 0 ]]; then
        echo -e "${RED}${BOLD}✗ ERRORS ($ERROR_COUNT):${NC}"
        echo ""

        local idx=1
        for ref in "${ERROR_REFS[@]}"; do
            local error_type="${ERROR_TYPE[$ref]}"
            local error_msg="${ERROR_MSG[$ref]}"
            local error_file="${ERROR_FILE[$ref]}"

            echo -e "${RED}$idx. ${error_type^^}${NC}"
            echo "   Reference: @include $ref"
            echo "   Location: $error_file"
            echo "   Issue: $error_msg"
            echo ""

            ((idx++))
        done
    fi

    # Warnings
    if [[ $WARNING_COUNT -gt 0 ]]; then
        echo -e "${YELLOW}${BOLD}⚠ WARNINGS ($WARNING_COUNT):${NC}"
        echo ""

        local idx=1
        for ref in "${WARNING_REFS[@]}"; do
            echo -e "${YELLOW}$idx. ORPHANED_SECTION${NC}"
            echo "   Section: $ref"
            echo "   Recommendation: Remove if unused"
            echo ""
            ((idx++))
        done
    fi

    # Summary
    echo -e "${BOLD}${BLUE}📊 SUMMARY:${NC}"
    echo "   Total References:     $TOTAL_REFS"
    echo "   Valid:                $VALID_COUNT"
    echo "   Errors:               $ERROR_COUNT (must fix)"
    echo "   Warnings:             $WARNING_COUNT (recommend fix)"
    echo "   Validation Time:      ${VALIDATION_TIME}ms"
    echo ""

    if [[ $ERROR_COUNT -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✓ All references are valid!${NC}"
    else
        echo -e "${RED}${BOLD}✗ Validation failed. Please fix errors above.${NC}"
    fi

    echo -e "${BOLD}${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose|-v)
                VERBOSE=true
                ;;
            --report|-r)
                REPORT_MODE=true
                ;;
            --fix)
                AUTO_FIX=true
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --version)
                echo "Reference Validator v$VALIDATOR_VERSION"
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

show_help() {
    cat << 'EOF'
SuperClaude Reference Validation System

Usage: ./validate-references.sh [OPTIONS]

Options:
  --verbose, -v    Enable verbose output
  --report, -r     Generate detailed report
  --fix            Auto-fix fixable issues (future)
  --help, -h       Show this help message
  --version        Show version information

Examples:
  ./validate-references.sh                 # Quick validation
  ./validate-references.sh --verbose       # With detailed output
  ./validate-references.sh --report        # With full report

Exit Codes:
  0                All references valid
  1                Validation errors found
EOF
}

main() {
    parse_arguments "$@"

    echo -e "${BOLD}SuperClaude Reference Validator v$VALIDATOR_VERSION${NC}"
    echo ""

    local start_time=$(date +%s%N)

    # Step 1: Build graph
    build_dependency_graph

    # Step 2: Detect circular refs
    detect_circular_references || EXIT_CODE=1

    # Step 3: Validate all references
    validate_references || EXIT_CODE=1

    # Step 4: Find orphaned sections
    find_orphaned_sections

    local end_time=$(date +%s%N)
    VALIDATION_TIME=$(( (end_time - start_time) / 1000000 ))

    # Generate report
    generate_report

    if [[ $EXIT_CODE -eq 0 ]]; then
        log_success "Validation completed successfully"
    else
        log_error "Validation completed with errors"
    fi

    return $EXIT_CODE
}

main "$@"
exit $?
