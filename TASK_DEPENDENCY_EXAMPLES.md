# Task Dependency Graph Examples

**Visual Examples for v2.1 Task Dependency System**

---

## Example 1: Simple Sequential Workflow

### Definition (YAML)

```yaml
tasks:
  analyze:
    description: "Analyze code quality"
    commands: ["/analyze --code --think"]
  
  review:
    description: "Review changes"
    commands: ["/review --quality"]
    depends-on: [analyze]
  
  improve:
    description: "Suggest improvements"
    commands: ["/improve --code"]
    depends-on: [review]
```

### Graph Visualization

```
analyze ──────→ review ──────→ improve
  (30s)         (20s)           (15s)

Execution:
═════════════════════════════════════
Phase 1: analyze (0-30s)
Phase 2: review (30-50s)
Phase 3: improve (50-65s)
═════════════════════════════════════
Total: 65 seconds (sequential)
```

### Execution Plan Output

```
Task Execution Plan:
══════════════════════════════════════

Sequence: 1 → 2 → 3
No parallel opportunities

Phase 1: analyze
  └─ Status: pending
  └─ Depends: (none)
  └─ Est. time: 30s
  
Phase 2: review
  └─ Status: pending
  └─ Depends: analyze
  └─ Est. time: 20s
  
Phase 3: improve
  └─ Status: pending
  └─ Depends: review
  └─ Est. time: 15s

Total estimated time: 65 seconds
Critical path: analyze → review → improve
```

---

## Example 2: Parallel Analysis Workflow

### Definition (YAML)

```yaml
tasks:
  analyze:
    description: "Analyze code"
    commands: ["/analyze --code"]
  
  review:
    description: "Code review"
    commands: ["/review --quality"]
    depends-on: [analyze]
  
  security:
    description: "Security audit"
    commands: ["/scan --security"]
    depends-on: [analyze]
  
  performance:
    description: "Performance check"
    commands: ["/analyze --profile"]
    depends-on: [analyze]
  
  report:
    description: "Generate report"
    commands: ["/document --comprehensive"]
    depends-on: [review, security, performance]
```

### Graph Visualization

```
              ┌─ review (20s) ─┐
              │                │
analyze ──┬──→ security (25s) ──┼──→ report (15s)
  (30s)   │                     │
          └─ performance (45s) ─┘

Execution Timeline:
═══════════════════════════════════════════════════
analyze         ████████████████████░░░░░░░░░░░░░░░░ (30s, 0-30)
review          ░░░░░░░░░░░░░░░░░░░░████░░░░░░░░░░░░ (20s, 30-50)
security        ░░░░░░░░░░░░░░░░░░░░░░░████░░░░░░░░░ (25s, 30-55)
performance     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░████░░░░ (45s, 30-75)
report          ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████░░ (15s, 75-90)
═══════════════════════════════════════════════════
                0         20        40        60   80
```

### Execution Plan Output

```
Task Execution Plan:
════════════════════════════════════════════════════

Critical Path: analyze → performance → report (90s)
Parallelizable: review + security + performance

Phase 1: [analyze]
  └─ Status: pending
  └─ Depends: (none)
  └─ Est. time: 30s
  └─ Finish by: 30s

Phase 2: [review] [security] [performance]  [PARALLEL]
  ├─ review (20s, 30-50s)
  ├─ security (25s, 30-55s)
  ├─ performance (45s, 30-75s)
  └─ Finish by: 75s

Phase 3: [report]
  └─ Status: pending
  └─ Depends: review, security, performance
  └─ Est. time: 15s
  └─ Finish by: 90s

Efficiency:
  Sequential time: 135 seconds
  Parallel time: 90 seconds
  Speedup: 1.5x (33% faster)
  Critical path: analyze → performance → report
```

---

## Example 3: Complex Enterprise Workflow

### Definition (YAML)

```yaml
tasks:
  # Phase 1: Analysis
  static-analysis:
    commands: ["/analyze --code --think-hard"]
  dependency-check:
    commands: ["/scan --dependencies"]
  
  # Phase 2: Testing (parallel after analysis)
  unit-tests:
    commands: ["/test --unit --coverage"]
    depends-on: [static-analysis]
  integration-tests:
    commands: ["/test --integration"]
    depends-on: [static-analysis]
  security-tests:
    commands: ["/scan --security --strict"]
    depends-on: [dependency-check]
  
  # Phase 3: Code review (after initial tests)
  code-review:
    commands: ["/review --quality --evidence"]
    depends-on: [unit-tests]
  performance-analysis:
    commands: ["/analyze --profile --think"]
    depends-on: [integration-tests]
  
  # Phase 4: Build (after passing tests)
  compile:
    commands: ["/build --compile"]
    depends-on: [unit-tests, security-tests]
  build-release:
    commands: ["/build --production"]
    depends-on: [compile]
  
  # Phase 5: Documentation
  generate-docs:
    commands: ["/document --comprehensive"]
    depends-on: [code-review, performance-analysis]
  
  # Phase 6: Deploy
  deploy-staging:
    commands: ["/deploy --env staging"]
    depends-on: [build-release]
  
  test-staging:
    commands: ["/test --e2e --env staging"]
    depends-on: [deploy-staging]
  
  deploy-prod:
    commands: ["/deploy --env prod"]
    depends-on: [test-staging, generate-docs]
  
  notification:
    commands: ["echo 'Deployment complete'"]
    depends-on: [deploy-prod]
    optional: true
```

