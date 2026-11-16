---
title: systemctl
summary: 管理服務
description: 啟動、停止、重啟服務，以及查看服務狀態。加上 --user 就是管理你自己的服務。
---

## 常用 {#basics}

```command
systemctl --user restart lab-app
```

| 寫法 | 做什麼 |
| --- | --- |
| `systemctl --user status lab-app` | 看狀態：執行中、停止或失敗 |
| `systemctl --user restart lab-app` | 重新啟動，改完設定後用 |
| `systemctl --user start lab-app` | 啟動 |
| `systemctl --user stop lab-app` | 停止 |

`start`、`stop`、`restart` 成功時**不會印任何東西**，要用 `status` 確認。`status` 的畫面按 [[q]] 離開。

少打 `--user` 會變成找系統服務，得到 `Unit lab-app.service not found`。為什麼要 `--user` 見 [systemd 使用者服務](/environment/systemd-user/)。

## 進階 {#advanced}

| 寫法 | 做什麼 |
| --- | --- |
| `is-active 服務` | 只回答 `active`、`inactive` 或 `failed` |
| `cat 服務` | 看服務的設定檔 |
| `enable 服務` / `disable 服務` | 開機（登入）時自動啟動 / 不要自動啟動 |
| `reset-failed 服務` | 清除 failed 狀態 |
| `list-units --type=service` | 列出所有服務 |
| `daemon-reload` | 修改服務設定檔後重新載入 |
| `--no-pager` | 直接印出，不進入翻頁畫面 |

以上都要接在 `systemctl --user` 後面，例如 `systemctl --user is-active lab-app`。

## 範例 {#examples}

```command
systemctl --user restart lab-app
systemctl --user status lab-app
```

第 5 段：改完設定後重啟並確認，看到 `Active: active (running)` 就成功了。狀態的判讀見 [lab-app](/environment/lab-app/#status)。

```command
systemctl --user stop lab-app
tail -n 3 ~/.log/app.log
systemctl --user start lab-app
```

選做：停止後 log 出現 `stopped`、heartbeat 不再增加，再開回來。

```command
systemctl status ssh
```

系統服務可以看，但沒有 root 不能改。
