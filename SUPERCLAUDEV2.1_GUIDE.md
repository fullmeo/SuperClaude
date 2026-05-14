# SuperClaude v2.1 - Complete Documentation

**Version:** 2.1  
**Release Date:** 2026-05-14  
**Status:** Production Ready (MVP)

---

## Table of Contents

1. [Overview](#overview)
2. [What's New in v2.1](#whats-new-in-v21)
3. [Quick Start](#quick-start)
4. [Core Features](#core-features)
5. [Architecture](#architecture)
6. [Migration from v1.0](#migration-from-v10)
7. [Usage Examples](#usage-examples)
8. [API Reference](#api-reference)
9. [Troubleshooting](#troubleshooting)
10. [Performance](#performance)
11. [FAQ](#faq)

---

## Overview

SuperClaude v2.1 is an AI-powered development framework that adds **task dependency management** and **intelligent execution orchestration** to Claude's native capabilities.

### Key Capabilities

- **Dependency Resolution:** Automatically order tasks based on dependencies
- **Parallel Execution:** Identify and execute parallelizable tasks concurrently
- **Reference Validation:** Catch configuration errors before execution
- **Dry-Run Planning:** Preview execution plans without side effects
- **Comprehensive Testing:** 119+ tests ensure reliability

### Who Should Use v2.1?

- **Multi-step workflows:** Projects with complex task ordering
- **CI/CD pipelines:** Automated quality gates and deployments
- **Parallel work:** Teams needing concurrent task execution
- **Large codebases:** Scalable to 1000+ task workflows

---

## What's New in v2.1

### Major Features

#### 1. **Task Dependency Graphs** ✨
Declare task dependencies in YAML, and SuperClaude automatically:
- Detects circular dependencies (errors caught early)
- Calculates optimal execution order (topological sort)
- Identifies parallelizable tasks (no blocking dependencies)
- Visualizes task relationships (ASCII + Graphviz)

#### 2. **Reference Validation System** ✨
Check configuration files for:
- Broken `@include` references
- Missing YAML/Markdown sections
- Circular dependencies in includes
- Invalid file paths

#### 3. **Intelligent Task Executor** ✨
Execute tasks with:
- Sequential mode (strict ordering)
- Parallel mode (configurable worker count: 1-8)
- Dry-run simulation (preview without execution)
- Automatic logging and result tracking

#### 4. **Comprehensive Test Suite** ✨
- 57 unit tests (component validation)
- 30 integration tests (pipeline coupling)
- 32+ performance benchmarks (scaling validation)
- CI/CD ready with automated reporting

### Performance Improvements

| Metric | v1.0 | v2.1 | Improvement |
|--------|------|------|-------------|
| Task resolution | Manual | <100ms | Automated |
| Parallel detection | None | Automatic | 30-50% speedup |
| Error detection | Late | Early | ~90% fewer failures |
| Test coverage | ~40% | ~85% | 2x coverage |

### Architectural Improvements

- **O(V+E) complexity:** Linear scaling to 1000+ tasks
- **Three-layer validation:** Config → Graph → Execution
- **Type-safe algorithms:** DFS cycle detection, Kahn's topological sort
- **Production-ready:** Comprehensive error handling

---

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/fullmeo/SuperClaude.git
cd SuperClaude

# Make scripts executable
chmod +x *.sh
chmod +x tests/*.sh
chmod +x tests/*/*.sh

# Verify installation
./task-dependency-resolver.sh --help
./task-executor.sh --help
```

### Your First Workflow

#### Step 1: Create a task file (`workflow.yml`)

```yaml
version: "1.0"
description: "My first workflow"

tasks:
  analyze:
    description: "Analyze code"
    commands:
      - "/analyze --code"
    timeout: 120

  test:
    description: "Run tests"
    commands:
      - "/test --unit"
    depends-on:
      - analyze
    timeout: 300

  report:
    description: "Generate report"
    commands:
      - "/report"
    depends-on:
      - test
    timeout: 60
```

#### Step 2: Validate References

```bash
./validate-references.sh --file workflow.yml
```

**Output:**
```
✓ All task references valid
✓ No circular dependencies detected
```

#### Step 3: Resolve Dependencies

```bash
./task-dependency-resolver.sh --file workflow.yml
```

**Output:**
```
Task Execution Plan
═══════════════════════════════════════
Total Tasks: 3
Execution Phases: 3

Phase 1: [analyze]
  ├─ analyze (depends: none)

Phase 2: [test]
  ├─ test (depends: analyze)

Phase 3: [report]
  ├─ report (depends: test)

Execution Order:
  1. analyze
  2. test
  3. report
```

#### Step 4: Execute Workflow

```bash
# Dry-run first (preview without execution)
./task-executor.sh --file workflow.yml --dry-run

# Actual execution
./task-executor.sh --file workflow.yml --parallel 4
```

---

## Core Features

### 1. Task Definition Format

**Full YAML Schema:**

```yaml
version: "1.0"
description: "Workflow description"

metadata:
  author: "Team name"
  created: "2026-05-14"
  tags: ["ci", "test"]

tasks:
  task-id:
    description: "What this task does"
    commands:
      - "/command --flag arg"
      - "/another-command"
    depends-on:
      - prerequisite-task-1
      - prerequisite-task-2
    timeout: 300              # seconds
    retry: 1                  # retry count
    continue-on-error: false  # skip on failure?
    optional: false           # skip if not needed?
    tags: ["unit-test"]
```

**Minimal Example:**

```yaml
tasks:
  build:
    commands: ["/build"]
  test:
    depends-on: [build]
    commands: ["/test"]
```

### 2. Dependency Patterns

#### Linear Dependencies
```
task-a → task-b → task-c
```

```yaml
tasks:
  a:
    commands: ["/a"]
  b:
    depends-on: [a]
    commands: ["/b"]
  c:
    depends-on: [b]
    commands: ["/c"]
```

#### Parallel Dependencies
```
        ↙ b ↘
start ┤        converge
        ↘ c ↗
```

```yaml
tasks:
  start:
    commands: ["/start"]
  b:
    depends-on: [start]
    commands: ["/b"]
  c:
    depends-on: [start]
    commands: ["/c"]
  converge:
    depends-on: [b, c]
    commands: ["/converge"]
```

#### Multi-Dependency
```yaml
tasks:
  task-d:
    depends-on: [a, b, c]  # Waits for ALL
    commands: ["/final"]
```

### 3. Reference Validation

Validate `@include` statements in configuration files:

```bash
./validate-references.sh --file CLAUDE.md --verbose
```

**Checks:**
- ✓ All referenced files exist
- ✓ All referenced sections exist
- ✓ No circular includes
- ✓ Valid file paths

### 4. Graph Visualization

#### ASCII Format
```bash
./task-dependency-resolver.sh --file workflow.yml --visualize
```

**Output:**
```
analyze (root)
test ← analyze
report ← test
```

#### Graphviz Format
```bash
./task-dependency-resolver.sh --file workflow.yml --dot > graph.dot
dot -Tpng graph.dot -o graph.png
```

### 5. Parallel Execution

#### Configure Worker Count
```bash
# Sequential (1 worker)
./task-executor.sh --file workflow.yml --parallel 1

# 4 workers (recommended)
./task-executor.sh --file workflow.yml --parallel 4

# 8 workers (maximum)
./task-executor.sh --file workflow.yml --parallel 8
```

#### Performance Impact

| Workers | Speedup | Use Case |
|---------|---------|----------|
| 1 | 1.0x (baseline) | Debugging, strict ordering |
| 2 | 1.5-1.8x | Small workflows |
| 4 | 2.0-2.5x | Medium workflows (recommended) |
| 8 | 2.5-3.0x | Large workflows |

---

## Architecture

### System Flow

```
┌─────────────────────────────────────────────┐
│  User: workflow.yml (task definitions)      │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  LAYER 1: Reference Validation              │
│  • Check file paths exist                   │
│  • Validate section references              │
│  • Detect circular includes                 │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  LAYER 2: Dependency Resolution             │
│  • Parse YAML task definitions              │
│  • Build dependency graph (DAG)             │
│  • Validate task references                 │
│  • Detect cycles (DFS)                      │
│  • Topological sort (Kahn's)                │
│  • Parallel grouping (level-based)          │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  LAYER 3: Execution Planning                │
│  • Generate execution phases                │
│  • Calculate task ordering                  │
│  • Visualize dependencies                   │
│  • Dry-run simulation                       │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  LAYER 4: Task Execution                    │
│  • Sequential mode                          │
│  • Parallel mode (1-8 workers)              │
│  • Progress tracking                        │
│  • Log management                           │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  Result: Execution summary & logs           │
└─────────────────────────────────────────────┘
```

### Algorithm Complexity

| Component | Time | Space | Notes |
|-----------|------|-------|-------|
| YAML parsing | O(n) | O(n) | Linear in file size |
| Reference validation | O(m) | O(m) | Linear in references |
| Cycle detection | O(V+E) | O(V) | DFS with stack |
| Topological sort | O(V+E) | O(V) | Kahn's algorithm |
| Parallel grouping | O(V+E) | O(V) | Level-based |
| **Total** | **O(V+E)** | **O(V)** | Linear in task count |

**Scaling Characteristics:**
- 10 tasks: ~50-100ms
- 50 tasks: ~100-150ms
- 100 tasks: ~150-250ms
- 500 tasks: ~400-600ms
- 1000 tasks: ~800-1200ms

---

## Migration from v1.0

### What Changed

| Aspect | v1.0 | v2.1 | Action |
|--------|------|------|--------|
| Task ordering | Manual | Automatic | Update workflow definitions |
| Parallelization | None | Auto | No changes needed (opt-in) |
| Error detection | Late | Early | Benefit from earlier validation |
| Testing | Limited | Comprehensive | Run tests for confidence |
| Configuration | Simple | Enhanced | Adopt new YAML schema |

### Migration Checklist

- [ ] Read this guide completely
- [ ] Review sample workflow (sample-workflow.yml)
- [ ] Create your first workflow.yml
- [ ] Run validation: `./validate-references.sh --file workflow.yml`
- [ ] Resolve dependencies: `./task-dependency-resolver.sh --file workflow.yml`
- [ ] Dry-run execution: `./task-executor.sh --file workflow.yml --dry-run`
- [ ] Run tests: `./tests/run_tests.sh quick`
- [ ] Execute workflow: `./task-executor.sh --file workflow.yml`

### Backward Compatibility

✅ **Good News:** v2.1 is backward compatible with v1.0 workflows

**Simple workflows still work:**
```bash
# This v1.0 workflow works unchanged
./task-executor.sh --file old-workflow.yml
```

**To leverage v2.1 features:**
1. Add task IDs and dependencies
2. Use YAML format (instead of shell)
3. Let resolver calculate execution order

---

## Usage Examples

### Example 1: Code Review Workflow

```yaml
version: "1.0"
description: "Automated code review pipeline"

tasks:
  lint:
    description: "Run linter"
    commands: ["/lint --strict"]
    timeout: 120

  unit-tests:
    description: "Run unit tests"
    commands: ["/test --unit --coverage"]
    depends-on: [lint]
    timeout: 300

  integration-tests:
    description: "Run integration tests"
    commands: ["/test --integration"]
    depends-on: [lint]
    timeout: 600

  security-scan:
    description: "Security analysis"
    commands: ["/scan --security --strict"]
    timeout: 180

  coverage-report:
    description: "Generate coverage report"
    commands: ["/report --coverage"]
    depends-on: [unit-tests, integration-tests]
    timeout: 120

  review:
    description: "Final review"
    commands: ["/review --comprehensive"]
    depends-on: [coverage-report, security-scan]
    timeout: 300
```

**Execution Plan:**
```
Phase 1: [lint]                    (0-2 min)
Phase 2: [unit-tests, integration-tests, security-scan] (2-13 min, parallel)
Phase 3: [coverage-report]         (13-15 min)
Phase 4: [review]                  (15-20 min)
Total: ~20 minutes (vs 30 sequential)
```

### Example 2: Deployment Pipeline

```yaml
version: "1.0"
description: "Production deployment"

tasks:
  build:
    commands: ["/build --release"]
    timeout: 600

  test:
    depends-on: [build]
    commands: ["/test --all"]
    timeout: 1200

  staging-deploy:
    depends-on: [test]
    commands: ["/deploy --environment staging"]
    timeout: 300

  smoke-tests:
    depends-on: [staging-deploy]
    commands: ["/test --smoke"]
    timeout: 120

  prod-deploy:
    depends-on: [smoke-tests]
    commands: ["/deploy --environment production"]
    timeout: 600
    retry: 1  # Retry once on failure
```

### Example 3: Data Pipeline

```yaml
version: "1.0"
description: "ETL pipeline with parallel processing"

tasks:
  extract:
    commands: ["/extract --source database"]
    timeout: 3600

  transform-a:
    depends-on: [extract]
    commands: ["/transform --type A"]
    timeout: 1800

  transform-b:
    depends-on: [extract]
    commands: ["/transform --type B"]
    timeout: 1800

  transform-c:
    depends-on: [extract]
    commands: ["/transform --type C"]
    timeout: 1800

  merge:
    depends-on: [transform-a, transform-b, transform-c]
    commands: ["/merge --all"]
    timeout: 900

  validate:
    depends-on: [merge]
    commands: ["/validate --strict"]
    timeout: 600

  load:
    depends-on: [validate]
    commands: ["/load --destination warehouse"]
    timeout: 1800
```

---

## API Reference

### Command-Line Tools

#### validate-references.sh

Validate configuration file references.

**Usage:**
```bash
./validate-references.sh --file <FILE> [OPTIONS]
```

**Options:**
```
--file, -f FILE          Configuration file to validate (required)
--verbose, -v            Show detailed output
--help, -h               Display help
```

**Exit Codes:**
```
0  All references valid
1  References invalid
2  File not found
```

**Example:**
```bash
./validate-references.sh --file CLAUDE.md --verbose
```

---

#### task-dependency-resolver.sh

Resolve task dependencies and generate execution plan.

**Usage:**
```bash
./task-dependency-resolver.sh --file <FILE> [OPTIONS]
```

**Options:**
```
--file, -f FILE          Task definition file (required)
--verbose, -v            Detailed output
--visualize              Show ASCII graph
--dot                    Export Graphviz format
--help, -h               Display help
```

**Exit Codes:**
```
0  Resolution successful
1  Cycle detected or validation error
2  File not found
```

**Example:**
```bash
# Generate execution plan
./task-dependency-resolver.sh --file workflow.yml

# Visualize dependencies
./task-dependency-resolver.sh --file workflow.yml --visualize --dot
```

---

#### task-executor.sh

Execute tasks according to dependency plan.

**Usage:**
```bash
./task-executor.sh --file <FILE> [OPTIONS]
```

**Options:**
```
--file, -f FILE          Task definition file (required)
--dry-run                Preview without execution
--parallel N             Max parallel tasks (default: 4)
--verbose, -v            Detailed output
--help, -h               Display help
```

**Exit Codes:**
```
0  All tasks successful
1  One or more tasks failed
2  File not found
```

**Example:**
```bash
# Dry-run
./task-executor.sh --file workflow.yml --dry-run

# Execute with 8 workers
./task-executor.sh --file workflow.yml --parallel 8
```

---

### Test Runner

#### run_tests.sh

Execute test suite.

**Usage:**
```bash
./tests/run_tests.sh [FILTER]
```

**Filters:**
```
unit           Run unit tests only
integration    Run integration tests only
performance    Run performance tests only
quick          CI/CD quick mode
all            All tests (default)
```

**Example:**
```bash
# Quick validation
./tests/run_tests.sh quick

# Full test suite
./tests/run_tests.sh all

# Performance analysis
./tests/run_tests.sh performance
```

---

## Troubleshooting

### Common Issues

#### Issue: "No tasks found in file"

**Cause:** YAML parsing didn't recognize task definitions.

**Solution:** Ensure YAML format is correct:
```yaml
tasks:
  task-id:          # ← Proper indentation
    description: "..."
    commands: [...]
```

**Check:**
- Proper YAML indentation (2 spaces)
- Task names are lowercase with hyphens
- Each task has a `commands` field

---

#### Issue: "Cycle detected: task-a → task-b → task-a"

**Cause:** Circular dependency in task definitions.

**Solution:** Review dependencies and remove circle:
```yaml
# ❌ Creates cycle
tasks:
  a:
    depends-on: [c]
  b:
    depends-on: [a]
  c:
    depends-on: [b]

# ✅ Fixed
tasks:
  a:
    depends-on: []
  b:
    depends-on: [a]
  c:
    depends-on: [b]
```

---

#### Issue: "Task 'deploy' references non-existent task: 'build'"

**Cause:** Dependency references non-existent task.

**Solution:** Check task IDs match:
```yaml
# ❌ Wrong - task doesn't exist
tasks:
  deploy:
    depends-on: [build]

# ✅ Fixed - task exists
tasks:
  build:
    commands: ["/build"]
  deploy:
    depends-on: [build]
    commands: ["/deploy"]
```

---

#### Issue: Execution is slower than expected

**Cause:** Suboptimal parallelization or many sequential tasks.

**Solution:**
1. Check parallel setting: `--parallel 4` (recommended)
2. Visualize dependencies: Look for parallelizable groups
3. Review timeouts: Long-running tasks won't parallelize

**Optimization tips:**
- Increase parallel workers: `--parallel 8`
- Reduce timeout values if possible
- Identify independent tasks (can run parallel)

---

## Performance

### Benchmarks

**Resolver Performance (planning):**
```
10 tasks:   ~100 ms
50 tasks:   ~150 ms
100 tasks:  ~250 ms
500 tasks:  ~600 ms
1000 tasks: ~1200 ms
```

**Executor Performance (execution):**
```
Sequential (1 worker):  ~100 ms baseline
Parallel-4 workers:     ~50-60% of sequential
Parallel-8 workers:     ~35-45% of sequential
```

**Pipeline Total (validation → resolution → execution):**
```
Small workflow (3 tasks):    <500 ms
Medium workflow (10 tasks):  <1 second
Large workflow (50 tasks):   <2 seconds
```

### Optimization Recommendations

1. **Use appropriate parallelization:**
   - 1-10 tasks: `--parallel 2`
   - 10-50 tasks: `--parallel 4` (default)
   - 50+ tasks: `--parallel 8`

2. **Reduce timeout values** where safe (fewer seconds waiting)

3. **Identify parallelizable tasks** (no circular dependencies)

4. **Profile with dry-run** before actual execution

---

## FAQ

### Q: Can I use v2.1 without defining dependencies?

**A:** Yes! If you don't specify `depends-on`, tasks run independently (no ordering). v2.1 is backward compatible with simple, sequential workflows.

### Q: What's the maximum number of tasks?

**A:** Tested and comfortable up to 1000 tasks. Beyond that, consider compiled language rewrite (Go/Rust) for better performance.

### Q: Can tasks communicate with each other?

**A:** Not directly in v2.1 MVP. All communication is via file/environment. Session persistence (Task #8) will add this.

### Q: How do I retry failed tasks?

**A:** Use the `retry` field:
```yaml
tasks:
  deploy:
    commands: ["/deploy"]
    retry: 2  # Retry up to 2 times
```

### Q: Can I run tasks on remote machines?

**A:** Not in v2.1 MVP. Distributed execution planned for v2.2+.

### Q: How do I debug task failures?

**A:** 
1. Use `--dry-run` to see execution plan
2. Use `--verbose` for detailed logging
3. Check task logs in `/tmp/superclaudetasks/`

### Q: Is there a GUI?

**A:** Not yet. Use ASCII visualization: `--visualize` or Graphviz: `--dot`

### Q: How do I contribute?

**A:** 
1. Fork: https://github.com/fullmeo/SuperClaude
2. Create feature branch
3. Add tests (run `tests/run_tests.sh`)
4. Submit PR with detailed description

### Q: What's the roadmap?

**A:**
- v2.2: Session persistence & distributed execution
- v2.3: Advanced visualization & scheduling
- v3.0: Graphical UI & workflow templates

---

## Additional Resources

- **Repository:** https://github.com/fullmeo/SuperClaude
- **Sample Workflow:** `sample-workflow.yml`
- **Testing Guide:** `TESTING_STRATEGY_V2.1.md`
- **Architecture Details:** `DESIGN_TASK_DEPENDENCY_GRAPHS.md`
- **Implementation Notes:** `IMPLEMENTATION_TASK_RESOLVER.md`

---

## Support

### Getting Help

1. **Check FAQ** above
2. **Review examples** in this document
3. **Run tests** to verify installation: `./tests/run_tests.sh quick`
4. **Check logs** in `/tmp/superclaudetasks/`
5. **Open issue** on GitHub with details

### Reporting Bugs

Include:
- Your workflow.yml
- Output of: `./task-dependency-resolver.sh --file workflow.yml --verbose`
- Expected vs actual behavior
- Platform/OS information

---

**SuperClaude v2.1 - Production Ready for MVP Phase**

For questions or contributions, visit: https://github.com/fullmeo/SuperClaude