### Graph Visualization (Simplified)

```
┌─────────────────────────────────────────────────────────────┐
│                    Complex Workflow                          │
│                                                              │
│  static-analysis ──┬──→ unit-tests ────┬──→ code-review ──┐ │
│                    │                   │                  │ │
│  dependency-check ─┴──→ security-tests │                  │ │
│                         │               │                  │ │
│                    integration-tests ──┼──→ perf-analysis ─┤ │
│                         │               │                  │ │
│                    compile ─────────────┴──→ build-release │ │
│                                              │              │ │
│                                              ├─→ generate-docs ┤
│                                              │              │ │
│                                    deploy-staging ────┐    │ │
│                                         │              │    │ │
│                                    test-staging ──────┼────┤ │
│                                         │              │    │ │
│                                    deploy-prod ───────┴────┤ │
│                                         │                  │ │
│                                    notification ◄──────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Execution Plan with Phases

```
Execution Plan: Complex Enterprise Workflow
════════════════════════════════════════════════════════════════

Estimated Total Time: 4 hours 15 minutes
Critical Path: static-analysis → unit-tests → code-review → 
              generate-docs → deploy-prod → notification (longest)

Phase 1: Initial Analysis [PARALLEL]
  ├─ static-analysis (40 min, CPU bound)
  └─ dependency-check (10 min, IO bound)
  Finishes: 40 min (limited by longest)

Phase 2: Testing Phase [PARALLEL] 
  ├─ unit-tests (30 min, depends: static-analysis)
  ├─ integration-tests (45 min, depends: static-analysis)
  ├─ security-tests (25 min, depends: dependency-check)
  Starts: 40 min
  Finishes: 40 + 45 = 85 min (limited by integration-tests)

Phase 3: Review Phase [PARALLEL]
  ├─ code-review (20 min, depends: unit-tests)
  ├─ performance-analysis (30 min, depends: integration-tests)
  Starts: 85 min
  Finishes: 85 + 30 = 115 min (limited by perf-analysis)

Phase 4: Build Phase [SEQUENTIAL]
  ├─ compile (15 min, depends: unit-tests, security-tests)
  └─ build-release (10 min, depends: compile)
  Starts: 115 min
  Finishes: 115 + 25 = 140 min

Phase 5: Documentation [SEQUENTIAL]
  └─ generate-docs (20 min, depends: code-review, perf-analysis)
  Starts: 115 min
  Finishes: 115 + 20 = 135 min

Phase 6: Deployment [SEQUENTIAL]
  ├─ deploy-staging (30 min, depends: build-release)
  ├─ test-staging (40 min, depends: deploy-staging)
  ├─ deploy-prod (30 min, depends: test-staging, generate-docs)
  └─ notification (5 min, depends: deploy-prod, optional)
  Starts: 140 min (build completes)
  Finishes: 140 + 30 + 40 + 30 + 5 = 245 min

FINAL TIME: 245 minutes (4 hours 5 minutes)

Parallelization Benefit:
  If sequential: 40 + 10 + 30 + 45 + 25 + 20 + 30 + 15 + 10 + 20 + 
                 30 + 40 + 30 + 5 = 350 minutes
  With parallelization: 245 minutes
  Speedup: 1.43x (30% faster) ✅
  Time saved: 105 minutes
```

### Dependency Analysis

```
Task Dependency Analysis:
═════════════════════════════════════════════════════════════════

Root Tasks (no dependencies):
  • static-analysis
  • dependency-check

Leaf Tasks (no dependents):
  • notification

Critical Path (determines total time):
  1. static-analysis (40 min) ← 0 min
  2. unit-tests (30 min) ← 40 min
  3. code-review (20 min) ← 70 min
  4. generate-docs (20 min) ← 90 min
  5. deploy-prod (30 min) ← 135 min
  6. notification (5 min) ← 165 min
  Total: 165 minutes on critical path
  
  WAIT: Recalculating...
  Actually: 40 + 45(integ) + 30(perf) + 25(build) + 30(staging) + 
           40(test-staging) + 30(prod) + 5(notif) = 245 min ✅

Bottlenecks (likely delays):
  ⚠️  integration-tests (45 min) - slowest test
  ⚠️  test-staging (40 min) - E2E tests
  ⚠️  deploy-staging (30 min) - I/O bound

