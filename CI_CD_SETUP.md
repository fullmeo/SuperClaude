# CI/CD Reference Validation Setup

**Task #3 Deliverable**  
**Version:** 1.0  
**Status:** Complete  
**Date:** 2026-05-11

---

## I. Overview

This document describes the GitHub Actions CI/CD integration for SuperClaude's reference validation system. The setup ensures configuration integrity through automated validation on every push and pull request.

### Goals
- ✅ Validate references on every code change
- ✅ Block PRs with invalid references
- ✅ Provide clear feedback to developers
- ✅ Generate validation reports
- ✅ Test installation procedures
- ✅ Maintain code quality

---

## II. Workflows Overview

### Workflow 1: Reference Validation (`validate-references.yml`)

**Trigger:** Push/PR to master/develop/main when config changes  
**Purpose:** Validate @include references  
**Required:** YES (blocks merge)

**Jobs:**
1. **validate-references** — Run validator on config
2. **comment-on-pr** — Comment results on PR (if failed)

**Success Criteria:** All references valid  
**Failure Action:** Block merge, comment with errors

---

### Workflow 2: Installation Testing (`test-install.yml`)

**Trigger:** Push/PR when install.sh changes  
**Purpose:** Test installation procedures  
**Required:** NO (informational)

**Jobs:**
1. **test-validator** — Run test suite on multiple OS/bash versions
2. **test-install-dry-run** — Test install script in dry-run mode
3. **summary** — Report overall status

**Success Criteria:** All tests pass  
**Platforms:** Ubuntu, macOS | Bash 4, 5

---

### Workflow 3: Quality Gate (`quality-gate.yml`)

**Trigger:** All PRs  
**Purpose:** Enforce quality standards  
**Required:** YES (blocks merge)

**Jobs:**
1. **quality-checks** — Run all quality checks
2. **branch-protection-status** — Report final status

**Checks:**
- Reference validation (if config changed)
- Validator tests (if validator changed)
- Merge conflict detection
- Documentation verification

---

## III. Workflow Files

### File Structure
```
.github/
└── workflows/
    ├── validate-references.yml    # Reference validation
    ├── test-install.yml           # Installation tests
    └── quality-gate.yml           # Quality gate checks
```

### File Details

| File | Size | Purpose | Required |
|------|------|---------|----------|
| validate-references.yml | 2.8 KB | Validate references | ✅ YES |
| test-install.yml | 3.5 KB | Test installation | ⚠️ NO |
| quality-gate.yml | 2.0 KB | Quality checks | ✅ YES |

---

## IV. Setup Instructions

### Step 1: Copy Workflow Files

The workflow files are already created in `.github/workflows/`:
```bash
.github/workflows/
├── validate-references.yml
├── test-install.yml
└── quality-gate.yml
```

### Step 2: Configure Branch Protection

**In GitHub Repository Settings:**

1. Go to: **Settings → Branches**
2. Add rule for `master` branch:
   - **Branch name pattern:** `master`
   - **Require status checks to pass:** ✅
   - **Require branches to be up to date:** ✅
   - **Dismiss stale pull request approvals:** ✅

3. **Required status checks:**
   - ✅ Reference Validation / Validate @include References
   - ✅ Quality Gate / Quality Gate Checks

4. **Required reviewers:**
   - Recommend: 1 reviewer minimum

5. **Dismiss stale reviews** when new commits pushed

6. **Require code reviews from code owners:** ✅

### Step 3: Add CODEOWNERS (Optional)

**File:** `.github/CODEOWNERS`

```
# Configuration validation
.claude/ @maintainer
CLAUDE.md @maintainer
validate-references.sh @maintainer
test_validate_references.sh @maintainer
```

### Step 4: Create PR Template (Optional)

**File:** `.github/pull_request_template.md`

```markdown
## Description
<!-- Describe your changes -->

## Configuration Changes
<!-- If you changed .claude/ or CLAUDE.md, describe what changed -->

## Testing
<!-- How did you test these changes? -->
- [ ] Run `./validate-references.sh` locally
- [ ] Run `bash test_validate_references.sh` locally
- [ ] Verify no merge conflicts
- [ ] Updated documentation

## Checklist
- [ ] References are valid
- [ ] Tests pass
- [ ] Documentation updated
- [ ] No merge conflicts
```

---

## V. Workflow Behavior

### Scenario 1: Valid Configuration Change

