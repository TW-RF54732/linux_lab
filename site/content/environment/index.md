---
title: Lab 環境總覽
nav: 環境總覽
summary: 伺服器、你的帳號、能做與不能做的事
description: 你登入的 lab 伺服器長什麼樣子，以及你在上面能做什麼。
---

## 常用 {#basics}

全班共用一台 Ubuntu 24.04 伺服器，每人一個帳號（`lab01`、`lab02`…）。每個帳號裡都有一份一模一樣的 log、設定檔和自己的 `lab-app` 服務。

| 項目 | 值 |
| --- | --- |
| 登入 | `ssh 帳號@IP`，帳號與 IP 由講師提供 |
| 主機名稱 | `linux-lab` |
| 你的家目錄 | `/home/帳號`，也就是 `~` |
| 預置的 log | `~/.log/`，見 [家目錄與預置檔案](/environment/home/) |
| 預置的設定 | `~/.config/` |
| 你的服務 | `lab-app`，見 [lab-app 服務](/environment/lab-app/)；闖關時還有 `evil-killer` |
| 看進度 | 隨時打 `lab`，見 [lab 指令](/commands/lab/) |
| 課後闖關 | `~/.challange/`，見 [challange 闖關](/guide/challange/) |

### 能做與不能做 {#boundaries}

| 可以 | 不行 |
| --- | --- |
| 在 `~` 底下做任何事 | 改 `/etc`、`/opt` 等系統目錄 |
| `systemctl --user` 管理自己的服務 | 管理系統服務、用 `sudo` |
| `ps aux` 看到所有人的程序 | `kill` 別人的程序 |
| 讀一般的系統檔，例如 `/etc/os-release` | 讀私密檔，例如 `/etc/shadow` |

這些限制就是一般的 Linux 權限，原理見 [檔案權限](/commands/permissions/)。

## 進階 {#advanced}

### 帳號與群組 {#accounts}

| 名稱 | 說明 |
| --- | --- |
| `labNN` | 學員帳號，主要群組也叫 `labNN` |
| `labusers` | 所有學員的共同群組，只有這個群組能 SSH 登入 |
| `labadmins` | 講師與助教 |
| `root` | 管理員，不能從 SSH 登入 |

### 共用檔案 {#layout}

| 路徑 | 說明 |
| --- | --- |
| `/opt/lab/lab-app` | `lab-app` 程式本體，所有人共用、唯讀 |
| `/etc/systemd/user/lab-app.service` | `lab-app` 的服務定義 |
| `/etc/ssh/sshd_config.d/00-lab.conf` | lab 的 SSH 設定 |
| `/usr/local/bin/lab` | [lab 指令](/commands/lab/)，看進度與提交答案 |
| `/lab/key.txt` | challange 的密鑰，所有人可讀、不能改 |
| `/opt/lab/evil-killer` | challange 的搗蛋鬼程式 |
| `/etc/systemd/user/evil-killer.service` | `evil-killer` 的服務定義 |

### 資源限制 {#limits}

每個帳號最多 200 個程序、512 MB 記憶體。超過只會影響你自己，例如出現 `fork: retry: Resource temporarily unavailable`，其他同學不受影響。

## 範例 {#examples}

```command
whoami
hostname
id
cat /etc/os-release
ls -la ~
```

1. 我是誰。
2. 我在哪台機器。
3. 我屬於哪些群組（沒有 `sudo`）。
4. 作業系統版本。
5. 家目錄裡有什麼，包含隱藏的 `.log`、`.config` 與 `.challange`。
