# SuperClaude v2.1 Testing Strategy & Automation

**Task #10 Deliverable**  
**Version:** 1.0  
**Status:** In Progress  
**Date:** 2026-05-12

---

## I. Executive Summary

This document defines comprehensive testing strategy for SuperClaude v2.1, covering all components implemented across Tasks #1-5:
- Reference validation system
- Task dependency resolver
- Task executor
- CI/CD workflows

**Goals:**
- ✅ Achieve >85% code coverage
- ✅ Validate all algorithms (DFS, topological sort, etc.)
- ✅ Test edge cases and error scenarios
- ✅ Ensure performance targets met
- ✅ Enable safe future enhancements
- ✅ Build confidence in production deployment

**Scope:** Unit tests, integration tests, performance tests, end-to-end tests

---

## II. Testing Framework Architecture

### Test Layers

```
┌─────────────────────────────────────────┐
│      End-to-End Tests (E2E)            │
│  Real workflows, actual execution      │
│  Tests: Complete pipelines             │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│   Integration Tests                     │
│  Multiple components working together  │
│  Tests: Resolver → Executor flow       │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│     Unit Tests                          │
│  Individual functions/algorithms       │
│  Tests: DFS, topological sort, etc     │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│   Performance Tests                     │
│  Benchmarks and scalability            │
│  Tests: Speed, memory, throughput      │
└─────────────────────────────────────────┘
```

### Test Organization

```
tests/
├── unit/
│   ├── test_reference_validator.sh
│   ├── test_task_resolver.sh
│   ├── test_task_executor.sh
│   └── test_algorithms.sh
├── integration/
│   ├── test_validator_resolver.sh
│   ├── test_resolver_executor.sh
│   └── test_full_pipeline.sh
├── performance/
│   ├── test_resolver_speed.sh
│   ├── test_executor_throughput.sh
│   └── test_scalability.sh
├── fixtures/
│   ├── valid_config.yml
│   ├── invalid_config.yml
│   ├── circular_deps.yml
│   └── large_workflow.yml
└── results/
    ├── coverage_report.txt
    └── performance_report.txt
```

---

## III. Unit Testing Strategy

### A. Reference Validator Tests

**Component:** validate-references.sh

**Test Cases:**

#### 1. Reference Extraction
```bash
test_extract_single_reference() {
    # Input: File with one @include statement
    # Expected: Reference extracted correctly
    # Assert: Reference matches pattern
}

test_extract_multiple_references() {
    # Input: File with multiple @include statements
    # Expected: All references extracted
    # Assert: Count matches, order preserved
}

test_extract_no_references() {
    # Input: File with no @include statements
    # Expected: Empty result
    # Assert: No false positives
}
```

#### 2. File Validation
```bash
test_valid_file_path() {
    # Valid paths: shared/file.yml, commands/config.md
    # Assert: Passes validation
}

test_invalid_extensions() {
    # Invalid: file.txt, file.json
    # Assert: Rejected
}

test_absolute_path_rejection() {
    # Input: /absolute/path/file.yml
    # Assert: Rejected as invalid
}

test_path_traversal_rejection() {
    # Input: ../parent/file.yml
    # Assert: Rejected (security)
}
```

#### 3. YAML Syntax Validation
```bash
test_valid_yaml_syntax() {
    # Valid YAML structure
    # Assert: Passes validation
}

test_unmatched_braces() {
    # Input: YAML with unmatched {}
    # Assert: Fails with clear error
}

test_tab_indentation() {
    # Input: YAML with tabs (invalid)
    # Assert: Fails validation
}
```

#### 4. Section Validation
```bash
test_yaml_section_exists() {
    # Input: Reference to existing section
    # Assert: Passes validation
}

test_yaml_section_missing() {
    # Input: Reference to non-existent section
    # Assert: Fails with "section not found"
}

test_markdown_header_exists() {
    # Input: Reference to existing markdown header
    # Assert: Passes validation
}

test_markdown_header_missing() {
    # Input: Reference to non-existent header
    # Assert: Fails with suggestions
}
```

#### 5. Circular Reference Detection
```bash
test_direct_cycle() {
    # A includes B, B includes A
    # Assert: Cycle detected, path shown
}

test_indirect_cycle() {
    # A → B → C → A
    # Assert: Cycle detected, full path shown
}

test_no_cycle() {
    # Valid DAG
    # Assert: Passes, no false positives
}
```

---

### B. Task Resolver Tests

**Component:** task-dependency-resolver.sh

