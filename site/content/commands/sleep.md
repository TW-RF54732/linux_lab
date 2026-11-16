---
title: sleep
summary: 等待一段時間
description: 什麼都不做，等指定的時間後結束。課堂上用它產生一個可以拿來練習 ps 與 kill 的程序。
---

## 常用 {#basics}

```command
sleep 1000 &
```

| 寫法 | 做什麼 |
| --- | --- |
| `sleep 5` | 等 5 秒 |
| `sleep 5m` | 等 5 分鐘（`s` 秒、`m` 分、`h` 時、`d` 天） |
| `sleep 1000 &` | 在背景等，不佔住終端機 |

前景在等的時候按 [[Ctrl+C]] 可以中斷。

## 進階 {#advanced}

| 寫法 | 做什麼 |
| --- | --- |
| `sleep 0.5` | 可以用小數 |
| `sleep 1m 30s` | 多個時間會加總 |
| `sleep infinity` | 永遠等下去 |

## 範例 {#examples}

```command
sleep 1000 &
sleep 10; tail -n 2 ~/.log/app.log
```

1. 第 5 段：開一個背景程序，接著用 `ps` 找、用 `kill` 結束。`&` 的說明見 [背景執行](/commands/jobs/)。
2. 等 10 秒再看 log，heartbeat 應該多了兩行。`;` 讓兩個指令依序執行。
