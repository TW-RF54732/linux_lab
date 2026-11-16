---
title: find
summary: 依名稱搜尋檔案
description: 從一個目錄開始往下找，列出符合條件的檔案。
---

## 常用 {#basics}

```command
find ~/.config -name config.json
```

| 寫法 | 做什麼 |
| --- | --- |
| `find 目錄 -name 檔名` | 依檔名找 |
| `find 目錄 -name '*.log'` | 用 `*` 代表任意字元，樣式要加引號 |
| `find 目錄 -iname 檔名` | 同上，不分大小寫 |
| `find 目錄 -type f` | 只找檔案 |
| `find 目錄 -type d` | 只找目錄 |

注意 `find` 的選項是**一個減號加完整單字**（`-name`），和一般指令不同。

## 進階 {#advanced}

| 條件 | 做什麼 |
| --- | --- |
| `-path '*app*'` | 完整路徑符合樣式 |
| `-size +100k` | 大於 100 KB（`-` 是小於，單位 `k`、`M`、`G`） |
| `-mmin -30` | 30 分鐘內改過 |
| `-mtime -1` | 1 天內改過 |
| `-maxdepth 1` | 只找一層，不往下 |
| `-exec 指令 {} \;` | 對每個結果執行指令，`{}` 會換成檔名 |
| `-delete` | 刪除找到的檔案，**無法復原**，先不加確認結果 |

## 範例 {#examples}

```command
find ~/.config -name config.json
```

```output
/home/lab07/.config/chat-bot/config.json
/home/lab07/.config/app/config.json
/home/lab07/.config/monitor/config.json
/home/lab07/.config/backup-agent/config.json
```

找到好幾個同名檔案，要靠**路徑**判斷哪一個是 `app` 的。另一種做法：`ls ~/.config | grep app`。

```command
find ~ -name '*.bak'
find ~ -mmin -30
find / -name sshd_config 2>/dev/null
```

1. 找所有備份檔。
2. 30 分鐘內改過的檔案。
3. 在整台機器找，`2>/dev/null` 丟掉沒權限的錯誤訊息，見 [| > >>](/commands/redirection/#advanced)。
