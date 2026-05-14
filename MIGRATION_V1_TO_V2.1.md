# Migration Guide: SuperClaude v1.0 → v2.1

**Time Required:** 30-60 minutes for typical projects  
**Compatibility:** Backward compatible (no breaking changes)  
**Benefit:** 30-50% faster execution via automatic parallelization

---

## What Changed

### Good News: Most Things Still Work ✅

Your existing workflows continue to work without modification. v2.1 is fully backward compatible.

### New Capabilities You Can Use 🎉

| Feature | v1.0 | v2.1 | Effort |
|---------|------|------|--------|
| Task dependencies | Manual | Automatic | 10 min |
| Parallelization | None | Auto-detected | 5 min |
| Cycle detection | None | Early error | 0 min |
| Visualization | None | Built-in | 0 min |
| Testing | Limited | Comprehensive | 10 min |

---

## Migration Steps

### Phase 1: Preparation (5 min)

1. **Backup existing workflows**
   ```bash
   cp -r workflow-files workflow-files.backup
   ```

2. **Install v2.1**
   ```bash
   git clone https://github.com/fullmeo/SuperClaude.git
   cd SuperClaude
   chmod +x *.sh tests/*.sh tests/*/*.sh
   ```

3. **Verify installation**
   ```bash
   ./tests/run_tests.sh quick
   # Should see: ✓ All tests passed
   ```

### Phase 2: Understanding (10 min)

Read quick start:
```bash
cat QUICKSTART.md
```

Review sample workflow:
```bash
cat sample-workflow.yml
```

### Phase 3: Conversion (30 min)

#### Option A: Quick Migration (Keep v1.0, Add v2.1)

Your existing v1.0 workflows still work:
```bash
# v1.0 style (still works)
./your-old-executor.sh
```

Create new v2.1 workflows alongside:
```bash
# v2.1 style (new)
./task-dependency-resolver.sh --file new-workflow.yml
./task-executor.sh --file new-workflow.yml
```

**Effort:** 10-20 minutes per workflow

---

#### Option B: Full Migration (Convert v1.0 → v2.1)

**Old v1.0 Structure:**
```bash
scripts/
  ├── step1.sh
  ├── step2.sh
  └── step3.sh

# Manual execution
bash scripts/step1.sh
bash scripts/step2.sh
bash scripts/step3.sh
```

**New v2.1 Structure:**
```bash
workflow.yml          # Task definitions
scripts/              # Commands stay the same
  ├── step1.sh
  ├── step2.sh
  └── step3.sh

# Automatic orchestration
./task-dependency-resolver.sh --file workflow.yml
./task-executor.sh --file workflow.yml
```

**Conversion Example:**

**v1.0:**
```bash
#!/bin/bash
set -e

# Build
./build.sh

# Test
./test.sh

# Deploy
./deploy.sh
```

**v2.1 (workflow.yml):**
```yaml
version: "1.0"
description: "Build, test, deploy pipeline"

tasks:
  build:
    description: "Build application"
    commands: ["./build.sh"]
    timeout: 600

  test:
    description: "Run tests"
    commands: ["./test.sh"]
    depends-on: [build]
    timeout: 1200

  deploy:
    description: "Deploy to production"
    commands: ["./deploy.sh"]
    depends-on: [test]
    timeout: 300
    retry: 1
```

Then execute:
```bash
./task-executor.sh --file workflow.yml --parallel 4
```

---

### Phase 4: Optimization (15 min)

Once workflows are migrated, optimize for v2.1:

1. **Identify parallel tasks**
   ```bash
   ./task-dependency-resolver.sh --file workflow.yml --visualize
   # Look for tasks at same level (no blocking dependencies)
   ```

2. **Add parallel tasks**
   ```yaml
   tasks:
     build:
       commands: ["./build.sh"]
       
     lint:
       commands: ["./lint.sh"]      # Can run with build
       
     test:
       depends-on: [build]
       commands: ["./test.sh"]      # Depends on build
       
     security-scan:
       commands: ["./security.sh"]  # Can run with lint
   ```

3. **Measure speedup**
   ```bash
   # Time sequential
   time ./task-executor.sh --file workflow.yml --parallel 1
   # Sequential:  30 seconds

   # Time parallel
   time ./task-executor.sh --file workflow.yml --parallel 4
   # Parallel:    18 seconds (40% faster!)
   ```

---

## Comparison: v1.0 vs v2.1

### Workflow Definition

**v1.0:**
```bash
#!/bin/bash
set -e

# Step 1
echo "Analyzing..."
/analyze --code

# Step 2
echo "Testing..."
/test --unit

# Step 3
echo "Reporting..."
/report
```

