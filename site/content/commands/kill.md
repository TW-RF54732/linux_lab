---
title: kill
summary: 結束程序
description: 送訊號給程序，最常用來叫它結束。只能對自己的程序使用。
---

## 常用 {#basics}

```command
kill 3420
```

| 寫法 | 做什麼 |
| --- | --- |
| `kill PID` | 請程序結束（PID 用 [ps](/commands/ps/) 查） |
| `kill %1` | 結束 1 號背景工作，不用查 PID |
| `kill -9 PID` | 強制結束，程序不理會時才用 |

成功時不會印任何東西。

## 進階 {#advanced}

`kill` 其實是「送訊號」，預設送的是 `TERM`（請你結束）：

| 訊號 | 意思 |
| --- | --- |
| `15` `TERM` | 請求結束，程序可以先收拾再離開（預設） |
| `9` `KILL` | 立刻強制結束，程序無法拒絕 |
| `2` `INT` | 中斷，等同按 [[Ctrl+C]] |
| `1` `HUP` | 很多服務拿來當「重新讀取設定」 |

`kill -l` 列出所有訊號。依名稱結束程序可以用 `pkill sleep`。

## 常見錯誤 {#errors}

| 訊息 | 原因 |
| --- | --- |
| `Operation not permitted` | 那是別人的程序 |
| `No such process` | PID 打錯，或程序已經結束了 |

## 範例 {#examples}

```command
sleep 1000 &
ps -u $USER
kill 3420
```

`3420` 換成你看到的 PID。再按一次 [[Enter]] 會看到：

```output
[1]+  Terminated              sleep 1000
```

> [!NOTE]
> 如果你 `kill` 的是 `lab-app`，等於停止服務，log 會寫 `INFO: stopped`。要用 `systemctl --user start lab-app` 開回來。服務應該用 [systemctl](/commands/systemctl/) 停止，而不是 `kill`。