```
Developer pushes to PR with valid config changes
   ↓
GitHub Actions triggers validate-references.yml
   ↓
Reference validation runs ✓
   ↓
✅ Workflow succeeds
   ↓
PR shows green checkmark ✓
   ↓
PR can be merged (if other checks pass)
```

### Scenario 2: Invalid Configuration Change

```
Developer pushes to PR with broken reference
   ↓
GitHub Actions triggers validate-references.yml
   ↓
Reference validation detects error ✗
   ↓
❌ Workflow fails
   ↓
GitHub Comments on PR with error details
   ↓
PR shows red X, cannot merge
   ↓
Developer fixes issue and pushes again
   ↓
Validation re-runs automatically
   ↓
Process repeats until valid
```

### Scenario 3: Installation Script Changes

```
Developer modifies install.sh
   ↓
GitHub Actions triggers test-install.yml
   ↓
Test suite runs on multiple platforms
   ↓
Results uploaded as artifacts
   ↓
Quality gate checks if validator changed
   ↓
If validator changed: run validator tests
   ↓
Report status (informational)
```

---

## VI. Developer Workflow

### For Configuration Changes

```bash
# 1. Make changes to .claude/ or CLAUDE.md
nano .claude/CLAUDE.md

# 2. Validate locally before pushing
./validate-references.sh

# 3. If issues found, fix them
# ... fix errors ...

# 4. Re-validate
./validate-references.sh --report

# 5. Push to branch
git push origin feature-branch

# 6. Create PR
# GitHub Actions runs automatically

# 7. If PR fails:
#    - Review GitHub Actions output
#    - Review PR comments with details
#    - Fix issues locally
#    - Push again (workflow re-runs)

# 8. When all checks pass, can merge
```

### For Validator Changes

```bash
# 1. Modify validate-references.sh or tests
nano validate-references.sh

# 2. Run test suite locally
bash test_validate_references.sh

# 3. Test validator on config
./validate-references.sh --report

# 4. If tests fail:
#    - Fix implementation
#    - Re-run tests locally
#    - Verify all tests pass

# 5. Push changes
git push origin feature-branch

# 6. GitHub Actions runs tests on multiple platforms
# 7. Verify all platform-specific tests pass
# 8. PR can be merged when all checks pass
```

---

## VII. Error Handling & Resolution

### Error: Circular Reference Detected

**GitHub Output:**
```
❌ Reference Validation / Validate @include References

CIRCULAR REFERENCE
Location: CLAUDE.md:10
Path: CLAUDE.md → core.yml → CLAUDE.md
```

**Resolution:**
1. Identify the circular reference
2. Remove one of the references in the cycle
3. Verify with: `./validate-references.sh`
4. Push fix to PR
5. Workflow automatically re-runs

### Error: Missing File

**GitHub Output:**
```
❌ File not found
Reference: @include shared/missing.yml#Section
Location: commands/analyze.md:5
```

**Resolution:**
1. Either create the file: `mkdir -p shared && touch shared/missing.yml`
2. Or fix the reference path
3. Verify with: `./validate-references.sh`
4. Push fix to PR

### Error: Invalid Section

**GitHub Output:**
```
❌ Section not found
Reference: @include shared/core.yml#BadSection
Location: CLAUDE.md:10
Available: Core_Philosophy, Standards, Token_Economy
```

**Resolution:**
1. Use correct section name from "Available" list
2. Check YAML file for valid sections
3. Verify with: `./validate-references.sh`
4. Push fix to PR

### Error: Syntax Error

**GitHub Output:**
```
❌ Invalid YAML syntax
File: shared/broken.yml
Issue: Unmatched braces
```

**Resolution:**
1. Fix YAML syntax (check indentation, brackets)
2. Verify with: `./validate-references.sh`
3. Push fix to PR

---

## VIII. Workflow Actions & Artifacts

### Actions Used

```yaml
actions/checkout@v4
  - Check out repository code
  - Used by all workflows

actions/upload-artifact@v4
  - Upload validation reports
  - Upload test results
  - Retention: 30 days

actions/github-script@v7
  - Comment on PRs with results
  - Used to post validation errors
  - Provides detailed feedback

dorny/paths-filter@v2
  - Detect which files changed
  - Optimize workflow (skip unnecessary jobs)
  - Only used in quality-gate.yml
```

### Artifacts Generated

**Validation Report**
- File: `validation-report.txt`
- Generated: On every validation run
- Available: In Actions → Artifacts for 30 days
- Contains: Full validation results, errors, warnings

