# Reference Validation System Design Specification

**Task #1 Deliverable**  
**Version:** 1.0  
**Status:** In Progress  
**Date:** 2026-05-11

---

## I. Executive Summary

This design specifies a reference validation system for SuperClaude's @include configuration template system. The system detects and reports configuration errors early, preventing silent failures and improving framework reliability.

**Scope:** Validate @include references across all configuration files  
**Impact:** Critical reliability improvement for v2.1  
**Complexity:** Medium (algorithm design + integration)

---

## II. Problem Statement

### Current Situation
- SuperClaude uses @include references extensively (50+ references across 20+ files)
- 735+ lines of shared YAML configuration
- No automated validation of reference integrity
- Broken references cause silent failures or cryptic errors

### Risks
1. **Circular References** — A.yml includes B.yml includes A.yml → infinite loop
2. **Missing Files** — Reference to non-existent file → undefined behavior
3. **Invalid Sections** — Reference to section that doesn't exist → silent skip
4. **Syntax Errors** — Malformed YAML → parse failures
5. **Orphaned Sections** — Sections referenced by nothing → maintenance burden

### Impact
- Framework instability
- Hard-to-debug configuration issues
- Difficult contributor onboarding
- Production reliability concerns

---

## III. Solution Design

### A. Validation Architecture

```
Reference Validation System
│
├─ Phase 1: Parse & Discover
│  ├─ Scan all .md and .yml files
│  ├─ Extract @include statements using regex
│  └─ Build reference graph
│
├─ Phase 2: Validate Structure
│  ├─ Check file existence
│  ├─ Verify YAML syntax
│  ├─ Validate section headers
│  └─ Check file readability
│
├─ Phase 3: Analyze Relationships
│  ├─ Build dependency graph
│  ├─ Detect circular dependencies (DFS)
│  ├─ Find orphaned sections
│  └─ Identify unreachable references
│
├─ Phase 4: Report Results
│  ├─ Structured error output
│  ├─ Severity classification
│  ├─ Remediation suggestions
│  └─ Summary statistics
│
└─ Phase 5: Integration
   ├─ install.sh integration
   ├─ CI/CD pipeline integration
   └─ Developer feedback
```

---

### B. Reference Format & Parsing

#### Current Reference Format
```
@include shared/filename.yml#SectionName
@include commands/shared/patterns.yml#Pattern_Name
@include shared/superclaude-core.yml#Core_Philosophy
```

#### Regex Pattern for Extraction
```bash
# Matches: @include path/to/file.yml#SectionName
PATTERN='@include\s+([^#\s]+)#([^\s]+)'

# Groups:
# [1] = file path (e.g., "shared/filename.yml")
# [2] = section name (e.g., "SectionName")
```

#### Validation Rules

| Component | Rule | Example |
|-----------|------|---------|
| **File Path** | Relative to project root | `shared/file.yml` ✓, `/abs/path` ✗ |
| **Extension** | Must be .yml or .md | `file.yml` ✓, `file.txt` ✗ |
| **Section** | Must be YAML key or markdown header | `Core_Philosophy` ✓, `Non-existent` ✗ |
| **Naming** | Use snake_case for sections | `My_Section` ✓, `my-section` ✗ |

---

### C. Circular Dependency Detection

#### Algorithm: Depth-First Search (DFS)

```python
function detectCycles(graph):
    visited = {}
    recursionStack = {}
    cycles = []
    
    for each node in graph:
        if not visited[node]:
            cycles += dfs(node, visited, recursionStack, graph)
    
    return cycles

function dfs(node, visited, recursionStack, graph):
    visited[node] = true
    recursionStack[node] = true
    cycles = []
    
    for each neighbor in graph[node]:
        if not visited[neighbor]:
            cycles += dfs(neighbor, visited, recursionStack, graph)
        elif recursionStack[neighbor]:
            # Found cycle!
            cycles.append(node → neighbor)
    
    recursionStack[node] = false
    return cycles
```

