#!/bin/bash

# GitHub Branch Protection Setup Script
# Configures branch protection rules for reference validation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
OWNER="${1:-}"
REPO="${2:-}"
BRANCH="${3:-master}"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

# ============================================================================
# VALIDATION
# ============================================================================

check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) not found"
        echo "Install from: https://cli.github.com/"
        exit 1
    fi
    log_success "GitHub CLI found"
}

check_authentication() {
    if ! gh auth status &> /dev/null; then
        log_error "Not authenticated with GitHub"
        echo "Run: gh auth login"
        exit 1
    fi
    log_success "GitHub authentication verified"
}

validate_repository() {
    local owner="$1"
    local repo="$2"

    if ! gh repo view "${owner}/${repo}" &> /dev/null; then
        log_error "Repository not found: ${owner}/${repo}"
        exit 1
    fi
    log_success "Repository found: ${owner}/${repo}"
}

# ============================================================================
# BRANCH PROTECTION SETUP
# ============================================================================

setup_branch_protection() {
    local owner="$1"
    local repo="$2"
    local branch="$3"

    echo ""
    echo -e "${BLUE}Configuring branch protection for ${branch}...${NC}"
    echo ""

    # Create protection rule
    gh api \
        --method PUT \
        "repos/${owner}/${repo}/branches/${branch}/protection" \
        -f required_status_checks='{"strict": true, "contexts": ["Reference Validation / Validate @include References", "Quality Gate / Quality Gate Checks"]}' \
        -f enforce_admins=true \
        -f required_pull_request_reviews='{"dismiss_stale_reviews": true, "require_code_owner_reviews": false, "required_approving_review_count": 1}' \
        -f allow_force_pushes=false \
        -f allow_deletions=false \
        -f required_linear_history=false \
        -f restrictions=null

    if [ $? -eq 0 ]; then
        log_success "Branch protection configured for ${branch}"
    else
        log_error "Failed to configure branch protection"
        exit 1
    fi
}

# ============================================================================
# VERIFICATION
# ============================================================================

verify_branch_protection() {
    local owner="$1"
    local repo="$2"
    local branch="$3"

    echo ""
    echo -e "${BLUE}Verifying branch protection...${NC}"
    echo ""

    local protection=$(gh api "repos/${owner}/${repo}/branches/${branch}/protection")

    # Check required status checks
    if echo "$protection" | jq -e '.required_status_checks.contexts[] | select(. == "Reference Validation / Validate @include References")' &> /dev/null; then
        log_success "Reference Validation check required"
    else
        log_warning "Reference Validation check not found"
    fi

    if echo "$protection" | jq -e '.required_status_checks.contexts[] | select(. == "Quality Gate / Quality Gate Checks")' &> /dev/null; then
        log_success "Quality Gate check required"
    else
        log_warning "Quality Gate check not found"
    fi

    # Check PR requirements
    if echo "$protection" | jq -e '.required_pull_request_reviews.required_approving_review_count >= 1' &> /dev/null; then
        log_success "PR reviews required"
    fi

    # Check other settings
    if echo "$protection" | jq -e '.allow_force_pushes == false' &> /dev/null; then
        log_success "Force pushes disabled"
    fi

    if echo "$protection" | jq -e '.allow_deletions == false' &> /dev/null; then
        log_success "Deletion disabled"
    fi

    echo ""
    log_success "Branch protection verified"
}

# ============================================================================
# MAIN
# ============================================================================

show_usage() {
    cat << 'EOF'
GitHub Branch Protection Setup

Usage: ./setup-branch-protection.sh <OWNER> <REPO> [BRANCH]

Arguments:
  OWNER      GitHub username or organization (e.g., NomenAK)
  REPO       Repository name (e.g., SuperClaude)
  BRANCH     Branch to protect (default: master)

Examples:
  ./setup-branch-protection.sh NomenAK SuperClaude
  ./setup-branch-protection.sh NomenAK SuperClaude main
  ./setup-branch-protection.sh NomenAK SuperClaude develop

Prerequisites:
  - GitHub CLI installed (gh)
  - Authenticated with GitHub (gh auth login)
  - Admin access to repository

Requirements:
  - jq (for JSON parsing)
  - GitHub repository with reference validation workflows
EOF
}

main() {
    echo ""
    echo -e "${BLUE}=== GitHub Branch Protection Setup ===${NC}"
    echo ""

    # Validation
    if [[ -z "$OWNER" ]] || [[ -z "$REPO" ]]; then
        show_usage
        exit 1
    fi

    # Check prerequisites
    check_gh_cli
    check_authentication

    # Verify repository
    validate_repository "$OWNER" "$REPO"

    # Setup branch protection
    setup_branch_protection "$OWNER" "$REPO" "$BRANCH"

    # Verify setup
    verify_branch_protection "$OWNER" "$REPO" "$BRANCH"

    echo ""
    echo -e "${GREEN}✓ Branch protection setup complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Visit: https://github.com/${OWNER}/${REPO}/settings/branches"
    echo "2. Verify protection rules are configured"
    echo "3. Create a test PR to verify workflows run"
    echo ""
}

main "$@"