**Test Results**
- Files: `test-results-*` artifacts
- Generated: On test runs
- Available: For 30 days
- Contains: Test pass/fail details per platform

---

## IX. GitHub Checks & Statuses

### Required Checks (Must Pass to Merge)

1. **Reference Validation / Validate @include References**
   - Validates all @include references
   - Triggers on: config changes
   - Must pass: YES

2. **Quality Gate / Quality Gate Checks**
   - Runs all quality checks
   - Triggers on: all PRs
   - Must pass: YES

### Optional Checks (Informational)

1. **Test Installation / Test Reference Validator**
   - Tests validator on multiple platforms
   - Triggers on: validator changes
   - Must pass: NO (informational)

---

## X. Monitoring & Debugging

### View Workflow Status

**In GitHub UI:**
1. Go to: **Actions** tab
2. Select workflow (Reference Validation, Test Installation, Quality Gate)
3. View recent runs
4. Click run to see details
5. Click job to see logs

### View PR Check Status

**In PR:**
1. Scroll to **Checks** section
2. See all required/optional checks
3. Click details to see logs
4. Click artifact to download report

### Download Artifacts

**Via GitHub UI:**
1. Go to: **Actions** tab
2. Click workflow run
3. Scroll to artifacts section
4. Click to download

**Via GitHub CLI:**
```bash
# List artifacts
gh run list --workflow validate-references.yml

# Download artifact
gh run download <RUN_ID> -n validation-report
```

### Debug Locally

```bash
# Run validator with verbose output
./validate-references.sh --verbose

# Run tests with verbose output
VERBOSE=true bash test_validate_references.sh

# Simulate CI environment
bash validate-references.sh --report

# Check what the workflow would do
cat .github/workflows/validate-references.yml
```

---

## XI. Advanced Configuration

### Customize Triggers

**Edit:** `.github/workflows/validate-references.yml`

**Change which branches are checked:**
```yaml
on:
  push:
    branches:
      - master
      - develop
      - main
      - release/*  # Add release branches
```

**Change which file changes trigger validation:**
```yaml
on:
  push:
    paths:
      - '.claude/**'
      - 'CLAUDE.md'
      - 'install.sh'
      - 'validate-references.sh'
      - 'README.md'  # Add if docs changes matter
```

### Configure Retention

**Edit:** `.github/workflows/validate-references.yml`

**Change artifact retention:**
```yaml
- uses: actions/upload-artifact@v4
  with:
    retention-days: 60  # Keep for 2 months instead of 30
```

### Add Custom Checks

**Add to:** `.github/workflows/quality-gate.yml`

```yaml
- name: Custom check
  run: |
    # Your custom validation logic
    ./custom-validator.sh || exit 1
```

---

## XII. Troubleshooting

### Workflow Not Triggering

**Symptoms:** Changes pushed but workflow doesn't run

**Causes & Fixes:**
1. Check branch matches trigger pattern
   ```yaml
   branches:
     - master  # Is your branch here?
   ```

2. Check paths match what you changed
   ```yaml
   paths:
     - '.claude/**'  # Did you change this?
   ```

3. Verify workflow file is in correct location
   - Must be: `.github/workflows/validate-references.yml`
   - Not: `github/workflows/` or other location

4. Check if workflow is enabled
   - Actions tab → must not say "Disabled"

**Solution:** 
- Edit workflow file to match your needs
- Commit and push again

### Workflow Keeps Failing

**Symptoms:** Workflow fails on every push

**Debug:**
1. Download validation report artifact
2. Review error messages in detail
3. Run validator locally: `./validate-references.sh --report`
4. Fix issues, test locally, push again

**Common Issues:**
- Circular references (fix by removing one)
- Missing files (create or fix path)
- Invalid sections (use correct name)
- Syntax errors (fix YAML/Markdown)

### PR Cannot Merge Despite Checks Passing

**Symptoms:** Green checkmarks but merge blocked

**Causes:**
1. Branch not up to date with main
   - Solution: Update branch (`git pull origin main`)

2. Code review not completed
   - Solution: Get required reviews

3. Other branch protection rules
   - Solution: Check Settings → Branches

4. Stale approvals
   - Solution: Request re-review

---

## XIII. Performance & Costs

### GitHub Actions Usage

**Free Tier Includes:**
- 2,000 minutes/month on free accounts
- Unlimited for public repos
- Unlimited on Pro/Team plans

