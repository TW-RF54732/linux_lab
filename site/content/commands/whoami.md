---
title: whoami
summary: 顯示我是誰
description: 印出目前登入的帳號名稱。
---

## 常用 {#basics}

```command
whoami
```

```output
lab07
```

| 寫法 | 做什麼 |
| --- | --- |
| `whoami` | 印出帳號名稱 |

在筆電和伺服器各打一次，結果不同，就知道兩邊是不同的電腦、不同的帳號。

## 進階 {#advanced}

`whoami` 沒有其他選項。想看更多身分資訊（群組等）用 [id](/commands/id/)。

## 範例 {#examples}

```command
echo "我是 $(whoami)，在 $(hostname)"
```

`$( )` 會先執行裡面的指令，再把結果放回原位。
