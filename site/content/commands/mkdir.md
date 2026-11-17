---
title: mkdir
summary: 建立目錄
description: 建立新的目錄（資料夾）。
---

## 常用 {#basics}

```command
mkdir reports
```

| 寫法 | 做什麼 |
| --- | --- |
| `mkdir 目錄` | 建立目錄 |
| `mkdir -p 路徑` | 一次建立多層；目錄已存在也不會報錯 |

## 進階 {#advanced}

| 選項 | 做什麼 |
| --- | --- |
| `-m 700` | 建立時直接設定權限 |
| `-v` | 顯示建立了哪些目錄 |

刪除空目錄用 `rmdir`，有內容的目錄用 [rm -r](/commands/rm/)。

## 範例 {#examples}

```command
mkdir reports
mkdir -p ~/.ssh
mkdir -p ~/practice/2026/nov
```

1. 第 3 段：建立存放報告的目錄。
2. 第 2 段：建立 `.ssh`。加 `-p` 是因為不確定它存不存在，重複執行也沒關係。
3. 一次建立三層。

不加 `-p` 時，目錄已存在會出現 `File exists`。
