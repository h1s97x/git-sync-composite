# TODO

> 记录 `v0.0.1` 之后的待办事项。当前版本是 Pre-release，尚未正式发布。

## 上线前必做

- [ ] **Marketplace 上架**：在 GitHub 的 Release 编辑页勾选 "Publish to GitHub Marketplace"（Release API 不支持该选项）。等功能验证完成再发正式版。
- [ ] **配置 GitHub Secret**：在仓库 Settings → Secrets 添加 `GIT_SYNC_TOKEN`（对目标仓库有写权限）。
- [ ] **真机端到端验证**：`test.sh` 只覆盖本地路径 target（不注入凭据的分支），需跑一次真实 HTTPS workflow，逐项确认
  - `http.https://<host>/.extraheader` 凭据注入生效，且凭据不会发送给 `origin`；
  - `::add-mask::` 日志脱敏生效；
  - runner 自带 `git-lfs` 可用，LFS 对象推送正常；
  - `GIT_CONFIG_*` 环境变量注入在真实 runner 上生效，不污染全局配置。

## 工程化

- [ ] 把 `test.sh` 接进 CI workflow（不依赖 Secret 即可运行），让每次 push 自动执行四个用例。
- [ ] 引入 `shellcheck` 并清理告警。
- [ ] 补 Windows runner / bash 兼容性验证，或明确只支持 Linux runner（文档已写明）。
- [ ] 补一次 `action.yml` 的完整 YAML 解析验证（本地环境没有 YAML 解析器，此前只做过文本结构检查）。

## 版本演进

- [ ] 0.x 阶段保持精确版本引用（`@v0.0.1`），不建浮动 `v0` / `v1` tag；稳定到 `1.0.0` 后再考虑浮动的 `v1`。
- [ ] 每次发版同步更新 2 处 `uses:` 示例与 2 处发布说明中的版本号（中英文 README）。
- [ ] 若后续要支持 SSH / `rebase` / `pull`，先评估是否仍保持「无镜像」的轻量定位。

## 运维

- [ ] 确认 GitHub PAT 与 CNB 临时令牌已全部撤销。
- [ ] 全局 `credential.helper` 仍指向已删除的凭据文件，本地后续推送需重新配置 PAT / SSH。
