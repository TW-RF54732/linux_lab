---
title: SSH 伺服器
nav: SSH 伺服器
summary: 登入方式、fingerprint、金鑰登入
description: 伺服器上負責讓你登入的服務。這裡說明第一次連線的提示、金鑰登入需要什麼，以及登入失敗怎麼辦。
---

## 常用 {#basics}

```command
ssh 帳號@IP
```

| 登入方式 | 說明 |
| --- | --- |
| 密碼 | 第 1 段使用。輸入時畫面不會顯示任何字元 |
| 公鑰 | 第 3 段設定，之後不用輸入密碼 |
| root | 不能登入 |

### 第一次連線 {#fingerprint}

```output
The authenticity of host '192.168.10.50 (192.168.10.50)' can't be established.
ED25519 key fingerprint is SHA256:Xb3w0dK8mR2...
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

輸入 `yes`。這是在確認伺服器的身分，確認後會記在你筆電的 `~/.ssh/known_hosts`，之後不會再問。

### 金鑰登入需要什麼 {#pubkey}

| 伺服器上的路徑 | 權限 |
| --- | --- |
| `~/.ssh/` | `700` |
| `~/.ssh/authorized_keys` | `600`，每行一把公鑰 |

權限太寬時，伺服器會**默默忽略**你的公鑰，改問密碼。

## 常見錯誤 {#errors}

| 狀況 | 原因 |
| --- | --- |
| 設好金鑰還是要密碼 | `authorized_keys` 拼錯、用 `>` 蓋掉了公鑰、或權限不對 |
| `Permission denied, please try again.` | 密碼錯，檢查大小寫與輸入法 |
| `Connection refused` / `timed out` | IP 打錯或網路不通 |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | 伺服器重建過，見下方進階 |

## 進階 {#advanced}

### 看金鑰登入哪裡出錯 {#pubkey-troubleshooting}

在**筆電**執行：

```command
ssh -v 帳號@IP
```

找 `Offering public key` 之後有沒有 `Server accepts key`。沒有的話，回伺服器檢查：

```command
ls -la ~/.ssh
cat ~/.ssh/authorized_keys
```

### 伺服器重建後 {#host-changed}

伺服器重建會換一把主機金鑰，筆電會警告 `REMOTE HOST IDENTIFICATION HAS CHANGED`。確認是講師重建的之後，在**筆電**刪掉舊紀錄：

```command
ssh-keygen -R 192.168.10.50
```

### lab 的 SSH 設定 {#auth}

```command
cat /etc/ssh/sshd_config.d/00-lab.conf
```

| 設定 | 值 |
| --- | --- |
| `PasswordAuthentication` | `yes`：可用密碼 |
| `PubkeyAuthentication` | `yes`：可用公鑰 |
| `PermitRootLogin` | `no`：root 不能登入 |
| `AllowGroups` | 只有學員與講師群組能登入 |

## 範例 {#examples}

第 3 段的完整流程見 [課程任務地圖](/guide/lab-tasks/#part-3)。
