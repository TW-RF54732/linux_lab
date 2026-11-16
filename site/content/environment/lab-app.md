---
title: lab-app
nav: lab-app 服務
summary: 課堂要修好的服務：設定、log、錯誤訊息
description: lab-app 是每個人各自一份的小服務。它讀 ~/.config/app/config.json，把狀態寫到 ~/.log/app.log。設定錯了就拒絕啟動，並在 log 寫下原因。
---

## 常用 {#basics}

```command
systemctl --user restart lab-app
tail ~/.log/app.log
```

| 寫法 | 做什麼 |
| --- | --- |
| `systemctl --user status lab-app` | 看現在是執行中還是失敗 |
| `systemctl --user restart lab-app` | 改完設定後重新啟動 |
| `systemctl --user stop lab-app` | 停止 |
| `systemctl --user start lab-app` | 啟動 |
| `tail ~/.log/app.log` | 看 log 的最後 10 行 |
| `tail -f ~/.log/app.log` | 持續看 log，[[Ctrl+C]] 結束 |

| 檔案 | 用途 |
| --- | --- |
| `~/.config/app/config.json` | 設定檔 |
| `~/.log/app.log` | log 檔，只會往後追加 |

### 設定 {#configuration}

設定檔只有一個欄位 `enable`，要寫成小寫、不加引號的 `true` 才會啟動：

```config
{"enable": true}
```

> [!NOTE]
> 設定只在啟動時讀一次，改完一定要 `restart`。

### 正常運作的樣子 {#running}

```output
2026-11-21 14:20:03 INFO: started
2026-11-21 14:20:08 INFO: heartbeat
2026-11-21 14:20:13 INFO: heartbeat
```

啟動成功寫 `started`，之後每 5 秒寫一行 `heartbeat`。

## 錯誤訊息 {#errors}

啟動失敗時 log 最後一行會是下面其中一個：

| log 訊息 | 原因 | 修法 |
| --- | --- | --- |
| `app is disabled, set "enable" to true ...` | 還是 `false`，或改錯檔案 | 把 `app/config.json` 的 `false` 改成 `true` |
| `invalid JSON in app/config.json (line N)` | 引號、冒號、括號弄壞了 | `cp config.json.bak config.json` 重來 |
| `"enable" must be true or false (boolean)` | 寫成 `"true"`、`True` 或 `yes` | 改成小寫、不加引號的 `true` |
| `app/config.json not found` | 檔案被刪掉或改名 | 從備份複製回來 |

舊的 ERROR 會留在檔案裡，看**最後一行**就好。

## 進階 {#advanced}

### 狀態判讀 {#status}

```command
systemctl --user status lab-app
```

| 看到 | 意思 |
| --- | --- |
| `Active: active (running)` | 正常執行中 |
| `Active: failed`，`status=78/CONFIG` | 設定錯誤，沒有啟動 |
| `Active: inactive (dead)` | 被停止了 |

### log 訊息 {#logging}

| 訊息 | 何時出現 |
| --- | --- |
| `INFO: started` | 啟動成功 |
| `INFO: heartbeat` | 執行中，每 5 秒一次 |
| `INFO: stopped` | 被 `stop`、`restart` 或 `kill` 結束 |
| `ERROR: ...` | 啟動失敗 |

### 被 kill 掉 {#signals}

用 `kill` 結束 `lab-app` 的程序，效果和 `stop` 一樣，log 會寫 `stopped`。它不會自動重啟，要自己 `start`。

### 服務定義 {#unit}

```command
systemctl --user cat lab-app
```

```config
[Unit]
Description=Lab demo app (Linux Server 社課)
ConditionGroup=labusers

[Service]
Type=simple
ExecStart=/opt/lab/lab-app
Restart=no

[Install]
WantedBy=default.target
```

| 設定 | 意思 |
| --- | --- |
| `ExecStart` | 啟動時執行 `/opt/lab/lab-app` |
| `Restart=no` | 失敗或結束後不自動重啟，讓你看得到失敗狀態 |
| `WantedBy=default.target` | 你的帳號一啟動就跟著啟動 |

程式本體是文字檔，好奇的話可以讀它：`less /opt/lab/lab-app`。

## 範例 {#examples}

第 5 段的完整流程：

```command
cd ~/.config/app
cp config.json config.json.bak
nano config.json
systemctl --user restart lab-app
tail ~/.log/app.log
```

選做：停止後確認 log 不再增加，再開回來。

```command
systemctl --user stop lab-app
tail -n 3 ~/.log/app.log
systemctl --user start lab-app
```
