---
title: 背景執行
nav: 背景執行（& 與 jobs）
summary: &、jobs、fg、Ctrl+Z
description: 在指令後面加 &，它就會在背景執行，終端機可以繼續打別的指令。
---

## 常用 {#basics}

```command
sleep 1000 &
```

```output
[1] 3420
```

`[1]` 是工作編號，`3420` 是 PID。

| 寫法 | 做什麼 |
| --- | --- |
| `指令 &` | 在背景執行 |
| `jobs` | 列出背景工作 |
| `fg` | 把背景工作拉回前景 |
| [[Ctrl+C]] | 結束前景正在跑的指令 |
| [[Ctrl+Z]] | 暫停前景正在跑的指令，放到背景 |

## 進階 {#advanced}

| 寫法 | 做什麼 |
| --- | --- |
| `bg` | 讓暫停中的工作在背景繼續跑 |
| `jobs -l` | 列出時一併顯示 PID |
| `fg %2` | 指定 2 號工作 |
| `kill %1` | 結束 1 號工作 |
| `$!` | 最近一個背景工作的 PID，例如 `kill $!` |
| `nohup 指令 &` | 登出後仍繼續執行 |

背景工作屬於這個終端機。要長期穩定執行的程式應該寫成服務，交給 systemd 管理，例如 [lab-app](/environment/lab-app/)。

## 範例 {#examples}

```command
sleep 300
```

按 [[Ctrl+Z]] 暫停：

```output
^Z
[1]+  Stopped                 sleep 300
```

```command
bg
jobs
fg
```

1. 讓它在背景繼續跑。
2. 確認是 Running。
3. 拉回前景，再按 [[Ctrl+C]] 結束。
