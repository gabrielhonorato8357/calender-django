#!/usr/bin/env bash
# =============================================================================
# rewrite-git-history.sh
#
# Rewrites ALL commits across ALL branches and tags, replacing every
# author and committer name/email with the values you set below.
#
# Automatically tracks all remote branches as local branches before
# rewriting, so no manual checkout is needed.
#
# Usage:
#   chmod +x rewrite-git-history.sh
#   ./rewrite-git-history.sh
#
# WARNING: This rewrites history. All collaborators must re-clone or rebase
#          after you force-push. Back up the repo before running.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# CONFIGURE THESE TWO VALUES
# ---------------------------------------------------------------------------
NEW_NAME="gabrielhonorato8357"
NEW_EMAIL="gabrielhonorato8357@gmail.com"

# Optional: path to your repo. Leave empty to use the current directory.
REPO_PATH=""
# ---------------------------------------------------------------------------

# ---- helpers ---------------------------------------------------------------
info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }
error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; }

# ---- sanity checks ---------------------------------------------------------
if [[ -n "$REPO_PATH" ]]; then
  cd "$REPO_PATH"
fi

if ! git rev-parse --git-dir &>/dev/null; then
  error "Not inside a git repository. Set REPO_PATH or cd into your repo."
  exit 1
fi

info "Repository : $(git rev-parse --show-toplevel 2>/dev/null || pwd)"
info "New name   : $NEW_NAME"
info "New email  : $NEW_EMAIL"
echo

# ---- confirmation ----------------------------------------------------------
warn "This will REWRITE HISTORY for every commit on every branch and tag."
warn "Every author and committer will be replaced with the values above."
warn "Make sure you have a backup before proceeding."
read -rp "Type YES to continue: " CONFIRM
if [[ "$CONFIRM" != "YES" ]]; then
  info "Aborted."
  exit 0
fi

# ---- fetch all remote branches as local branches ---------------------------
info "Fetching all remote branches and tracking them locally..."

git fetch --all

# Loop every remote tracking branch and create a local branch for it
# e.g. remotes/origin/solution-rosty-git -> local branch solution-rosty-git
for REMOTE_BRANCH in $(git branch -r | grep -v '\->' | grep -v 'HEAD'); do
  # Strip "origin/" prefix to get the local branch name
  LOCAL_BRANCH="${REMOTE_BRANCH#*/}"

  if git show-ref --verify --quiet "refs/heads/$LOCAL_BRANCH"; then
    info "  Already local: $LOCAL_BRANCH"
  else
    info "  Tracking: $LOCAL_BRANCH"
    git branch --track "$LOCAL_BRANCH" "$REMOTE_BRANCH"
  fi
done

echo
info "Local branches now:"
git branch

# ---- export vars for the filter sub-shell ----------------------------------
export NEW_NAME NEW_EMAIL

# ---- rewrite ---------------------------------------------------------------
echo
info "Running git filter-branch on ALL branches and tags..."

git filter-branch -f --env-filter "
  export GIT_AUTHOR_NAME='$NEW_NAME'
  export GIT_AUTHOR_EMAIL='$NEW_EMAIL'
  export GIT_COMMITTER_NAME='$NEW_NAME'
  export GIT_COMMITTER_EMAIL='$NEW_EMAIL'
" --tag-name-filter cat -- --branches --tags

info "Rewrite complete."

# ---- verify (sample) -------------------------------------------------------
echo
info "Sample of rewritten commits (last 10 across all refs):"
git log --all --format="%h  %an <%ae>  %s" | head -10

# ---- push ------------------------------------------------------------------
echo
if git remote 2>/dev/null | grep -q .; then
  warn "You must force-push to update the remote."
  echo
  echo "  git push --force --all origin"
  echo "  git push --force --tags origin"
  echo
  read -rp "Force-push all branches and tags to origin now? [y/N]: " PUSH_NOW
  if [[ "$PUSH_NOW" =~ ^[Yy]$ ]]; then
    info "Force-pushing all branches..."
    git push --force --all origin
    info "Force-pushing all tags..."
    git push --force --tags origin
    info "Done."
  else
    info "Skipped. Run the commands above manually when ready."
  fi
else
  info "No remotes configured — nothing to push."
fi

info "All done!"