---
title: scp
summary: 在電腦之間傳檔案
description: 透過 SSH 在筆電與伺服器之間複製檔案，用法和 cp 一樣是「來源 → 目的地」。
---

## 常用 {#basics}

在**筆電**上執行：

```command
scp ~/.ssh/id_ed25519.pub 帳號@IP:~/
```

| 寫法 | 做什麼 |
| --- | --- |
| `scp 本機檔案 帳號@IP:~/` | 上傳到伺服器的家目錄 |
| `scp 帳號@IP:遠端檔案 .` | 下載到筆電的目前目錄 |
| `scp -r 目錄 帳號@IP:~/` | 上傳整個目錄 |

**冒號不能少**。`scp file 帳號@IP` 少了冒號，只會在筆電上複製出一個叫 `帳號@IP` 的檔案。

Windows PowerShell 的公鑰路徑：

```command
scp $env:USERPROFILE\.ssh\id_ed25519.pub 帳號@IP:~/
```

## 進階 {#advanced}

| 選項 | 做什麼 |
| --- | --- |
| `-P 埠號` | 指定埠號，注意是**大寫** P（`ssh` 是小寫 `-p`） |
| `-p` | 保留檔案的時間與權限 |
| `-i 私鑰` | 指定私鑰 |
| `-C` | 壓縮傳輸 |
| `-v` | 顯示連線過程 |

## 範例 {#examples}

```command
scp ~/.ssh/id_ed25519.pub lab07@192.168.10.50:~/
scp lab07@192.168.10.50:~/reports/error.txt .
```

1. 第 3 段：上傳公鑰。這時還沒設好金鑰，會要求密碼。成功時會顯示 `100%`。
2. 把伺服器上的報告下載回筆電。