#### Example: Detecting Circular References

```yaml
# File A: CLAUDE.md
@include shared/superclaude-core.yml#Core_Philosophy

# File B: shared/superclaude-core.yml
# [At end of file]
@include CLAUDE.md#Section  ← CIRCULAR REFERENCE!

# Detection Output:
Circular reference detected:
  CLAUDE.md → shared/superclaude-core.yml → CLAUDE.md
  
Path: CLAUDE.md[line 10] → shared/superclaude-core.yml[line 50] → CLAUDE.md[line 1]
```

---

### D. Section Validation

#### YAML Section Detection

```yaml
# YAML sections are top-level keys
Core_Philosophy:
  key1: value1
  key2: value2

Another_Section:
  nested:
    item: value
```

**Validation:** Check that section name exists as top-level key

#### Markdown Section Detection

```markdown
# Universe
## Core_Philosophy
### Subsection

## Another_Section
```

**Validation:** Check that section exists as heading at any level

---

### E. Error Classification & Severity

| Severity | Type | Recovery | Example |
|----------|------|----------|---------|
| **CRITICAL** | Circular reference | Manual fix required | A→B→A |
| **CRITICAL** | Missing file | Manual fix required | file.yml not found |
| **ERROR** | Invalid section | Manual fix required | Section not in file |
| **ERROR** | Invalid YAML syntax | Manual fix required | Bad indentation |
| **WARNING** | Orphaned section | Optional cleanup | Section never referenced |
| **INFO** | Reference stats | FYI | "47 references found" |

---

### F. Error Message Format

```
┌─────────────────────────────────────────────────────────┐
│              REFERENCE VALIDATION REPORT                 │
├─────────────────────────────────────────────────────────┤

🔴 CRITICAL (2 errors):

1. Circular Reference
   Location: CLAUDE.md:10
   Reference: @include shared/superclaude-core.yml#Philosophy
   Cycle: CLAUDE.md → superclaude-core.yml → CLAUDE.md
   
   Fix: Remove the @include statement from superclaude-core.yml
        that references CLAUDE.md

2. Missing File
   Location: commands/analyze.md:5
   Reference: @include shared/missing-file.yml#Section
   File: shared/missing-file.yml (NOT FOUND)
   
   Fix: Create the file or correct the reference path

⚠️  WARNING (1 item):

3. Orphaned Section
   File: shared/superclaude-core.yml
   Section: Unused_Philosophy
   Never referenced by any file
   
   Fix: Remove if no longer needed, or add reference

✅ SUMMARY:
   Total references: 47
   Valid: 44
   Errors: 2 (must fix)
   Warnings: 1 (recommend fix)
   
   Validation time: 0.087 seconds
└─────────────────────────────────────────────────────────┘
```

---

### G. Validation Rules Engine

#### Rule Set

```yaml
RuleSet:
  File_Rules:
    - Must exist and be readable
    - Must be .yml or .md extension
    - Must be relative path (not absolute)
    - Must not be outside project root
    
  Section_Rules:
    - Must exist in referenced file
    - Must be valid YAML key or Markdown heading
    - Must follow naming convention (snake_case)
    
  Reference_Rules:
    - No circular dependencies allowed
    - No self-references allowed (file includes itself)
    - Limit recursion depth to prevent DOS
    
  Syntax_Rules:
    - YAML files must have valid syntax
    - Markdown files must have valid headers
    - @include statements must match regex format
```

---

## IV. Implementation Plan

### Phase 1: Core Validator Module

**File:** `validate-references.sh`

**Functions:**
1. `parse_references(file)` — Extract all @include statements
2. `build_graph(files)` — Build dependency graph
3. `validate_file(file)` — Check file existence & syntax
4. `validate_section(file, section)` — Verify section exists
5. `detect_cycles(graph)` — Find circular dependencies
6. `find_orphans(graph)` — Identify unreferenced sections
7. `generate_report(results)` — Format output