Parallelizable Groups:
  Group 1: [static-analysis, dependency-check]
  Group 2: [unit-tests, integration-tests, security-tests]
  Group 3: [code-review, performance-analysis]
  Group 4: [compile]
  Group 5: [build-release, generate-docs]
  Group 6: [deploy-staging]
  Group 7: [test-staging]
  Group 8: [deploy-prod]
  Group 9: [notification]

Opportunities for Optimization:
  1. Cache unit test results if only minor changes
  2. Run security-tests in parallel with other tests earlier
  3. Move generate-docs to start after code-review (don't wait for perf)
  4. Use canary deployment for faster validation
  5. Implement artifact caching to skip duplicate builds
```

---

## Example 4: Error Scenarios

### Scenario A: Circular Dependency

**Invalid Definition:**
```yaml
tasks:
  task-a:
    commands: ["/analyze"]
    depends-on: [task-b]
  
  task-b:
    commands: ["/review"]
    depends-on: [task-c]
  
  task-c:
    commands: ["/improve"]
    depends-on: [task-a]  # Circular!
```

**Detection & Error:**
```
❌ CYCLE DETECTED IN TASK GRAPH
═══════════════════════════════════════════════════════════════

Circular dependency found:
  task-a → task-b → task-c → task-a

This forms a cycle and cannot be executed.

Graph Visualization:
    ┌─────────────────┐
    │   task-a        │
    │  (/analyze)     │
    │                 │
    │   depends-on:   │────┐
    │   task-b        │    │
    └─────────────────┘    │
          ▲                 ▼
          │            ┌─────────────────┐
          └────────────│   task-b        │
                       │  (/review)      │
                       │                 │
                       │   depends-on:   │────┐
                       │   task-c        │    │
                       └─────────────────┘    │
                             ▲                ▼
                             │          ┌─────────────────┐
                             └──────────│   task-c        │
                                        │  (/improve)     │
                                        │                 │
                                        │   depends-on:   │
                                        │   task-a  ───┐  │
                                        └─────────────┼──┘
                                                      │
                                        (CYCLE HERE) ─┘

To fix:
  1. Remove the dependency from task-c to task-a, OR
  2. Remove the dependency from task-b to task-c, OR
  3. Remove the dependency from task-a to task-b

Example fix:
  task-c:
    commands: ["/improve"]
    depends-on: []  # Remove dependency to task-a
```

### Scenario B: Missing Task Reference

**Invalid Definition:**
```yaml
tasks:
  analyze:
    commands: ["/analyze --code"]
  
  review:
    commands: ["/review"]
    depends-on: [analyze]
  
  deploy:
    commands: ["/deploy"]
    depends-on: [nonexistent-task]  # ❌ ERROR!
```

**Error Output:**
```
❌ MISSING TASK REFERENCE
═══════════════════════════════════════════════════════════════

Task 'deploy' references non-existent task: 'nonexistent-task'

Location: Line 14
  depends-on: [nonexistent-task]
                ^^^^^^^^^^^^^^^^

Available tasks:
  • analyze
  • review

Did you mean one of:
  • analyze (sounds similar?)

To fix:
  1. Ensure the referenced task is defined above
  2. Check spelling: nonexistent-task vs non-existent-task
  3. Create the missing task if needed
```

---

## Example 5: Retry & Error Handling

**Definition with Error Handling:**
```yaml
tasks:
  flaky-test:
    commands: ["/test --integration"]
    retry: 3           # Retry up to 3 times
    retry-delay: 30    # Wait 30 seconds between retries
    continue-on-error: false  # Fail if all retries exhausted
  
  optional-step:
    commands: ["/scan --experimental"]
    optional: true     # Don't block if this fails
    continue-on-error: true
  
  critical-deploy:
    commands: ["/deploy --prod"]
    depends-on: [flaky-test]
    continue-on-error: false  # Must succeed
```

**Execution with Retries:**
```
Task: flaky-test
Try 1: ❌ FAILED (connection timeout)
  Wait 30 seconds...
Try 2: ❌ FAILED (connection timeout)
  Wait 30 seconds...
Try 3: ❌ FAILED (connection timeout)
  Wait 30 seconds...
Try 4: ✅ SUCCESS (recovered)

Task: optional-step
  ⚠️  WARNING: FAILED (but optional)
  Continue anyway...

Task: critical-deploy
  ✅ Running (flaky-test succeeded)
```

---

## Example 6: Conditional Execution (Future Enhancement)

**Proposed Syntax:**
```yaml
tasks:
  build:
    commands: ["/build"]
  
  test:
    commands: ["/test"]
    depends-on: [build]
  
  deploy-staging:
    commands: ["/deploy --staging"]
    depends-on: [test]
  
  # Only deploy to production if all tests pass
  deploy-prod:
    commands: ["/deploy --prod"]
    depends-on: [deploy-staging]
    condition: "test.result == 'success'"
```

---

These examples demonstrate the flexibility and power of the task dependency graph system for SuperClaude v2.1.
