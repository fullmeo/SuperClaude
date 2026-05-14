# SuperClaude v2.1 - Quick Start (5 Minutes)

## Installation (1 min)

```bash
git clone https://github.com/fullmeo/SuperClaude.git
cd SuperClaude
chmod +x *.sh tests/*.sh tests/*/*.sh
```

## Your First Workflow (4 min)

### Step 1: Create workflow.yml
```yaml
version: "1.0"
description: "My first workflow"

tasks:
  step1:
    description: "First step"
    commands: ["/analyze --code"]
    timeout: 120

  step2:
    description: "Second step"
    commands: ["/test --unit"]
    depends-on: [step1]
    timeout: 300

  step3:
    description: "Third step"
    commands: ["/report"]
    depends-on: [step2]
    timeout: 60
```

### Step 2: Validate
```bash
./validate-references.sh --file workflow.yml
# Output: ✓ All task references valid
```

### Step 3: Plan
```bash
./task-dependency-resolver.sh --file workflow.yml
# Output: Task Execution Plan with 3 phases
```

### Step 4: Execute
```bash
# Preview without execution
./task-executor.sh --file workflow.yml --dry-run

# Run it
./task-executor.sh --file workflow.yml --parallel 4
```

## Common Commands

```bash
# Validate references
./validate-references.sh --file workflow.yml

# View execution plan
./task-dependency-resolver.sh --file workflow.yml

# Visualize dependencies
./task-dependency-resolver.sh --file workflow.yml --visualize

# Dry-run execution
./task-executor.sh --file workflow.yml --dry-run

# Run with 4 workers
./task-executor.sh --file workflow.yml --parallel 4

# Run tests
./tests/run_tests.sh quick
```

## Dependency Patterns

### Linear
```yaml
A → B → C
tasks:
  a: {commands: ["/a"]}
  b: {depends-on: [a], commands: ["/b"]}
  c: {depends-on: [b], commands: ["/c"]}
```

### Parallel
```yaml
    ↙ B ↘
A ┤        D
    ↘ C ↗

tasks:
  a: {commands: ["/a"]}
  b: {depends-on: [a], commands: ["/b"]}
  c: {depends-on: [a], commands: ["/c"]}
  d: {depends-on: [b, c], commands: ["/d"]}
```

## Next Steps

- Read full guide: `SUPERCLAUDEV2.1_GUIDE.md`
- Review sample: `sample-workflow.yml`
- Run tests: `./tests/run_tests.sh all`

---

**Ready to build awesome workflows?** Let's go! 🚀
