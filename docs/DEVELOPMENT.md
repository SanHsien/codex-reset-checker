# 開發環境

維護者與 AI 接手用的開發文件。產品使用方式在 [`README.md`](../README.md)；上游同步在 [`UPSTREAM.md`](UPSTREAM.md)；決策在 [`DECISIONS.md`](DECISIONS.md)。

## 架構

```text
bin/
  └── codex-reset-checker.js   CLI 執行入口（Node.js 14+）
scripts/
  ├── check-codex-rate-limit.ps1 PowerShell 查詢輔助腳本
  └── check-codex-rate-limit.sh  Shell 查詢輔助腳本
test/
  └── codex-reset-checker.test.js 產品單元測試
tools/                         fork 維護工具（Windows gate、上游檢查、相對連結檢查）
  └── tests/                   維護契約測試
docs/                          fork 維護與治理文件
```

## 本機開發（Windows 11 原生）

### 維護骨架（必跑）

```powershell
python -m venv .venv
.venv\Scripts\python -m pip install --upgrade pip
.venv\Scripts\python -m pip install -r requirements-dev.txt
$env:PYTHONUTF8 = "1"
pwsh -NoProfile -File tools\dev_check.ps1
```

等價一鍵指令：

```powershell
pwsh -NoProfile -File tools\bootstrap_dev.ps1
```

### 執行產品測試

本 repo 提供專用 Windows 原生產品測試腳本 `tools/test_product.ps1`：

```powershell
pwsh -NoProfile -File tools\test_product.ps1
```

## Canonical Gate

`tools\dev_check.ps1` 會依序執行：

1. `python -m compileall`（`tools`）
2. `ruff check`（E9 + F，僅檢查 `tools`）
3. `pytest tools/tests`（使用獨立的 `tools/pytest.ini`）
4. `python tools/check_links.py`（驗證所有維護文件相對連結）
5. `node test/codex-reset-checker.test.js`（產品測試）

CI 專注於 Windows 原生環境，在 `windows-latest` 執行 Node.js 矩陣與 dev_check gate。推至 `main` 前請務必在本機跑過 gate。

## 不要做的事

- 不要提交含有個人憑證、API key 或敏感資訊的檔案（特別是 `auth.json`）。
- 不要把 PR 指向上游 `doggy8088/codex-reset-checker`。
