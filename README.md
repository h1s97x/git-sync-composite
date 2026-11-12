# Git Sync (Composite)

一个轻量的 Git 仓库镜像 Action：直接在 GitHub Actions runner 上执行 git 命令完成同步，无需构建或拉取 Docker 镜像，启动快、改完打 tag 即生效。

本项目由 `h1s97x` 独立维护，采用 MIT 协议发布。

## 功能特点

- 只依赖 runner 自带的 git / git-lfs，没有镜像构建与分发环节
- HTTPS 认证，凭据按目标域名注入、不落盘
- 全分支与标签镜像，或只同步指定分支
- 支持强制推送、Git LFS
- 所有 git 配置通过环境变量注入，不修改 runner 全局配置
- 自带离线回归测试

## 快速开始

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
    if: github.actor != 'git-sync-bot'   # 避免与反向同步形成循环
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

把示例中的目标仓库地址和账号换成你自己的。`dependabot` 创建的分支还需要配置 [Dependabot Secrets](https://docs.github.com/en/code-security/dependabot/troubleshooting-dependabot/troubleshooting-dependabot-on-github-actions#accessing-secrets)。

发布到 Marketplace：推送 `v1` 这类版本 tag，创建 Release 时勾选 "Publish to GitHub Marketplace"（`action.yml` 位于仓库根目录，已满足要求）。

## 参数说明

| 参数名 | 必填 | 默认值 | 说明 |
| --- | --- | --- | --- |
| target_url | 是 | - | 目标仓库 URL，HTTPS 目标须使用 `https://` 格式 |
| username | 否* | - | HTTPS 认证用户名（*HTTPS 目标必填） |
| password | 否* | - | 密码或访问令牌，务必使用 CI Secret（*HTTPS 目标必填） |
| branch | 否 | - | 指定后只推这个分支 |
| force | 否 | false | 强制推送，只接受 `true` / `false` |
| push_tags | 否 | false | 是否推送标签 |
| fetch_options | 否 | - | 传给 `git fetch` 的额外选项 |
| git_user | 否 | Git Sync | 提交者名 |
| git_email | 否 | git-sync@users.noreply.github.com | 提交者邮箱 |

## 实现要点

- `actions/checkout` 默认只取触发分支，脚本先执行 `git fetch origin --prune '+refs/heads/*:refs/remotes/origin/*'`，再以 `refs/remotes/origin/*:refs/heads/*` 推送，保证全分支镜像生效。
- 凭据经 Base64 编码后注入 `http.https://<host>/.extraheader`，按域名限定作用域，不会发送给 `origin`；配合 `::add-mask::` 脱敏。
- 所有 git 配置走 `GIT_CONFIG_*` 环境变量，不写 `~/.gitconfig`。
- 未知 `sync_mode`、非布尔参数、找不到的分支都以非零状态退出，不会静默「假成功」。

## 本地测试

```bash
bash test.sh
```

无需 Docker 与网络。测试用临时裸仓库模拟单分支 checkout 场景，覆盖全分支与标签镜像、指定分支、非法参数拒绝。

## 限制

- 仅支持 HTTPS 认证的 `push` 模式，本仓库不实现 SSH、`rebase`、`pull`
- 需要 `bash`，建议使用 Linux runner
- 依赖 runner 预装的 git / git-lfs 版本

## License

[MIT License](LICENSE) — 保留原始版权声明，并追加本项目维护者 `h1s97x` 的版权声明。
