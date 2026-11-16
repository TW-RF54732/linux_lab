# 文件網站原始檔

`scripts/build-site.mjs` 把這個目錄轉成 `dist/` 的靜態網站。只需要 Node.js 20 以上，不用 `npm install`。

```bash
node scripts/build-site.mjs        # 建置
npm run preview:site               # 建置並在 http://127.0.0.1:4173 預覽
```

建置時會檢查所有站內連結與 `#錨點`，連到不存在的頁面或章節會直接失敗。

## 檔案

| 路徑 | 用途 |
| --- | --- |
| `site.json` | 網站標題、側欄分類與頁面順序（上一頁／下一頁也照這個順序） |
| `template.html` | 每一頁的版型 |
| `styles.css`、`docs.js`、`favicon.svg` | 樣式、複製按鈕、圖示 |
| `content/**/*.md` | 頁面內容。`content/commands/ls.md` 會變成 `/commands/ls/`；`index.md` 變成目錄本身 |

新增頁面：建立 `.md` 檔，再把它的路徑（不含 `.md`）加到 `site.json` 某個分類的 `pages`。

## frontmatter

```yaml
---
title: ls                 # 頁面大標題（必要）
nav: ls                   # 側欄顯示的名稱（選填，預設同 title）
summary: 列出目錄內容       # 首頁索引的簡短說明（選填）
description: ...          # 標題下方的說明與 <meta description>（必要）
---
```

## 頁面結構

每頁都照同一個順序，先讓新手能用，再補充：

1. `## 常用 {#basics}`：一個最常用的指令區塊 + 常用寫法表格。
2. `## 進階 {#advanced}`：之後可能用到的選項，一張表格就好。
3. `## 範例 {#examples}`：課堂上的實際用法與幾個組合。
4. （選填）`## 常見錯誤 {#errors}`：只放新手真的會遇到的。

不求完整，完整的選項請學員自己 `指令 --help` 或 `man 指令`。

## 支援的 Markdown

| 寫法 | 說明 |
| --- | --- |
| `## 標題 {#id}` | 章節，`{#id}` 必填，會出現在「本頁內容」 |
| `### 標題 {#id}` | 小節，`{#id}` 選填 |
| ` ```command ` | 可執行的指令，有複製按鈕 |
| ` ```output `、` ```config `、` ```reference ` | 輸出、設定檔、語法參考，沒有複製按鈕 |
| `\| a \| b \|` | 表格，第二列必須是分隔列。儲存格內要顯示 `\|` 時寫 `\|` |
| `> [!NOTE]`、`> [!WARNING]`、`> [!TIP]` | 提示框 |
| `- `、`1. ` | 清單（不支援巢狀） |
| `` `code` ``、`**粗體**`、`[文字](/commands/ls/#options)` | 行內語法。站內連結用 `/` 開頭，建置時會轉成相對路徑 |
| `[[Ctrl+O]]` | 鍵盤按鍵 |
| `{lab}`、`{lab:2}` | 「課程用到」／「第 2 段」標籤 |
| `{{index}}` | 單獨一行，插入全站分類索引 |
