#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "::error::$*" >&2
  exit 1
}

USERNAME="${PLUGIN_USERNAME:-}"
BRANCH="${PLUGIN_BRANCH:-}"
FORCE="${PLUGIN_FORCE:-false}"
PUSH_TAGS="${PLUGIN_PUSH_TAGS:-false}"
FETCH_OPTIONS="${PLUGIN_FETCH_OPTIONS:-}"
GIT_USER="${PLUGIN_GIT_USER:-Git Sync}"
GIT_EMAIL="${PLUGIN_GIT_EMAIL:-git-sync@users.noreply.github.com}"
MODE="${PLUGIN_SYNC_MODE:-push}"
AUTH_TYPE="${PLUGIN_AUTH_TYPE:-https}"
TARGET_URL="${PLUGIN_TARGET_URL:-}"

[[ -n "$TARGET_URL" ]] || fail "target_url is required"
[[ "$MODE" == "push" ]] || fail "composite action supports sync_mode=push only; use the Docker action for rebase/pull"
[[ "$AUTH_TYPE" == "https" ]] || fail "composite action supports https auth only; use the Docker action for ssh"
case "$FORCE" in true|false) ;; *) fail "force must be true or false" ;; esac
case "$PUSH_TAGS" in true|false) ;; *) fail "push_tags must be true or false" ;; esac

config_add() {
  local key="$1" value="$2" idx="$GIT_CONFIG_COUNT"
  export "GIT_CONFIG_KEY_${idx}=$key"
  export "GIT_CONFIG_VALUE_${idx}=$value"
  GIT_CONFIG_COUNT=$((idx + 1))
  export GIT_CONFIG_COUNT
}

GIT_CONFIG_COUNT=0
export GIT_CONFIG_COUNT
config_add "user.name" "$GIT_USER"
config_add "user.email" "$GIT_EMAIL"
config_add "safe.directory" "$(pwd)"

if [[ "$TARGET_URL" =~ ^https://([^/]+)/(.+)$ ]]; then
  PASSWORD="${PLUGIN_PASSWORD:-}"
  [[ -n "$USERNAME" && -n "$PASSWORD" ]] || fail "username and password are required for HTTPS targets"
  HOST="${BASH_REMATCH[1]}"
  echo "::add-mask::${PASSWORD}"
  AUTH="$(printf '%s:%s' "$USERNAME" "$PASSWORD" | base64 | tr -d '\n')"
  echo "::add-mask::${AUTH}"
  config_add "http.https://${HOST}/.extraheader" "AUTHORIZATION: basic ${AUTH}"
else
  echo "::notice::Non-HTTPS target: no credentials injected; the runner must already have access"
fi

git remote add target "$TARGET_URL" 2>/dev/null || git remote set-url target "$TARGET_URL"

echo "Fetching all branches from origin..."
git fetch origin --prune ${FETCH_OPTIONS} '+refs/heads/*:refs/remotes/origin/*'
git update-ref -d refs/remotes/origin/HEAD 2>/dev/null || true

if [[ "$PUSH_TAGS" == "true" ]]; then
  git fetch origin --tags --force ${FETCH_OPTIONS} || fail "failed to fetch tags from origin"
fi

if git lfs version >/dev/null 2>&1 && [[ -n "$(git lfs ls-files 2>/dev/null)" ]]; then
  HAS_LFS=1
else
  HAS_LFS=0
fi

FORCE_ARGS=()
if [[ "$FORCE" == "true" ]]; then
  FORCE_ARGS+=(--force)
fi

if [[ -n "$BRANCH" ]]; then
  if git rev-parse --verify "refs/remotes/origin/$BRANCH" >/dev/null 2>&1; then
    SOURCE_REF="refs/remotes/origin/${BRANCH}:refs/heads/${BRANCH}"
  elif git rev-parse --verify "refs/heads/$BRANCH" >/dev/null 2>&1; then
    SOURCE_REF="refs/heads/$BRANCH"
  else
    fail "branch $BRANCH not found on origin"
  fi
  git push "${FORCE_ARGS[@]}" target "$SOURCE_REF"
else
  git push "${FORCE_ARGS[@]}" target 'refs/remotes/origin/*:refs/heads/*'
fi

if [[ "$HAS_LFS" == "1" ]]; then
  git lfs push target --all || echo "::warning::failed to push LFS objects"
fi

if [[ "$PUSH_TAGS" == "true" ]]; then
  git push "${FORCE_ARGS[@]}" target --tags
fi

echo "Sync completed"
