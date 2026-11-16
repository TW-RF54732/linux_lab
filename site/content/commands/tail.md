---
title: tail
summary: 看檔案的最後幾行
description: 印出檔案最後幾行。log 的最新內容都在最後面，所以看 log 先用 tail。
---

## 常用 {#basics}

```command
tail ~/.log/app.log
```

| 寫法 | 做什麼 |
| --- | --- |
| `tail 檔案` | 最後 10 行 |
| `tail -n 3 檔案` | 最後 3 行 |
| `tail -f 檔案` | 持續顯示新增的內容，[[Ctrl+C]] 結束 |

## 進階 {#advanced}

| 寫法 | 做什麼 |
| --- | --- |
| `tail -n +100 檔案` | 從第 100 行印到結尾 |
| `tail -F 檔案` | 同 `-f`，檔案被重建時也能繼續追 |
| `tail 檔案1 檔案2` | 多個檔案，各自有標題 |
| `head 檔案` | 相反：看**開頭** 10 行，選項和 `tail` 一樣 |

## 範例 {#examples}

```command
grep ERROR app.log | tail -n 1
tail ~/.log/app.log
tail -f ~/.log/app.log
```

1. 所有 ERROR 中只看最新一筆。
2. 重啟 `lab-app` 後確認出現 `INFO: started`。
3. 看著 heartbeat 每 5 秒多一行。

```output
2026-11-21 14:20:03 INFO: started
2026-11-21 14:20:08 INFO: heartbeat
2026-11-21 14:20:13 INFO: heartbeat
```
