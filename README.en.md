# Git Sync (Composite)

A lightweight Git repository mirroring Action. It runs git commands directly on the GitHub Actions runner, with no Docker image to build or pull: fast startup, and a new tag takes effect immediately.

Maintained independently by `h1s97x` and released under the MIT License.

## Features

- Only depends on the runner's git / git-lfs; no image build or distribution
- HTTPS auth with host-scoped credentials that are never written to disk
- Mirror all branches and tags, or a single branch
- Force push and Git LFS support
- All git config injected through environment variables; the runner's global config stays untouched
- Self-contained offline regression tests

## Quick Start

```yaml
# .github/workflows/git-sync.yml
name: Mirror Repository
on:
  push:
    branches: ['**']
    tags: ['**']
  workflow_dispatch:

concurrency:
  group: git-sync
  cancel-in-progress: false

jobs:
  sync:
    if: github.actor != 'git-sync-bot'   # avoid a loop with a reverse sync
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: h1s97x/git-sync-composite@v1
        with:
          target_url: https://git.example.com/<org>/<repo>.git
          username: <your-username>
          password: ${{ secrets.GIT_SYNC_TOKEN }}
          push_tags: 'true'
```

Replace the target repository URL and account with your own. Branches created by `dependabot` additionally need [Dependabot Secrets](https://docs.github.com/en/code-security/dependabot/troubleshooting-dependabot/troubleshooting-dependabot-on-github-actions#accessing-secrets).

To publish on the Marketplace, push a version tag such as `v1` and check "Publish to GitHub Marketplace" when creating the Release (`action.yml` is already at the repository root).

## Parameters

| Parameter | Required | Default | Description |
| --- | --- | --- | --- |
| target_url | Yes | - | Target repository URL; HTTPS targets must use `https://` |
| username | No* | - | Username for HTTPS auth (*required for HTTPS targets) |
| password | No* | - | Password or access token, always pass a CI secret (*required for HTTPS targets) |
| branch | No | - | Push only this branch |
| force | No | false | Force push, accepts `true` / `false` only |
| push_tags | No | false | Push tags |
| fetch_options | No | - | Extra options for `git fetch` |
| git_user | No | Git Sync | Git committer name |
| git_email | No | git-sync@users.noreply.github.com | Git committer email |

## How It Works

- `actions/checkout` only fetches the triggering branch, so the script first runs `git fetch origin --prune '+refs/heads/*:refs/remotes/origin/*'` and then pushes with `refs/remotes/origin/*:refs/heads/*` to mirror every branch.
- Credentials are Base64-encoded into `http.https://<host>/.extraheader`, scoped by host so they are never sent to `origin`, and masked with `::add-mask::`.
- All git config comes from `GIT_CONFIG_*` environment variables; `~/.gitconfig` is never written.
- Unknown `sync_mode`, non-boolean flags, and missing branches all exit non-zero instead of failing silently.

## Local Tests

```bash
bash test.sh
```

No Docker or network required. The suite builds temporary bare repositories to emulate a single-branch checkout and covers full branch/tag mirroring, single-branch sync, and rejection of invalid arguments.

## Limitations

- HTTPS `push` mode only; SSH, `rebase`, and `pull` are not implemented in this repository
- Requires `bash`; Linux runners are recommended
- Depends on the git / git-lfs versions preinstalled on the runner

## License

[MIT License](LICENSE) — the original copyright notice is retained, with `h1s97x`'s copyright added as the maintainer.
