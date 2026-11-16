---
title: grep
summary: 找出含有關鍵字的行
description: 從檔案或其他指令的輸出中，只留下含有關鍵字的行。在大量 log 裡找錯誤的主力工具。
---

## 常用 {#basics}

```command
grep ERROR app.log
```

| 寫法 | 做什麼 |
| --- | --- |
| `grep 關鍵字 檔案` | 印出含有關鍵字的行 |
| `grep -i 關鍵字 檔案` | 不分大小寫 |
| `grep -n 關鍵字 檔案` | 加上行號 |
| `grep -c 關鍵字 檔案` | 只印有幾行符合 |
| `grep -v 關鍵字 檔案` | 反過來：印出**不含**關鍵字的行 |
| `指令 \| grep 關鍵字` | 過濾其他指令的輸出 |

**大小寫有差**：`grep error` 找不到 `ERROR`。關鍵字有空白時要加引號：`grep 'app is disabled' app.log`。

## 進階 {#advanced}

| 選項 | 做什麼 |
| --- | --- |
| `-r` | 搜尋整個目錄，例如 `grep -r ERROR ~/.log` |
| `-l` | 只印有符合的檔名 |
| `-w` | 只比對完整單字，`-w app` 不會符合 `apple` |
| `-A 2` / `-B 2` / `-C 2` | 同時印出後 / 前 / 前後 2 行 |
| `-E 'A\|B'` | 符合 A 或 B，例如 `grep -E 'ERROR\|WARN'` |
| `-o` | 只印出符合的部分 |
| `-m 1` | 找到 1 筆就停 |

常用的特殊符號（正規表示式）：`^` 行首、`$` 行尾、`.` 任意一個字元。例如 `grep '^2026-11-21' app.log` 只找該日期開頭的行。

## 範例 {#examples}

```command
grep ERROR app.log
grep ERROR app.log | tail -n 1
grep ERROR app.log | wc -l
grep ERROR app.log > ~/error.txt
ls ~/.config | grep app
```

1. 列出所有錯誤。
2. 只看最新一筆，就是現在的問題。
3. 數有幾筆。
4. 存成檔案，見 [| > >>](/commands/redirection/)。
5. 從目錄清單中找出 `app`。

`cat app.log | grep ERROR` 也可以，但 `grep` 自己就能讀檔，不必先 `cat`。

```command
grep -A 2 'database connection lost' app.log
```

看舊錯誤之後發生了什麼（恢復訊息）。
