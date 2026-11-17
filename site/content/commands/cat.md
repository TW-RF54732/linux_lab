---
title: cat
summary: 印出檔案內容
description: 把檔案內容一次全部印在畫面上。適合小檔案；大檔案用 less 或 tail。
---

## 常用 {#basics}

```command
cat config.json
```

| 寫法 | 做什麼 |
| --- | --- |
| `cat 檔案` | 印出檔案內容 |
| `cat 檔案1 檔案2` | 依序印出多個檔案 |
| `cat -n 檔案` | 加上行號 |

> [!WARNING]
> `cat` 不會分頁，幾千行的檔案會瞬間洗掉畫面。大檔案用 [less](/commands/less/) 翻頁，或用 [tail](/commands/tail/) 只看結尾。不小心洗版時按 [[Ctrl+C]] 中斷、`clear` 清畫面。

## 進階 {#advanced}

| 選項 | 做什麼 |
| --- | --- |
| `-A` | 顯示看不見的字元：行尾 `$`、tab `^I`、Windows 換行 `^M` |
| `-s` | 連續空白行只顯示一行 |
| `-b` | 只替非空白行加行號 |

## 範例 {#examples}

```command
cat ~/.config/app/config.json
cat -n config.json
cat ~/id_ed25519.pub >> ~/.ssh/authorized_keys
```

1. 看設定檔目前的內容。
2. 加行號，對照 `invalid JSON ... (line N)` 錯誤。
3. 第 2 段：把公鑰內容**追加**到 `authorized_keys`，見 [| > >>](/commands/redirection/)。
