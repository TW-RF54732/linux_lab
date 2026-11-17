---
title: lab
nav: lab 指令
summary: 看自己的進度、拿提示、提交 challange 答案
description: lab 是這台伺服器專用的指令。隨時打 lab 就能看到自己每一段完成了沒，challange 闖關的提示與提交也都用它。
---

## 常用 {#basics}

```command
lab
```

| 寫法 | 做什麼 |
| --- | --- |
| `lab` | 看自己的進度：教學關卡與 challange |
| `lab hint` | 依你目前的進度給一則 challange 提示 |
| `lab hint 3` | 看第 3 則提示，共 5 則 |
| `lab flag '解出來的 flag'` | 提交 flag，要整串貼上，用單引號包起來 |
| `lab bonus 文字` | 提交 bonus，大小寫都可以 |

不需要 `sudo`，每個人只看得到自己的進度。

### 看懂進度 {#status}

```output
lab07 的進度

教學關卡
  ✓ 1 SSH 登入
  ✓ 2 金鑰登入      這次是用金鑰登入的
  △ 3 錯誤報告      報告做好了，記得 scp 回筆電
  · 5 修好 lab-app

challange 闖關
  任務：解開 ~/.challange 裡的加密檔拿到 flag，用 lab 提交
  先讀：~/.challange/README.txt
  evil-killer：沒在執行
  · flag    提交：lab flag '<flag>'
  · bonus   提交：lab bonus <文字>

  卡住了：lab hint
```

| 符號 | 意思 |
| --- | --- |
| `✓` | 完成 |
| `△` | 做了一半，右邊會寫還差什麼 |
| `✗` | 有問題，右邊會寫原因 |
| `·` | 還沒開始 |

第 4 段只講不做，所以沒有列出來。

## 進階 {#advanced}

### 每一項怎麼判斷 {#checkpoints}

| 項目 | 什麼時候變 `✓` | 其他狀態 |
| --- | --- | --- |
| 1 SSH 登入 | 你能執行 `lab` 就代表登入了 | — |
| 2 金鑰登入 | **這一次**登入是用金鑰，不是密碼 | `△` 公鑰放好了，`exit` 再登入一次試試；`✗` `authorized_keys` 沒有公鑰或權限太寬 |
| 3 錯誤報告 | 講師那邊看到你用 `scp` 把 `error.txt` 拉回筆電 | `△` `~/reports/error.txt` 做好了，或 `~/error.txt` 還沒搬；`✗` 報告裡沒有最後那筆 ERROR |
| 5 修好 lab-app | `app.log` 出現過 `INFO: started` | `✗` 會寫出 lab-app 最後一次失敗的原因 |

> [!NOTE]
> 第 3 段在你這邊**最多只會到 `△`**，這是正常的。下載紀錄只有講師的計分板看得到，你 `scp` 成功、筆電上有 `error.txt` 就算完成。

第 2 段如果是用密碼登入，就算公鑰已經放好也只會顯示 `△`。`exit` 後重新 `ssh` 一次，沒問密碼就會變 `✓`。

### 提示 {#hints}

```command
lab hint
```

```output
提示 1/5
先讀 ~/.challange/README.txt（cat ~/.challange/README.txt），
然後執行解密器：cd ~/.challange，再 ./decoder.sh

其他提示：lab hint 1 … lab hint 5
```

不加編號會依照你目前的進度自動挑一則。提示會直接給指令，想自己解的話先別急著看後面幾則。

### 提交 {#submit}

```output
✓ flag 正確！
```

答對後答案會存在 `~/.lab/`，`lab` 的 flag、bonus 那一行會變成 `已取得`。不要刪掉 `~/.lab`，刪了就要重新提交。

| 規則 | flag | bonus |
| --- | --- | --- |
| 要給的內容 | 整串，包含開頭的 `flag` 和大括號 | 畫出來的 5 個字 |
| 大小寫 | 要一模一樣 | 不分 |
| 空白 | 不能有 | 會自動忽略 |

flag 裡有大括號等符號，用單引號 `'...'` 包起來，shell 就不會動到它。

### 講師用的選項 {#admin}

`lab --all`、`lab --start` 這些是講師的計分板與闖關開關，要 root 才能執行，你用不到。

## 範例 {#examples}

```command
lab
lab hint
lab hint 2
```

1. 上課中隨時看自己做到哪。
2. challange 卡住時看下一步。
3. 指定看第 2 則。

整個闖關流程見 [challange 闖關](/guide/challange/)。

## 常見錯誤 {#errors}

| 訊息 | 原因 |
| --- | --- |
| `✗ flag 不對，再試試` | 少了開頭的 `flag` 或大括號、多了空白，或沒用單引號包起來 |
| `用法：lab flag '<flag>'` | `flag` 後面沒有接答案 |
| `lab：提示編號是 1 到 5` | `lab hint` 後面的數字超出範圍 |
| `lab：還沒有你的答案資料，請找講師` | 你的 challange 還沒建立，請講師處理 |
| `lab：這個指令要 root` | 執行了講師用的選項 |
