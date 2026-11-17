---
title: touch
summary: 建立空檔案
description: 建立一個空檔案；檔案已經存在時只更新它的時間，不會動到內容。
---

## 常用 {#basics}

```command
touch ~/error.txt
```

| 寫法 | 做什麼 |
| --- | --- |
| `touch 檔案` | 建立空檔案 |
| `touch a b c` | 一次建立多個 |

## 進階 {#advanced}

| 選項 | 做什麼 |
| --- | --- |
| `-d '3 days ago'` | 把檔案時間設成指定的時間 |
| `-c` | 檔案不存在時不要建立 |
| `-r 參考檔` | 時間設成和參考檔一樣 |

## 範例 {#examples}

```command
touch ~/error.txt
touch demo.sh
ls -l demo.sh
```

1. 第 3 段：先建立空檔，再用 `>>` 把錯誤加進去。
2. 第 4 段：建立檔案來示範 `chmod +x`。
3. 看到大小是 `0`。

上層目錄不存在時會失敗（`No such file or directory`），先用 [mkdir -p](/commands/mkdir/) 建立。
