---
title: ps
summary: 列出正在跑的程序
description: 列出目前正在執行的程序，以及它們的 PID（程序編號）。要 kill 一個程序之前先用 ps 找到它。
---

## 常用 {#basics}

```command
ps -u $USER
```

```output
    PID TTY          TIME CMD
   1190 ?        00:00:00 systemd
   3301 ?        00:00:00 lab-app
   3389 pts/0    00:00:00 bash
   3420 pts/0    00:00:00 sleep
   3425 pts/0    00:00:00 ps
```

| 寫法 | 做什麼 |
| --- | --- |
| `ps` | 只列出目前這個終端機的程序 |
| `ps -u $USER` | 列出自己所有的程序（`$USER` 會自動換成你的帳號） |
| `ps aux` | 列出所有人的所有程序 |

| 欄位 | 意思 |
| --- | --- |
| `PID` | 程序編號，[kill](/commands/kill/) 要用 |
| `TTY` | 在哪個終端機；`?` 表示沒有，例如服務 |
| `CMD` | 程式名稱 |

## 進階 {#advanced}

| 寫法 | 做什麼 |
| --- | --- |
| `ps -ef` | 所有程序，含父程序 PID 與完整指令 |
| `ps -ef --forest` | 樹狀顯示誰啟動了誰 |
| `ps -C sleep` | 只找名稱為 sleep 的程序 |
| `ps -o pid,cmd -u $USER` | 自訂要顯示的欄位 |
| `ps aux --sort=-%mem` | 依記憶體用量排序 |
| `pgrep sleep` | 直接印出 sleep 的 PID |

`ps aux` 的 `STAT` 欄：`R` 執行中、`S` 睡眠中、`T` 暫停、`Z` 已結束但還沒被收回。

## 範例 {#examples}

第 5 段：

```command
sleep 1000 &
ps -u $USER
kill 3420
ps -u $USER
```

找到 `sleep` 那一行的 PID（每次都不同），`kill` 它，再列一次確認消失。清單裡的 `lab-app` 是你的服務。