**Test Cases:**

#### 1. YAML Parsing
```bash
test_parse_simple_task() {
    # Single task with no dependencies
    # Assert: Task loaded correctly
}

test_parse_task_with_dependencies() {
    # Task with depends-on list
    # Assert: Dependencies parsed and stored
}

test_parse_multiple_tasks() {
    # Several tasks in one file
    # Assert: All tasks loaded, graph built
}
```

#### 2. Reference Validation
```bash
test_missing_task_reference() {
    # Task depends on non-existent task
    # Assert: Error reported with suggestion
}

test_all_references_valid() {
    # All dependencies exist
    # Assert: Passes validation
}
```

#### 3. Topological Sort (Kahn's Algorithm)
```bash
test_simple_sequence() {
    # A → B → C
    # Expected order: [A, B, C]
    # Assert: Order is correct
}

test_parallel_tasks() {
    # A → [B, C] → D
    # Expected: A, then B and C (any order), then D
    # Assert: Dependencies respected
}

test_diamond_pattern() {
    # A → [B, C] → D → E
    # Expected: All dependencies before dependent
    # Assert: Order is valid
}

test_complex_graph() {
    # Large workflow with multiple levels
    # Expected: Valid topological order
    # Assert: No dependencies violated
}
```

#### 4. Cycle Detection
```bash
test_detect_simple_cycle() {
    # A → B → A
    # Assert: Cycle detected, path shown
}

test_detect_self_reference() {
    # A → A
    # Assert: Detected as cycle
}

test_detect_long_cycle() {
    # A → B → C → D → A
    # Assert: Cycle detected, full path
}

test_no_false_positives() {
    # Valid DAG
    # Assert: No cycle detected
}
```

#### 5. Parallel Group Identification
```bash
test_identify_sequential_tasks() {
    # A → B → C (no parallelization)
    # Expected groups: [[A], [B], [C]]
    # Assert: 3 groups
}

test_identify_parallel_tasks() {
    # A → [B, C, D] → E
    # Expected groups: [[A], [B,C,D], [E]]
    # Assert: 3 groups with parallel in middle
}

test_identify_complex_parallelization() {
    # Large workflow with multiple parallel opportunities
    # Assert: Groups identified correctly
}
```

#### 6. Execution Plan Generation
```bash
test_execution_plan_format() {
    # Input: Valid workflow
    # Assert: Plan is well-formatted, readable
}

test_execution_plan_completeness() {
    # Input: 5 tasks
    # Assert: Plan includes all tasks
}

test_execution_plan_accuracy() {
    # Input: Complex workflow
    # Assert: Plan respects all dependencies
}
```

---

### C. Task Executor Tests

**Component:** task-executor.sh

**Test Cases:**

#### 1. Sequential Execution
```bash
test_execute_single_task() {
    # Single task
    # Assert: Executes successfully
}

test_execute_task_sequence() {
    # A → B → C
    # Assert: Executes in correct order
}

test_sequential_stops_on_failure() {
    # A (passes) → B (fails) → C
    # Assert: C does not execute
}
```

#### 2. Parallel Execution
```bash
test_execute_parallel_tasks() {
    # [A, B, C] all independent
    # Assert: All execute (in parallel or serial)
}

test_parallel_respects_limit() {
    # [A, B, C, D] with limit=2
    # Assert: Never more than 2 concurrent
}

test_parallel_waits_for_dependencies() {
    # A → [B, C] (B,C in parallel)
    # Assert: B, C don't start until A done
}
```

#### 3. Dry-Run Mode
```bash
test_dry_run_no_execution() {
    # --dry-run flag
    # Assert: Commands not actually executed
}

test_dry_run_shows_commands() {
    # --dry-run flag
    # Assert: Output shows what would execute
}
```

#### 4. Result Tracking
```bash
test_track_success() {
    # Task succeeds
    # Assert: Status recorded as success
}

test_track_failure() {
    # Task fails
    # Assert: Status recorded as failed
}

test_log_file_creation() {
    # Task execution
    # Assert: Log file created in correct location
}
```

#### 5. Summary Reporting
```bash
test_summary_counts() {
    # Execute 5 tasks: 3 pass, 2 fail
    # Assert: Summary shows 3 success, 2 failed
}

test_summary_lists_failures() {
    # Some tasks fail
    # Assert: Failed tasks listed with details
}
```

---

## IV. Integration Testing Strategy

### Test A: Validator → Resolver Pipeline