**Workflow Execution Times:**
- Reference Validation: ~30 seconds
- Test Installation (single OS): ~60 seconds
- Test Installation (matrix): ~180 seconds total
- Quality Gate: ~20 seconds

**Estimated Monthly Cost:**
- For typical project: $0 (within free tier)
- High-volume: Minimal (GitHub Actions is cheap)

### Optimization

**Already Implemented:**
- ✅ Paths filters (skip unnecessary runs)
- ✅ Conditional jobs (only run when needed)
- ✅ Artifact cleanup (30-day retention)
- ✅ Quick validation (40ms runtime)

**Further Optimization (Optional):**
- Cache validator across runs
- Skip validation for non-config PRs
- Parallel job execution

---

## XIV. Security Considerations

### Secrets & Access

**Current Setup:** No secrets required
- Validation uses only public code
- No credentials needed
- GitHub token used only for PR comments (safe)

**Best Practices:**
- ✅ No secrets in workflow files
- ✅ Read-only access for validation
- ✅ Comments only on PRs (not external)

### Code Safety

**Validation Workflow:**
- ✅ No `eval()` or `exec()`
- ✅ No external script execution
- ✅ File validation only
- ✅ No network calls

**PR Comments:**
- ✅ GitHub Actions supplied credentials only
- ✅ Limited to PR comments
- ✅ No external API calls

---

## XV. Integration with install.sh

### Local Validation (Before CI)

**In install.sh:**
```bash
# Validate references before installation
validate_configuration_references() {
    bash ./validate-references.sh --report || return 1
}

# Call in main installation flow
validate_configuration_references || exit 1
```

### Flags Supported

- `--verbose` — Detailed output
- `--report` — Full report
- `SKIP_VALIDATION=true` — Skip validation (env var)

---

## XVI. Success Metrics

### Implementation Complete ✅

- ✅ Reference Validation workflow created
- ✅ Installation Testing workflow created
- ✅ Quality Gate workflow created
- ✅ Branch protection rules documented
- ✅ Error handling guide provided
- ✅ Developer workflow documented
- ✅ Troubleshooting guide included

### Quality Standards ✅

- ✅ All workflows use latest actions
- ✅ Comprehensive error messages
- ✅ Artifact preservation (30 days)
- ✅ PR commenting for feedback
- ✅ Multi-platform testing
- ✅ No external dependencies
- ✅ Zero cost for public repos

---

## XVII. Next Steps

### Before Going Live

- [ ] Merge all workflow files to repository
- [ ] Configure branch protection in GitHub
- [ ] Test with first PR
- [ ] Verify all workflows trigger correctly
- [ ] Document any customizations

### After Going Live

- [ ] Monitor workflow execution
- [ ] Review PR feedback
- [ ] Adjust triggers if needed
- [ ] Optimize performance if needed
- [ ] Update team documentation

---

## Appendix A: Quick Reference

### Workflow Files
```
.github/workflows/
├── validate-references.yml     (Reference validation)
├── test-install.yml            (Installation tests)
└── quality-gate.yml            (Quality checks)
```

### Branch Protection Settings
```
Branch: master
Required Checks:
  ✓ Reference Validation / Validate @include References
  ✓ Quality Gate / Quality Gate Checks
Require Reviews: 1 minimum
Dismiss Stale Reviews: Yes
```

### Key Paths in Workflows
```yaml
# Config validation paths
paths:
  - '.claude/**'
  - 'CLAUDE.md'
  - 'install.sh'
  - 'validate-references.sh'

# Test validation paths
paths:
  - 'validate-references.sh'
  - 'test_validate_references.sh'
```

---

## Appendix B: Status Badges (Optional)

**Add to README.md:**

```markdown
# SuperClaude

[![Reference Validation](https://github.com/NomenAK/SuperClaude/workflows/Reference%20Validation/badge.svg)](https://github.com/NomenAK/SuperClaude/actions?query=workflow%3A%22Reference+Validation%22)
[![Test Installation](https://github.com/NomenAK/SuperClaude/workflows/Test%20Installation/badge.svg)](https://github.com/NomenAK/SuperClaude/actions?query=workflow%3A%22Test+Installation%22)
[![Quality Gate](https://github.com/NomenAK/SuperClaude/workflows/Quality%20Gate/badge.svg)](https://github.com/NomenAK/SuperClaude/actions?query=workflow%3A%22Quality+Gate%22)
```

---

**Task #3: CI/CD Integration Complete** ✅

Ready for deployment and team usage.
