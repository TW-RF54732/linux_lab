---
title: id
summary: 顯示帳號與群組
description: 印出你的帳號編號（uid）與所屬的群組，用來判斷你有哪些權限。
---

## 常用 {#basics}

```command
id
```

```output
uid=1001(lab07) gid=1008(lab07) groups=1008(lab07),1000(labusers)
```

| 欄位 | 意思 |
| --- | --- |
| `uid` | 帳號編號與名稱。root 是 `0` |
| `gid` | 主要群組 |
| `groups` | 所屬的所有群組 |

數字每台機器不同。重點是群組裡**沒有** `sudo`，所以你不是管理員。

## 進階 {#advanced}

| 寫法 | 做什麼 |
| --- | --- |
| `id 帳號` | 看別人的身分，例如 `id root` |
| `id -un` | 只印帳號名稱，等於 `whoami` |
| `id -Gn` | 只印群組名稱 |
| `id -u` | 只印 uid 數字 |

## 範例 {#examples}

```command
id
id root
```

比較自己和 root：root 是 `uid=0`，可以做任何事。權限的運作見 [檔案權限](/commands/permissions/)。
