# 上游維護

## Remote

- Fork：`origin` → `https://github.com/SanHsien/codex-reset-checker.git`（預設分支 `main`）
- 原作者：`upstream` → `https://github.com/doggy8088/codex-reset-checker.git`（預設分支 `main`）
- 追蹤分支：`main`

## 檢查新提交

```powershell
git fetch upstream main
python tools\check_upstream_updates.py --strict
```

工具以 `tools/upstream_baseline.json` 的 `reviewed_through` 為起點，列出所有未審查提交、PR 與 Issues。
有新變更或檢查失敗時，`--strict` 回傳非零；排程 workflow 也會因此明確亮紅燈提醒。

CI 沒有 `upstream` remote，所以 baseline 的 `repo` 寫完整 clone URL，不要寫遠端短名。

## 審查清冊

每次只做一次批次審查：

1. 讀 commit 主旨與變更檔案（open PR 必須讀 diff，禁止只憑標題結案）。
2. 判斷是否與繁中 README、Windows gate、發佈閘門或測試衝突。
3. 可直接同步的提交用 merge；只需要部分修正時 cherry-pick 或最小重做。
4. 跑 `pwsh -NoProfile -File tools\dev_check.ps1`。
5. 在 `docs/DECISIONS.md` 記錄採用／略過理由。
6. 驗證完成後才把 baseline 推進到已審查的完整 40 字元 SHA 與更新 PR/Issue 水位。

Baseline 代表「已審查」，不代表「全部已合併」。

## 2026-09-12：fork 起點

本 fork 自上游 `main` `76dbb0b2ce3def7e9c5832135d1c84382ea2499c`
（`chore(release): 1.0.1`）建立。
此 SHA 設為第一個 `reviewed_through`（短 SHA 為 `76dbb0b`）。
之後的上游 commit 才需要進入審查清冊。

---

## 2026-09-12：上游 PR、Issue、分支全面盤點

2026-09-12 對 [`doggy8088/codex-reset-checker`](https://github.com/doggy8088/codex-reset-checker) 進行完整盤點：
**2 個分支、4 個歷史 PR、0 個 Issue**。
評估結論與盤點原則如下，記錄於本檔與 [`docs/DECISIONS.md`](DECISIONS.md)，避免未來重複評估。

### 一、上游分支盤點

上游 remote 有 `main` 與 `doggy8088-initialize-design-context`。
經比對 `doggy8088-initialize-design-context` 核心提交 `dfec056`（產品首頁）已於 2026-07-14 併入 `main`（提交 `49ab833`），僅差上游主動廢棄之 `.now.json`，無需且不重複引進。
本 fork 刪除 `origin/doggy8088-initialize-design-context`，**唯一長期跟隨分支為 `upstream/main`**。

### 二、上游 PR 盤點（共 4 筆）

| PR 編號 | 標題 | 狀態 | 本輪評估結論與理由 |
|---|---|---|---|
| `#1` | ci(pages): publish public folder with GitHub Actions | MERGED | **已在 main 包含**。Pages 發佈設定。 |
| `#2` | ci(pages): restrict publishing to public changes | MERGED | **已在 main 包含**。限制 Pages 發佈路徑。 |
| `#3` | fix(ci): publish releases only after version changes | MERGED | **已在 main 包含**。版本變更發佈控制。 |
| `#4` | feat(ics): 支援手動重置額度複選與 iCalendar 匯出 | CLOSED | **不予引進**。原作者關閉。該功能引入本機磁碟寫入與資料夾開啟，違反本專案「唯讀查詢、不修改任何本機檔案」之核心安全政策，且 base 停留於 0.6.x 舊版，決定不引進。 |

當前無任何待處理之 Open PR。

### 三、上游 Issue 盤點（共 0 筆）

上游目前無任何 Issues。

### 四、防重複評估機制（Watermark 機制）

為避免每次巡檢重複評估既有項目，本專案實施嚴格的水位線（Watermark）機制：

1. **基準水位鎖定**：
   - Commit 水位：`76dbb0b2ce3def7e9c5832135d1c84382ea2499c`（短 SHA `76dbb0b`）
   - PR 水位：`4`
   - Issue 水位：`0`
   - 記錄於 [`tools/upstream_baseline.json`](../tools/upstream_baseline.json)。

2. **增量巡檢機制**：
   - 每次執行 `tools/check_upstream_updates.py` 或 GitHub Actions 每週排程時，檢查器會自動過濾 `number <= watermark` 的項目。
   - 只有編號大於 **#4** 的新開 PR / Issue，或 `main` 上高於 `76dbb0b` 的新 Commit，才會出現在待審報告中。
   - 當新項目被審查完畢並於 `docs/DECISIONS.md` 記錄結論後，再遞增更新 baseline 水位。