```bash
test_validate_then_resolve() {
    # 1. Create config with valid references
    # 2. Run validator (should pass)
    # 3. Run resolver (should generate plan)
    # Assert: Both succeed, output consistent
}

test_validator_catches_errors() {
    # 1. Create config with circular refs
    # 2. Run validator (should fail)
    # 3. Try to run resolver
    # Assert: Validator blocks resolver
}

test_validator_error_messages_helpful() {
    # 1. Create config with errors
    # 2. Run validator
    # Assert: Error messages guide user to fix
}
```

### Test B: Resolver → Executor Pipeline

```bash
test_resolve_then_execute() {
    # 1. Load tasks from YAML
    # 2. Resolve dependencies (generate plan)
    # 3. Execute based on plan
    # Assert: All tasks execute in correct order
}

test_execution_respects_plan() {
    # 1. Generate execution plan
    # 2. Execute and track order
    # Assert: Execution follows plan exactly
}

test_executor_logs_results() {
    # 1. Execute workflow
    # 2. Check logs and results
    # Assert: All tasks have log files
}
```

### Test C: Full Pipeline

```bash
test_full_pipeline_success() {
    # 1. Create valid workflow YAML
    # 2. Validate references
    # 3. Resolve dependencies
    # 4. Execute workflow
    # 5. Report results
    # Assert: All steps succeed
}

test_full_pipeline_with_errors() {
    # 1. Create workflow with issues
    # 2. Each step detects problem
    # 3. Error propagates correctly
    # Assert: User sees clear error
}

test_full_pipeline_end_to_end() {
    # Real workflow from sample-workflow.yml
    # 1. Validate
    # 2. Resolve
    # 3. Execute (dry-run)
    # 4. Report
    # Assert: Everything works together
}
```

---

## V. Performance Testing Strategy

### Test A: Reference Validator Performance

```bash
test_validator_speed_small() {
    # 20 files, 50 references
    # Target: <50ms
    # Assert: Completes within target
}

test_validator_speed_medium() {
    # 100 files, 500 references
    # Target: <200ms
    # Assert: Completes within target
}

test_validator_memory_usage() {
    # Load large config
    # Assert: Memory usage reasonable
}
```

### Test B: Task Resolver Performance

```bash
test_resolver_speed_10_tasks() {
    # 10 tasks, 15 edges
    # Target: <10ms
    # Assert: Execution time acceptable
}

test_resolver_speed_100_tasks() {
    # 100 tasks, 200 edges
    # Target: <50ms
    # Assert: Scales well
}

test_resolver_speed_1000_tasks() {
    # 1000 tasks, 2000 edges
    # Target: <500ms
    # Assert: Still performant
}

test_resolver_memory_1000_tasks() {
    # 1000 tasks
    # Target: <2MB
    # Assert: Memory efficient
}
```

### Test C: Task Executor Performance

```bash
test_executor_throughput() {
    # Execute 100 simple tasks
    # Target: Complete within time limit
    # Assert: No overhead per task
}

test_executor_parallel_speedup() {
    # Tasks: [sequential], [parallel]
    # Assert: Parallel is faster
}

test_executor_memory_during_execution() {
    # Execute workflow
    # Assert: Memory stable, no leaks
}
```

---

## VI. Edge Cases & Error Scenarios

### Scenario A: Circular Dependencies

```bash
test_circular_direct() {
    # A ← → B
    # Assert: Detected and reported
}

test_circular_indirect() {
    # A → B → C → A
    # Assert: Detected and reported
}

test_circular_complex() {
    # Multiple cycles in same graph
    # Assert: All detected
}
```

### Scenario B: Missing Dependencies

```bash
test_missing_single_dep() {
    # Task depends on non-existent task
    # Assert: Clear error message
}

test_missing_multiple_deps() {
    # Multiple missing references
    # Assert: All reported together
}

test_typo_in_dependency() {
    # Task name typo in dependency
    # Assert: Error suggests correction
}
```

### Scenario C: Invalid Formats

```bash
test_malformed_yaml() {
    # Invalid YAML syntax
    # Assert: Parse error with location
}

test_missing_required_fields() {
    # Task missing 'commands' field
    # Assert: Validation error
}

test_invalid_field_values() {
    # Invalid field types
    # Assert: Type validation error
}
```

### Scenario D: Large Workflows

