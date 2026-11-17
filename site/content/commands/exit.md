---
title: exit
summary: 登出
description: 結束目前的 shell。在 SSH 登入後執行就是登出，回到你的筆電。
---

## 常用 {#basics}

```command
exit
```

```output
logout
Connection to 192.168.10.50 closed.
```

| 寫法 | 做什麼 |
| --- | --- |
| `exit` | 登出 |
| [[Ctrl+D]] | 在空白提示字元按下，效果一樣 |

## 進階 {#advanced}

| 寫法 | 做什麼 |
| --- | --- |
| `exit 數字` | 以指定的結束碼離開，`0` 代表成功 |
| `~.` | 連線卡住時先按 [[Enter]] 再輸入，強制中斷 ssh |

有暫停中的背景工作時，第一次 `exit` 會提示 `There are stopped jobs.`，再打一次就會離開。

## 範例 {#examples}

第 2 段設定好金鑰後：

```command
exit
ssh 帳號@IP
```

重新登入，確認不用輸入密碼。
