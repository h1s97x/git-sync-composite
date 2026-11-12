#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC="$ROOT/sync.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

export HOME="$WORK/home"
mkdir -p "$HOME"

commit() {
  git -c commit.gpgsign=false -c user.name=test -c user.email=test@example.com commit "$@"
}

git init -q --bare "$WORK/origin.git"
git init -q "$WORK/seed"
cd "$WORK/seed"
echo one > file.txt
git add file.txt
commit -qm init
git branch -M main
git tag v1.0.0
git remote add origin "$WORK/origin.git"
git push -q origin main --tags
git checkout -qb feature
echo two >> file.txt
commit -qam feature
git push -q origin feature
cd "$WORK"

prepare_workspace() {
  cd "$WORK"
  rm -rf "$WORK/work" "$WORK/target.git"
  git init -q "$WORK/work"
  git init -q --bare "$WORK/target.git"
  cd "$WORK/work"
  git remote add origin "$WORK/origin.git"
  git fetch -q origin main
  git checkout -q -b main FETCH_HEAD
}

branches() {
  git --git-dir="$WORK/target.git" for-each-ref --format='%(refname:short)' refs/heads/ | sort | tr '\n' ' '
}

prepare_workspace
if ! GITHUB_ACTIONS=true PLUGIN_TARGET_URL="$WORK/target.git" PLUGIN_USERNAME=test PLUGIN_PASSWORD=dummy PLUGIN_PUSH_TAGS=true bash "$SYNC" > "$WORK/log1" 2>&1; then
  cat "$WORK/log1"
  exit 1
fi
[[ "$(branches)" == "feature main " ]] || { echo "FAIL: all branches -> $(branches)"; exit 1; }
[[ -n "$(git --git-dir="$WORK/target.git" tag -l v1.0.0)" ]] || { echo "FAIL: tags"; exit 1; }
echo "PASS: full mirror (branches + tags)"

prepare_workspace
if ! GITHUB_ACTIONS=true PLUGIN_TARGET_URL="$WORK/target.git" PLUGIN_USERNAME=test PLUGIN_PASSWORD=dummy PLUGIN_BRANCH=main bash "$SYNC" > "$WORK/log2" 2>&1; then
  cat "$WORK/log2"
  exit 1
fi
[[ "$(branches)" == "main " ]] || { echo "FAIL: single branch -> $(branches)"; exit 1; }
echo "PASS: single branch"

prepare_workspace
if GITHUB_ACTIONS=true PLUGIN_TARGET_URL="$WORK/target.git" PLUGIN_USERNAME=test PLUGIN_PASSWORD=dummy PLUGIN_FORCE=yes bash "$SYNC" > "$WORK/log3" 2>&1; then
  echo "FAIL: invalid force was accepted"
  exit 1
fi
echo "PASS: invalid force rejected"

prepare_workspace
if GITHUB_ACTIONS=true PLUGIN_TARGET_URL="$WORK/target.git" PLUGIN_USERNAME=test PLUGIN_PASSWORD=dummy PLUGIN_SYNC_MODE=rebase bash "$SYNC" > "$WORK/log4" 2>&1; then
  echo "FAIL: rebase mode was accepted"
  exit 1
fi
echo "PASS: unsupported mode rejected"

echo "All composite tests passed"
