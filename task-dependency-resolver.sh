#!/bin/bash

# SuperClaude Task Dependency Graph Resolver
# Parses task definitions, builds dependency graphs, and generates execution plans
# Version: 1.0
# License: MIT

set -o pipefail

# ============================================================================
# CONSTANTS & CONFIGURATION
# ============================================================================

readonly RESOLVER_VERSION="1.0"
readonly SCRIPT_NAME="$(basename "$0")"

# Colors
if [[ -t 1 ]] && [[ "$(tput colors 2>/dev/null)" -ge 8 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly BOLD='\033[1m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

# Limits
readonly MAX_RECURSION_DEPTH=20
readonly MAX_TASKS=1000

# ============================================================================
# GLOBAL STATE
# ============================================================================

declare -A TASKS=()              # tasks[id] = json_definition
declare -A GRAPH=()              # graph[id] = "dep1 dep2 dep3"
declare -A REVERSE_GRAPH=()      # reverse_graph[id] = "dependent1"
declare -a TASK_LIST=()          # Ordered list of task IDs
declare -a TOPO_ORDER=()         # Topological sort result
declare -a PARALLEL_GROUPS=()    # Execution groups
declare -a CYCLES=()             # Found cycles

declare -A VISITED=()
declare -A RECURSION_STACK=()

VERBOSE=false
EXIT_CODE=0

# ============================================================================
# LOGGING
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
# YAML PARSING (SIMPLIFIED)
# ============================================================================

parse_yaml_task() {
    local file="$1"
    local in_tasks=false
    local current_task=""
    local current_deps=""

    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Detect tasks section
        if [[ "$line" =~ ^tasks:$ ]]; then
            in_tasks=true
            continue
        fi

        if [[ "$in_tasks" == false ]]; then
            continue
        fi

        # Detect task definition (no leading whitespace)
        if [[ "$line" =~ ^[a-z_][a-z0-9_-]*:$ ]]; then
            local task_id="${line%:}"
            current_task="$task_id"
            current_deps=""
            TASK_LIST+=("$task_id")
            debug "Found task: $task_id"
            continue
        fi

        # Parse depends-on field
        if [[ -n "$current_task" ]] && [[ "$line" =~ depends-on:(.+) ]]; then
            local deps="${BASH_REMATCH[1]}"
            # Remove brackets and whitespace
            deps="${deps//[\[\]]/}"
            deps="${deps//,/ }"
            deps=$(echo "$deps" | xargs)  # Trim whitespace
            current_deps="$deps"
            debug "Task $current_task depends on: $deps"
            continue
        fi

        # Parse description (optional)
        if [[ -n "$current_task" ]] && [[ "$line" =~ description:(.+) ]]; then
            local desc="${BASH_REMATCH[1]}"
            desc="${desc// }"
            debug "Task $current_task description: $desc"
        fi
    done < "$file"

    # Store graph edges
    for task_id in "${TASK_LIST[@]}"; do
        # Extract depends-on for this task (simplified - scan again)
        local deps=$(grep -A 10 "^$task_id:" "$file" | \
                     grep "depends-on:" | head -1 | \
                     sed 's/.*depends-on:[[:space:]]*\[\(.*\)\].*/\1/' | \
                     tr ',' ' ')

        if [[ -n "$deps" ]]; then
            GRAPH["$task_id"]="$deps"
            # Build reverse graph
            for dep in $deps; do
                REVERSE_GRAPH["$dep"]+=" $task_id"
            done
            log_verbose "Graph[$task_id] = $deps"
        fi
    done
}

# ============================================================================
# GRAPH VALIDATION
# ============================================================================

validate_task_references() {
    log_info "Validating task references..."

    local errors=0

    for task_id in "${TASK_LIST[@]}"; do
        local deps="${GRAPH[$task_id]}"

        for dep in $deps; do
            # Check if dependency exists
            local found=false
            for t in "${TASK_LIST[@]}"; do
                if [[ "$t" == "$dep" ]]; then
                    found=true
                    break
                fi
            done

            if [[ "$found" == false ]]; then
                log_error "Task '$task_id' references non-existent task '$dep'"
                ((errors++))
            fi
        done
    done

    if [[ $errors -gt 0 ]]; then
        log_error "Validation failed: $errors missing task reference(s)"
        return 1
    fi

    log_success "All task references valid"
    return 0
}

# ============================================================================
# CYCLE DETECTION (DFS)
# ============================================================================

dfs_visit() {
    local node="$1"
    local depth="${2:-0}"

    if [[ $depth -gt $MAX_RECURSION_DEPTH ]]; then
        log_warning "Max recursion depth exceeded at: $node"
        return 1
    fi

    VISITED["$node"]=1
    RECURSION_STACK["$node"]=1

    debug "DFS visit: $node (depth: $depth)"

    local deps="${GRAPH[$node]}"
    for dep in $deps; do
        if [[ -z "${VISITED[$dep]}" ]]; then
            dfs_visit "$dep" $((depth + 1))
        elif [[ "${RECURSION_STACK[$dep]}" == "1" ]]; then
            # Cycle found
            CYCLES+=("$node -> $dep")
            log_error "Cycle detected: $node → $dep"
        fi
    done

    unset RECURSION_STACK["$node"]
}

detect_cycles() {
    log_info "Detecting cycles..."

    CYCLES=()
    VISITED=()
    RECURSION_STACK=()

    for task_id in "${TASK_LIST[@]}"; do
        if [[ -z "${VISITED[$task_id]}" ]]; then
            dfs_visit "$task_id" 0
        fi
    done

    if [[ ${#CYCLES[@]} -gt 0 ]]; then
        log_error "Found ${#CYCLES[@]} cycle(s):"
        for cycle in "${CYCLES[@]}"; do
            log_error "  $cycle"
        done
        return 1
    fi

    log_success "No cycles detected (valid DAG)"
    return 0
}

# ============================================================================
# TOPOLOGICAL SORT (KAHN'S ALGORITHM)
# ============================================================================

topological_sort() {
    log_info "Computing topological order..."

    TOPO_ORDER=()

    # Calculate in-degrees
    declare -A in_degree
    for task_id in "${TASK_LIST[@]}"; do
        in_degree["$task_id"]=0
    done

    for task_id in "${TASK_LIST[@]}"; do
        local deps="${GRAPH[$task_id]}"
        for dep in $deps; do
            ((in_degree["$dep"]++))
        done
    done

    # Queue of nodes with no dependencies
    local -a queue=()
    for task_id in "${TASK_LIST[@]}"; do
        if [[ ${in_degree[$task_id]:-0} -eq 0 ]]; then
            queue+=("$task_id")
        fi
    done

    while [[ ${#queue[@]} -gt 0 ]]; do
        local node="${queue[0]}"
        queue=("${queue[@]:1}")

        TOPO_ORDER+=("$node")
        log_verbose "Topo: $node"

        # Process dependents
        local dependents="${REVERSE_GRAPH[$node]}"
        for dependent in $dependents; do
            ((in_degree["$dependent"]--))
            if [[ ${in_degree[$dependent]} -eq 0 ]]; then
                queue+=("$dependent")
            fi
        done
    done

    if [[ ${#TOPO_ORDER[@]} -ne ${#TASK_LIST[@]} ]]; then
        log_error "Topological sort failed (graph not fully sorted)"
        return 1
    fi

    log_success "Topological order computed (${#TOPO_ORDER[@]} tasks)"
    return 0
}

# ============================================================================
# PARALLEL GROUP IDENTIFICATION
# ============================================================================

identify_parallel_groups() {
    log_info "Identifying parallelizable tasks..."

    PARALLEL_GROUPS=()
    declare -A processed

    while [[ ${#processed[@]} -lt ${#TOPO_ORDER[@]} ]]; do
        local -a current_group=()

        for task_id in "${TOPO_ORDER[@]}"; do
            [[ -n "${processed[$task_id]}" ]] && continue

            # Check if all dependencies are processed
            local all_deps_done=true
            local deps="${GRAPH[$task_id]}"
            for dep in $deps; do
                if [[ -z "${processed[$dep]}" ]]; then
                    all_deps_done=false
                    break
                fi
            done

            if [[ "$all_deps_done" == true ]]; then
                current_group+=("$task_id")
                processed["$task_id"]=1
            fi
        done

        if [[ ${#current_group[@]} -gt 0 ]]; then
            local group_str="${current_group[*]}"
            PARALLEL_GROUPS+=("$group_str")
            log_verbose "Group: $group_str"
        fi
    done

    log_success "Identified ${#PARALLEL_GROUPS[@]} execution phase(s)"
    return 0
}

# ============================================================================
# EXECUTION PLAN GENERATION
# ============================================================================

generate_execution_plan() {
    log_info "Generating execution plan..."

    echo ""
    echo -e "${BOLD}${BLUE}Task Execution Plan${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Total Tasks: ${#TASK_LIST[@]}"
    echo "Execution Phases: ${#PARALLEL_GROUPS[@]}"
    echo ""

    local phase=1
    for group_str in "${PARALLEL_GROUPS[@]}"; do
        local -a group=($group_str)
        local group_size=${#group[@]}

        if [[ $group_size -eq 1 ]]; then
            echo -e "${BLUE}Phase $phase:${NC} [${group[0]}]"
        else
            echo -e "${BLUE}Phase $phase:${NC} [${group[*]}] ${YELLOW}(PARALLEL${NC})"
        fi

        for task_id in "${group[@]}"; do
            local deps="${GRAPH[$task_id]}"
            if [[ -z "$deps" ]]; then
                echo "  ├─ $task_id (depends: none)"
            else
                echo "  ├─ $task_id (depends: $deps)"
            fi
        done

        ((phase++))
    done

    echo ""
    echo "Execution Order:"
    local idx=1
    for task_id in "${TOPO_ORDER[@]}"; do
        echo "  $idx. $task_id"
        ((idx++))
    done

    echo ""
}

# ============================================================================
# VISUALIZATION
# ============================================================================

visualize_graph_ascii() {
    log_info "Graph Visualization (ASCII):"
    echo ""

    for task_id in "${TASK_LIST[@]}"; do
        local deps="${GRAPH[$task_id]}"
        if [[ -z "$deps" ]]; then
            echo "$task_id (root)"
        else
            echo "$task_id ← $deps"
        fi
    done

    echo ""
}

visualize_graph_dot() {
    log_info "Graph Visualization (Graphviz DOT format):"
    echo ""
    echo "digraph TaskDependencies {"
    echo "  rankdir=LR;"

    for task_id in "${TASK_LIST[@]}"; do
        echo "  \"$task_id\";"
    done

    echo ""
    for task_id in "${TASK_LIST[@]}"; do
        local deps="${GRAPH[$task_id]}"
        for dep in $deps; do
            echo "  \"$task_id\" -> \"$dep\";"
        done
    done

    echo "}"
    echo ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --file|-f)
                TASK_FILE="$2"
                shift 2
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --visualize)
                VISUALIZE=true
                shift
                ;;
            --dot)
                VISUALIZE_DOT=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << 'EOF'
Task Dependency Resolver

Usage: ./task-dependency-resolver.sh --file TASK_FILE [OPTIONS]

Options:
  --file, -f FILE     Task definition file (YAML)
  --verbose, -v       Enable verbose output
  --visualize         Show ASCII graph visualization
  --dot               Export Graphviz DOT format
  --help, -h          Show this help message

Examples:
  ./task-dependency-resolver.sh --file tasks.yml
  ./task-dependency-resolver.sh --file tasks.yml --verbose
  ./task-dependency-resolver.sh --file tasks.yml --visualize

Exit Codes:
  0                   Success
  1                   Validation or cycle detection error
EOF
}

main() {
    echo -e "${BOLD}SuperClaude Task Dependency Resolver v$RESOLVER_VERSION${NC}"
    echo ""

    parse_arguments "$@"

    if [[ -z "${TASK_FILE}" ]]; then
        log_error "No task file specified"
        show_help
        exit 1
    fi

    if [[ ! -f "$TASK_FILE" ]]; then
        log_error "Task file not found: $TASK_FILE"
        exit 1
    fi

    # Step 1: Parse tasks
    log_info "Loading task definitions from: $TASK_FILE"
    parse_yaml_task "$TASK_FILE" || return 1

    if [[ ${#TASK_LIST[@]} -eq 0 ]]; then
        log_error "No tasks found in file"
        return 1
    fi

    log_success "Loaded ${#TASK_LIST[@]} tasks"
    echo ""

    # Step 2: Validate references
    validate_task_references || return 1
    echo ""

    # Step 3: Detect cycles
    detect_cycles || return 1
    echo ""

    # Step 4: Topological sort
    topological_sort || return 1
    echo ""

    # Step 5: Identify parallel groups
    identify_parallel_groups || return 1
    echo ""

    # Step 6: Generate execution plan
    generate_execution_plan

    # Step 7: Visualization (optional)
    if [[ "${VISUALIZE}" == true ]]; then
        visualize_graph_ascii
    fi

    if [[ "${VISUALIZE_DOT}" == true ]]; then
        visualize_graph_dot
    fi

    log_success "Task dependency resolution complete!"
    return 0
}

main "$@"
exit $?
