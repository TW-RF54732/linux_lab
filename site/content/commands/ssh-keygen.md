---
title: ssh-keygen
summary: 產生 SSH 金鑰
description: 產生一組金鑰：私鑰留在筆電，公鑰放到伺服器，之後登入就不用密碼。
---

## 常用 {#basics}

在**筆電**上執行，問題一路按 [[Enter]]：

```command
ssh-keygen -t ed25519
```

會產生兩個檔案：

| 檔案 | 是什麼 | 可以給別人嗎 |
| --- | --- | --- |
| `~/.ssh/id_ed25519` | 私鑰 | **絕對不行** |
| `~/.ssh/id_ed25519.pub` | 公鑰，要放到伺服器上 | 可以 |

Windows 的位置是 `C:\Users\你的帳號\.ssh\`。

> [!WARNING]
> 如果問 `Overwrite (y/n)?`，代表已經有一把金鑰了，回答 `n`。覆蓋之後，舊金鑰能登入的地方都會失效。

## 進階 {#advanced}

| 寫法 | 做什麼 |
| --- | --- |
| `-f 路徑` | 指定檔名，例如 `-f ~/.ssh/lab_key` |
| `-C 註解` | 加在公鑰最後的註解，方便辨認 |
| `-N ''` | 不設密語、不再詢問 |
| `-p -f 私鑰` | 修改私鑰的密語 |
| `-lf 公鑰` | 顯示金鑰的指紋（fingerprint） |
| `-R 主機` | 從 `known_hosts` 刪除某台主機的紀錄 |

產生時問的 passphrase（密語）是私鑰的密碼。留空最方便；設定的話，私鑰被偷也無法直接使用。

## 範例 {#examples}

```command
ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub
```

1. 產生金鑰。
2. 看公鑰內容，是一行以 `ssh-ed25519` 開頭的文字。

接著用 [scp](/commands/scp/) 把 `.pub` 傳到伺服器，完整流程見 [課程任務地圖](/guide/lab-tasks/#part-2)。
