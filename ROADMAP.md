# 路線圖

> 本 repo 後續工作的單一真相源。做完一項，就在同一個 commit 刪掉那一列；新工作只加在這裡。
> 現況段的數字是 2026-10-30 依 `main` `ce41af4` 查的快照，開工前先重查 GitHub。

## 現況
這是 Windows 原生 Codex 額度查詢與手動重置工具的維護 fork，預設僅查詢（[README.md:34](README.md)）。2026-10-30 `gh` 查詢記錄 CI、CodeQL 最近結果成功，安全開啟告警為 0；Publish GitHub Pages 最近一次（2026-10-17）失敗已查明為遠端 repo 尚未啟用 GitHub Pages 站點設定（404 Not Found），非流程或程式缺陷，交由維護者決定是否啟用；issues 停用而未查到 issue（2026-10-30 `gh` 查詢）。最新 release 為 v1.1.1，後續系統匣、安裝及錯誤視窗修正仍在 Unreleased（[CHANGELOG.md:3](CHANGELOG.md)）。

## 近期：可以直接動手
| 項目 | 為什麼 | 驗收方式 | 建議執行者 | 證據 |
| --- | --- | --- | --- | --- |
| 決定 GitHub Pages 要啟用還是移除 workflow | `Publish GitHub Pages` 最近一次 run 39045986830（2026-10-17）在 `actions/configure-pages@v5` 失敗：repo 未在 Settings 啟用 Pages（`gh api repos/SanHsien/codex-reset-checker/pages` 回 404）；repo 為 public，不是方案限制，也不是流程缺陷。不處理的話，下一次符合 paths 條件的 push 還會再紅 | 二擇一：在 Settings → Pages 把 Source 設為 GitHub Actions，然後重跑該 workflow 轉綠；或刪掉 `.github/workflows/pages.yml`，並同步移除 README／文件中對站點的引用 | 維護者 | `gh run view 39045986830 --log-failed`；[.github/workflows/pages.yml:1](.github/workflows/pages.yml) |
| 核對修正後的 Windows 安裝與移除路徑 | 深掃只測純函式與解析，未跑真實安裝／解除安裝 | 隔離使用者環境驗證單項 PATH 不黏連、系統匣讀取摘要、無 pwsh 可回退、查詢失敗保留視窗；移除後捷徑及安裝檔清乾淨且保留其他 PATH | 維護者 | [REVIEW.md:26](REVIEW.md)、[CHANGELOG.md:7](CHANGELOG.md)；深掃報告（2026-10-27）「範圍」 |

## 中期：等條件成立再做
| 項目 | 觸發條件 | 驗收方式 | 建議執行者 | 證據 |
| --- | --- | --- | --- | --- |
| 發布包含 Windows 修正的執行檔 | 安裝與產品驗收通過，維護者授權發行 | 更新版本及 Scoop 所需資訊；重建執行檔並核對來源與雜湊，tag、Release、可下載資產一致，下載版 smoke 通過 | Codex | [AGENTS.md:78](AGENTS.md)、[CHANGELOG.md:3](CHANGELOG.md)、[tools/build_exe.ps1:50](tools/build_exe.ps1) |
| 收緊建置成功判斷 | 準備發布新版，或確認不再允許沿用舊執行檔 | 以編譯失敗／舊 exe 存在與 postject 非零案例驗證；失敗不可把舊產物標成本次成功，正常產物能執行 `--version` | Codex | [tools/build_exe.ps1:78](tools/build_exe.ps1)、[tools/build_exe.ps1:85](tools/build_exe.ps1)；深掃報告（2026-10-27）的既有取捨 |
| 重審 Ruff 延後版本 | freshness 顯示超過已審精度的新版本 | 用新版本跑 `ruff check --select E9,F tools` 與維護測試；保持下限的相容承諾，採用或續延附理由 | Codex | [docs/DECISIONS.md:52](docs/DECISIONS.md) |

## 刻意不做
| 不做什麼 | 理由 | 什麼情況下重新考慮 |
| --- | --- | --- |
| 用真帳戶執行 reset 當 smoke | reset 會消耗可用額度，查詢驗收不需要它；見 [README.md:34](README.md) | 維護者明確要求測試消耗額度的行為 |
| 引進舊 iCalendar 寫入功能 | 決策與產品邊界見 [docs/DECISIONS.md:27](docs/DECISIONS.md) | 維護者提出新的匯出需求與本機寫入規格 |

## 維護方式
每週依 [tools/upstream_baseline.json](tools/upstream_baseline.json) 審新增差量；歷史無共同祖先時用 cherry-pick 或最小重做，不改寫歷史。每月沿用 freshness 與 Dependabot 維護依賴；發行時除了 [AGENTS.md](AGENTS.md) 的 gate，必須核對下載產物及安裝路徑，理由記 [docs/DECISIONS.md](docs/DECISIONS.md)。
