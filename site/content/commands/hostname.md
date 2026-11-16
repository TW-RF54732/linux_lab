---
title: hostname
summary: 顯示主機名稱
description: 印出這台電腦的名稱，也就是提示字元 @ 後面那一段。
---

## 常用 {#basics}

```command
hostname
```

```output
linux-lab
```

| 寫法 | 做什麼 |
| --- | --- |
| `hostname` | 印出主機名稱 |

## 進階 {#advanced}

| 選項 | 做什麼 |
| --- | --- |
| `-I` | 列出這台機器的 IP 位址 |
| `-s` | 只印短名稱（第一個 `.` 之前） |
| `-f` | 完整網域名稱 |

改主機名稱需要 root，學員不能改。

## 範例 {#examples}

```command
hostname -I
```

列出伺服器的 IP，也就是你 `ssh` 連進來的位址。