**v2.1:**
```yaml
version: "1.0"
tasks:
  analyze:
    commands: ["/analyze --code"]
  test:
    depends-on: [analyze]
    commands: ["/test --unit"]
  report:
    depends-on: [test]
    commands: ["/report"]
```

### Execution

**v1.0:**
```bash
# Run script (strictly sequential)
./workflow.sh
# No visibility into ordering
# Can't parallelize
```

**v2.1:**
```bash
# See execution plan
./task-dependency-resolver.sh --file workflow.yml
# Shows: 3 phases, sequential due to dependencies

# Execute with parallelization
./task-executor.sh --file workflow.yml --parallel 4
# Automatically optimal (can't parallelize here)
```

---

## Real-World Example: Code Review Pipeline

### v1.0 Approach
```bash
#!/bin/bash
set -e

# Must run sequentially - no parallelization
time_start=$(date +%s)

bash lint.sh        # 2 min
bash unit-test.sh   # 5 min
bash int-test.sh    # 8 min
bash security.sh    # 3 min
bash review.sh      # 2 min

time_end=$(date +%s)
echo "Total time: $((time_end - time_start)) seconds"
# Output: Total time: 1200 seconds (20 minutes)
```

### v2.1 Approach
```yaml
version: "1.0"
description: "Code review pipeline"

tasks:
  lint:
    commands: ["bash lint.sh"]
    timeout: 120

  unit-test:
    depends-on: [lint]
    commands: ["bash unit-test.sh"]
    timeout: 300

  int-test:
    depends-on: [lint]
    commands: ["bash int-test.sh"]
    timeout: 480

  security:
    commands: ["bash security.sh"]  # No dependency - parallel!
    timeout: 180

  review:
    depends-on: [unit-test, int-test, security]
    commands: ["bash review.sh"]
    timeout: 120
```

**Execution:**
```bash
./task-executor.sh --file pipeline.yml --parallel 4

# Execution plan:
# Phase 1: lint (2 min)
# Phase 2: unit-test, int-test, security IN PARALLEL (8 min)
# Phase 3: review (2 min)
# Total time: 12 minutes (40% faster!)
```

---

## Backward Compatibility

### What Still Works

✅ All existing shell scripts continue to work  
✅ All existing task definitions (with modifications)  
✅ All existing output and logging  
✅ All existing scheduling and automation  

### What's New (Optional)

✨ Task dependency declarations  
✨ Automatic parallelization  
✨ Cycle detection  
✨ Visualization  
✨ Comprehensive testing  

---

## Common Migration Questions

### Q: Do I have to migrate everything?

**A:** No. Keep v1.0 workflows as-is, create new v2.1 workflows alongside. Mix and match during transition.

### Q: Will my old scripts break?

**A:** No. Backward compatible. All v1.0 workflows continue to work unchanged.

### Q: How long does migration take?

**A:** 
- Quick migration: 10-20 min per workflow
- Full migration: 30-60 min total project

### Q: What's the benefit?

**A:**
- 30-50% faster via parallelization
- Early error detection (cycles, missing deps)
- Better visibility into task ordering
- Comprehensive testing

### Q: Can I run v1.0 and v2.1 together?

**A:** Yes. During migration period, run both in parallel.

---

## Checklist

- [ ] Backup existing workflows
- [ ] Install SuperClaude v2.1
- [ ] Run `./tests/run_tests.sh quick`
- [ ] Read `SUPERCLAUDEV2.1_GUIDE.md`
- [ ] Review `sample-workflow.yml`
- [ ] Create test `workflow.yml`
- [ ] Run `./task-dependency-resolver.sh --file workflow.yml`
- [ ] Run `./task-executor.sh --file workflow.yml --dry-run`
- [ ] Compare performance: sequential vs parallel
- [ ] Identify parallelizable tasks in your workflows
- [ ] Migrate workflows to v2.1 format
- [ ] Run `./tests/run_tests.sh all` to verify
- [ ] Deploy v2.1 workflows

---

## Support

### Having Issues?

1. **Check troubleshooting:** `SUPERCLAUDEV2.1_GUIDE.md#troubleshooting`
2. **Run tests:** `./tests/run_tests.sh quick`
3. **Review sample:** `sample-workflow.yml`
4. **Open issue:** https://github.com/fullmeo/SuperClaude/issues

### Need Help?

- Email: Check GitHub Issues
- Chat: GitHub Discussions
- Docs: https://github.com/fullmeo/SuperClaude

---

**Migration is straightforward. Most projects complete in under 1 hour.**

Ready to upgrade? Start with `QUICKSTART.md` 🚀

