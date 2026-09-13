# CLAUDE.md

請先完整閱讀並遵守 [`AGENTS.md`](AGENTS.md)。本檔只補充 Claude Code 的最小入口：

- 這是保留上游歷史的 fork；不要移除 `upstream`、原作者 Will 保哥或 MIT License 授權標示。
- 核心程式在 `bin/` 與 `scripts/`，測試在 `test/`，以上游為準。
- 提交前跑 `pwsh -NoProfile -File tools\dev_check.ps1`。
- 測試檔案、使用者專有文件、`auth.json`、`.env` 一律不可提交。
- 使用繁體中文，直接交付可驗證結果，避免冗長背景鋪陳。
- PR、push、release 一律指向 `SanHsien/codex-reset-checker`，嚴禁未經當次許可打向 `doggy8088/codex-reset-checker`。