**Dependencies:**
- bash 3.0+ (available on all systems)
- grep, find (standard Unix tools)
- No external dependencies

---

### Phase 2: install.sh Integration

**Integration Points:**

```bash
# In install.sh, add validation step:

function validate_configuration() {
    echo "Validating references..."
    
    # Run validation
    ./validate-references.sh --report
    
    # Check result
    if [ $? -ne 0 ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "Validation would fail. Fix issues and retry."
            return 1
        else
            echo "Reference validation failed. Cannot proceed."
            return 1
        fi
    fi
    
    echo "✓ All references valid"
}

# Call during installation:
validate_configuration || exit 1
```

**Flags:**
- `--validate-only` — Run validation without installation
- `--skip-validation` — Skip validation (not recommended)
- `--report` — Generate detailed report
- `--fix-auto` — Auto-fix fixable issues (future)

---

### Phase 3: CI/CD Integration

**GitHub Actions Workflow:**

```yaml
name: Reference Validation

on: [pull_request, push]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Validate References
        run: |
          ./validate-references.sh --report
        
      - name: Upload Report
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: validation-report
          path: validation-report.txt
      
      - name: Comment on PR
        if: failure()
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '❌ Reference validation failed. See artifact for details.'
            })
```

---

## V. Data Structures

### Reference Graph Structure

```bash
# Adjacency list representation
declare -A GRAPH

# Example:
GRAPH[CLAUDE.md]="shared/core.yml commands/analyze.md"
GRAPH[shared/core.yml]="shared/rules.yml"
GRAPH[commands/analyze.md]=""  # No outgoing refs

# To check dependencies of CLAUDE.md:
echo ${GRAPH[CLAUDE.md]}
# Output: shared/core.yml commands/analyze.md
```

### Validation Result Structure

```bash
# Arrays to collect results
declare -a VALID_REFS=()
declare -a ERROR_REFS=()
declare -a WARNING_REFS=()

# Error details
declare -A ERROR_TYPE  # Maps ref to error type
declare -A ERROR_MSG   # Maps ref to error message
declare -A ERROR_LINE  # Maps ref to line number

# Statistics
TOTAL_REFS=0
VALID_COUNT=0
ERROR_COUNT=0
WARNING_COUNT=0
```

---

## VI. Performance Requirements

| Operation | Target | Justification |
|-----------|--------|---------------|
| **Full validation** | <100ms | Must be fast for CI/CD |
| **Single file** | <10ms | Developer iteration speed |
| **Cycle detection** | <50ms | DFS is O(V+E), fast |
| **Report generation** | <10ms | Minimal formatting |

**Current Config Load:**
- 47 config files
- 50+ references
- 735+ lines of YAML
- Expected: ~50-80ms for full validation

---

## VII. Testing Strategy

### Unit Tests

```bash
# Test 1: Parse references correctly
test_parse_references() {
    # Input: File with @include statements
    # Expected: Correctly extract all references
}

# Test 2: Detect circular references
test_circular_detection() {
    # Setup: Create circular A→B→A
    # Expected: Detect cycle
}

# Test 3: Find missing files
test_missing_file_detection() {
    # Input: Reference to non-existent file
    # Expected: Error reported
}

# Test 4: Validate sections
test_section_validation() {
    # Input: Reference to YAML section
    # Expected: Verify section exists
}

# Test 5: Orphaned sections
test_orphan_detection() {
    # Input: Unused YAML section
    # Expected: Warning generated
}
```

### Integration Tests

```bash
# Test 1: Full installation validation
test_install_validation() {
    # Run: ./install.sh --dry-run
    # Expected: Validation runs, reports passed
}

# Test 2: CI/CD integration
test_cicd_integration() {
    # Run: GitHub Actions workflow
    # Expected: PR blocked on validation failure
}

# Test 3: Error recovery
test_error_recovery() {
    # Introduce error, fix, revalidate
    # Expected: System recovers correctly
}
```

