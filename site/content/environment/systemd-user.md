---
title: systemd 使用者服務
nav: systemd 使用者服務
summary: 程序和服務的差別、為什麼不用 sudo
description: 服務是交給 systemd 照顧的程序。加上 --user 就是管理你自己的服務，不需要 sudo。
---

## 常用 {#basics}

```command
systemctl --user status lab-app
```

| | 程序 | 服務 |
| --- | --- | --- |
| 是什麼 | 正在跑的程式，例如 `sleep 1000` | 交給 systemd 管理的程序，例如 `lab-app` |
| 啟動 | 直接打指令 | `systemctl start 名稱` |
| 停止 | `kill <PID>` | `systemctl stop 名稱` |
| 狀態 | 只有在跑或不在 | 會記得是執行中、已停止還是失敗 |

### --user 是什麼 {#system-vs-user}

| 寫法 | 管理的是 | 需要 root |
| --- | --- | --- |
| `systemctl ...` | 整台機器的系統服務，例如 `ssh` | 要 |
| `systemctl --user ...` | 你自己的服務，例如 `lab-app` | 不用 |

每個帳號都有自己的一套服務，互不影響。少打 `--user` 會得到 `Unit lab-app.service not found`。

### 你的服務 {#services}

| 服務 | 什麼時候在跑 | 說明 |
| --- | --- | --- |
| `lab-app` | 開機就會啟動，設定錯誤時是 `failed` | 第 5 段要修好的服務，見 [lab-app](/environment/lab-app/) |
| `evil-killer` | 講師宣布 challange 開始時才啟動 | 闖關裡的搗蛋鬼，見 [challange 闖關](/guide/challange/#eaten) |

兩個服務都屬於你自己，所以 `systemctl --user` 就能管理，不需要 `sudo`。

## 進階 {#advanced}

### 服務的狀態 {#states}

| 狀態 | 意思 |
| --- | --- |
| `active (running)` | 執行中 |
| `inactive (dead)` | 沒在執行 |
| `failed` | 上次失敗結束，會一直保留到下次成功啟動 |

### unit file {#unit-files}

每個服務由一個設定檔（unit file）定義，用 `systemctl --user cat 名稱` 查看。最重要的三行：

| 設定 | 意思 |
| --- | --- |
| `ExecStart=` | 啟動時執行什麼 |
| `Restart=` | 結束後要不要自動重啟 |
| `WantedBy=` | 什麼時候自動啟動 |

### 停止和停用 {#stop-vs-disable}

`stop` 是**現在**停下來；`disable` 只是**下次**不要自動啟動，正在跑的服務不會停。要兩個一起做用 `disable --now`。詳見 [systemctl](/commands/systemctl/#stop-vs-disable)。

### 你登入前服務就在了 {#linger}

lab 對每個帳號開了 linger，伺服器開機時就會啟動你的服務，不必等你登入。所以你第一次登入時，`lab-app` 已經失敗過一次，留下 log 讓你調查。

## 疑難排解 {#troubleshooting}

| 訊息 | 處理 |
| --- | --- |
| `Failed to connect to bus` | 你不是用 `ssh` 直接登入（例如用了 `su`）。登出，重新 `ssh 帳號@IP` |
| `Unit xxx.service not found` | 名稱打錯，或少了 `--user` |
| `Access denied` | 想控制系統服務，但你不是 root |

## 範例 {#examples}

```command
systemctl --user list-units --type=service
systemctl status ssh
systemctl restart ssh
```

1. 列出你自己的所有服務。
2. 系統服務可以**看**。
3. 但不能**改**，會被拒絕。