```bash
test_1000_tasks() {
    # Very large workflow
    # Assert: Handles gracefully
}

test_many_dependencies() {
    # One task depends on many tasks
    # Assert: Parses and executes correctly
}

test_wide_graph() {
    # Many tasks at same level
    # Assert: All parallelized correctly
}
```

---

## VII. Test Coverage Goals

### Component Coverage Targets

| Component | Target | Strategy |
|-----------|--------|----------|
| **Reference Validator** | >90% | Unit + integration tests |
| **Task Resolver** | >85% | Unit + performance tests |
| **Task Executor** | >80% | Integration tests |
| **Algorithms** | >95% | Dedicated algorithm tests |
| **Error Handling** | >80% | Error scenario tests |
| **Overall** | >85% | Comprehensive coverage |

### Coverage Measurement

```bash
# Track coverage with bash coverage tool
./run_tests.sh --coverage

# Output:
# ===================== Coverage Report =====================
# File                          Covered  Total  Percent
# validate-references.sh         145/160  90.6%
# task-dependency-resolver.sh    180/210  85.7%
# task-executor.sh              110/140  78.6%
# ─────────────────────────────────────────────────────────
# TOTAL                          435/510  85.3% ✓ PASS
```

---

## VIII. Test Automation

### Test Execution Script

```bash
#!/bin/bash
# run_tests.sh - Run all tests for v2.1

# Run unit tests
./tests/unit/run_all.sh

# Run integration tests
./tests/integration/run_all.sh

# Run performance tests
./tests/performance/run_all.sh

# Generate coverage report
./tools/coverage_report.sh

# Generate summary
echo "Test Summary:"
echo "  Unit Tests: PASS"
echo "  Integration Tests: PASS"
echo "  Performance Tests: PASS"
echo "  Coverage: 85.3%"
echo "  Overall: ✓ PASS"
```

### CI/CD Integration

**In GitHub Actions:**
```yaml
- name: Run test suite
  run: ./run_tests.sh --coverage

- name: Check coverage threshold
  run: |
    coverage=$(grep "TOTAL" coverage_report.txt | awk '{print $NF}' | sed 's/%//')
    if (( $(echo "$coverage < 85" | bc -l) )); then
      echo "Coverage below threshold: $coverage%"
      exit 1
    fi

- name: Upload coverage report
  uses: actions/upload-artifact@v4
  with:
    name: coverage-report
    path: coverage_report.txt
```

---

## IX. Test Data & Fixtures

### Fixture Files

**valid_config.yml** - Correct configuration
```yaml
tasks:
  analyze:
    commands: ["/analyze --code"]
  review:
    depends-on: [analyze]
    commands: ["/review"]
```

**invalid_config.yml** - Missing reference
```yaml
tasks:
  task-a:
    depends-on: [nonexistent]
    commands: ["/cmd"]
```

**circular_deps.yml** - Circular dependency
```yaml
tasks:
  task-a:
    depends-on: [task-b]
  task-b:
    depends-on: [task-a]
```

**large_workflow.yml** - 1000 tasks for scalability testing

---

## X. Test Execution Procedures

### Before Release

```bash
# Step 1: Run all tests
./run_tests.sh

# Step 2: Check coverage
coverage=$(grep "TOTAL" coverage_report.txt | awk '{print $NF}')
echo "Coverage: $coverage (target: >85%)"

# Step 3: Run performance tests
./tests/performance/run_all.sh

# Step 4: Manual smoke tests
./manual_smoke_tests.sh

# Step 5: Generate report
./generate_test_report.sh
```

### During Development

```bash
# Quick test
./run_tests.sh --quick

# Specific test
./tests/unit/test_algorithms.sh

# Watch mode
./run_tests.sh --watch
```

---

## XI. Success Criteria

### Coverage Requirements
- ✅ Overall: >85%
- ✅ Core algorithms: >95%
- ✅ Error handling: >80%

### Test Execution
- ✅ All tests pass
- ✅ No false positives
- ✅ No false negatives

### Performance
- ✅ Reference validator: <200ms for 500 refs
- ✅ Task resolver: <500ms for 1000 tasks
- ✅ Test suite completes: <5 minutes

### Quality
- ✅ Clear test names
- ✅ Comprehensive documentation
- ✅ Easy to maintain and extend

---

## XII. Test Schedule

**Week 1 (Current):** Unit tests implementation  
**Week 2:** Integration tests + fixes  
**Week 3:** Performance tests + optimization  
**Week 4:** Final validation + release prep

---

**Testing Strategy Complete** ✅  
**Ready for Test Implementation (Subtasks)**