---

## VIII. Success Criteria

### Acceptance Criteria (v2.1 Release Gate)

- ✅ **Accuracy**: Detects 100% of circular references
- ✅ **Performance**: Validates full config in <100ms
- ✅ **Coverage**: All 47 current references validate
- ✅ **Usability**: Error messages actionable (include remediation)
- ✅ **Integration**: Works in install.sh and CI/CD
- ✅ **Testing**: >90% code coverage, all tests pass
- ✅ **Documentation**: Clear design + user guide

### Quality Gates

| Metric | Target | Verification |
|--------|--------|--------------|
| **Accuracy** | 100% | Test suite |
| **Performance** | <100ms | Benchmark test |
| **False Positives** | 0 | Real config testing |
| **Test Coverage** | >90% | Coverage report |
| **Documentation** | Complete | Doc review |

---

## IX. Error Handling & Edge Cases

### Edge Cases

| Case | Handling | Example |
|------|----------|---------|
| **Self-reference** | Error (circular) | A includes A |
| **Indirect cycle** | Error (circular) | A→B→C→A |
| **Deep nesting** | Allowed (depth limit TBD) | A→B→C→D→E... |
| **Duplicate refs** | Allowed (redundant but safe) | A includes B twice |
| **Case sensitivity** | Strict (section names case-sensitive) | `Core` ≠ `core` |
| **Whitespace** | Flexible (trimmed in parsing) | `@include  file.yml  #Section` |

### Recovery Strategies

1. **Syntax Error** → Report line number, expected format
2. **Missing File** → Suggest correct paths
3. **Missing Section** → List available sections
4. **Circular Ref** → Show cycle path, recommend removal
5. **Orphaned Section** → Mark for cleanup, don't block

---

## X. Future Enhancements (Post v2.1)

### Enhancement 1: Auto-fix
```bash
./validate-references.sh --fix-auto
# Automatically fixes common issues:
# - Reorders includes to break cycles
# - Adds missing sections with stubs
```

### Enhancement 2: Visualization
```bash
./validate-references.sh --visualize
# Generates ASCII graph of references
```

### Enhancement 3: Impact Analysis
```bash
./validate-references.sh --impact shared/core.yml
# Shows: "Changing this affects 12 files"
```

---

## XI. Documentation Requirements

**User Documentation:**
- How to run validation
- Understanding error messages
- Fixing common issues

**Developer Documentation:**
- Architecture overview
- Adding new validation rules
- Contributing tests

**Admin Documentation:**
- CI/CD setup
- Maintenance procedures
- Performance tuning

---

## XII. Sign-off Checklist

- [ ] Design approved by architecture team
- [ ] Algorithm validation (DFS correctness)
- [ ] Performance analysis (benchmarked)
- [ ] Error message taxonomy finalized
- [ ] Integration points identified
- [ ] Test strategy approved
- [ ] Ready for implementation phase (Task #2)

---

## Appendix A: Reference Count Analysis

```
File Type Distribution:
├─ CLAUDE.md (main config): 50+ references
├─ Command files (.md): 5-8 refs each × 19 = 95-152 refs
├─ Shared config (.yml): 2-3 refs each × 4 = 8-12 refs
└─ Total: ~150-200+ references

Reference Types:
├─ Core patterns: shared/superclaude-*.yml
├─ Command patterns: commands/shared/*.yml
└─ Universal patterns: shared/universal-*.yml

Complexity Assessment:
├─ Circular refs possible: YES (moderate risk)
├─ Orphaned sections likely: MEDIUM
├─ Performance concern: NONE (all local files)
└─ Maintainability: CRITICAL (many references)
```

---

**Design Specification Complete** ✅

**Next: Implementation (Task #2)**  
Estimated completion: 5-7 days  
Review & approval ready for architecture team
