#!/usr/bin/env bash
# Linux Server 社課 lab：在 CT 內以 root 跑「開課前驗證清單」中能自動化的部分。
#
# 用法：
#   ./verify.sh                      # 檢查 lab01 的初始狀態、權限、SSH、資源限制設定
#   ./verify.sh --user lab05         # 改用其他測試帳號
#   ./verify.sh --scenarios          # 另外跑第 5 段的修復情境（改 true / 壞 JSON / "true" …），結束後還原
#   ./verify.sh --fork-test          # 另外在測試帳號實際超過 TasksMax，確認只影響自己
#   ./verify.sh --challange          # 另外跑完整闖關（啟動 evil-killer、解密、被吃、停止、提交），最後 lab --reset 還原；
#                                    #   結尾會跑一次 lab --stop（全部學員），請在課前執行
#   ./verify.sh --progress           # 另外測 lab --all 的教學檢查點偵測（金鑰登入、下載 error.txt），最後清掉 ~/.ssh、~/reports
#
# 需要從學員網段外部電腦手動確認的項目（密碼登入、公鑰登入、多人同時登入、bonus）見 README。

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lab.conf
source "$HERE/lab.conf"

WIDTH=$(( ${#LAB_COUNT} < 2 ? 2 : ${#LAB_COUNT} ))
U=$(printf '%s%0*d' "$LAB_PREFIX" "$WIDTH" 1)
OTHER=$(printf '%s%0*d' "$LAB_PREFIX" "$WIDTH" 2)
SCENARIOS=0
FORK=0
CHALLANGE=0
PROGRESS=0
while [ $# -gt 0 ]; do
    case "$1" in
        --user) U=$2; shift ;;
        --scenarios) SCENARIOS=1 ;;
        --fork-test) FORK=1 ;;
        --challange) CHALLANGE=1 ;;
        --progress) PROGRESS=1 ;;
        -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done
[ "$OTHER" = "$U" ] && OTHER=$(printf '%s%0*d' "$LAB_PREFIX" "$WIDTH" 1)

PASS=0; FAIL=0
pass() { printf '  \033[32mPASS\033[0m %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; FAIL=$((FAIL + 1)); }
check() { local desc=$1; shift; if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi; }
not() { ! "$@"; }
section() { printf '\n\033[1m%s\033[0m\n' "$*"; }

[ "$(id -u)" -eq 0 ] || { echo "請用 root 執行" >&2; exit 1; }
id "$U" >/dev/null 2>&1 || { echo "帳號 $U 不存在" >&2; exit 1; }
UID_=$(id -u "$U")
HOME_=$(getent passwd "$U" | cut -d: -f6)
LOG="$HOME_/.log/app.log"
CFG="$HOME_/.config/app/config.json"
CHAL="$HOME_/.challange"
MARK='flag{'
EVIL_TAIL=$'I am evil-killer\nI eat your flag hahaha\ntry to stop me!!'

as_user() { runuser -u "$U" -- env HOME="$HOME_" XDG_RUNTIME_DIR="/run/user/$UID_" "$@"; }
# lab_json <段落> <欄位>：從 lab --all --json 取出測試帳號的狀態，例如 lab_json lesson key → ok
lab_json() {
    lab --all --json 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(d.get(sys.argv[1], {}).get(sys.argv[2], {}).get(sys.argv[3], ""))' "$U" "$1" "$2"
}
wait_for() {  # wait_for <秒> <指令…>：在時限內等到指令成功
    local t=$1 i; shift
    for i in $(seq 1 $((t * 4))); do "$@" && return 0; sleep 0.25; done
    return 1
}
evil_ok() { [ -f "$CHAL/evil.txt" ] && [ "$(tail -n 3 "$CHAL/evil.txt")" = "$EVIL_TAIL" ]; }
usvc() { as_user systemctl --user "$@"; }
state() { usvc show -p ActiveState --value lab-app.service 2>/dev/null; }
last_line() { tail -n 1 "$LOG"; }
wait_state() {  # wait_state <state> [timeout_s]
    local want=$1 t=${2:-10} i
    for i in $(seq 1 $((t * 4))); do [ "$(state)" = "$want" ] && return 0; sleep 0.25; done
    return 1
}

echo "測試帳號：$U（另一個帳號：$OTHER）"

# ------------------------------------------------------------------ 帳號與權限
section "帳號與權限"
groups_=$(id -nG "$U")
if [[ " $groups_ " == *" sudo "* || " $groups_ " == *" adm "* ]]; then
    fail "id 不含 sudo 與 adm（目前：$groups_）"
else
    pass "id 不含 sudo 與 adm（$groups_）"
fi
check "sudo -l 被拒" bash -c "! runuser -u '$U' -- sudo -n -l"
check "登入 shell 是 /bin/bash" bash -c "[ \"\$(getent passwd '$U' | cut -d: -f7)\" = /bin/bash ]"
check "家目錄權限 750" bash -c "[ \"\$(stat -c %a '$HOME_')\" = 750 ]"
if id "$OTHER" >/dev/null 2>&1; then
    check "$OTHER 無法進入 $HOME_" bash -c "! runuser -u '$OTHER' -- ls '$HOME_'"
fi
check "學員讀 /etc/shadow 被拒" bash -c "! runuser -u '$U' -- cat /etc/shadow"
check "/opt/lab/lab-app 為 root 755" bash -c "[ \"\$(stat -c '%U %a' /opt/lab/lab-app)\" = 'root 755' ]"
check "學員不能改 /opt/lab/lab-app" bash -c "! runuser -u '$U' -- test -w /opt/lab/lab-app"

# ------------------------------------------------------------------ 家目錄內容
section "家目錄內容"
for d in .log .config; do
    check "~/$d 存在、擁有者 $U、權限 755" \
        bash -c "[ \"\$(stat -c '%U %a' '$HOME_/$d')\" = '$U 755' ]"
done
for x in .ssh reports error.txt; do
    [ -e "$HOME_/$x" ] && fail "~/$x 不應存在（課前要清掉）" || pass "~/$x 不存在"
done
for f in app.log access.log db.log cron.log boot.log; do
    check "~/.log/$f 存在" test -s "$HOME_/.log/$f"
done
n=$(wc -l < "$LOG"); [ "$n" -ge 1500 ] && pass "app.log 行數 $n" || fail "app.log 行數 $n（預期約 2000）"
check "其他 log 不含 ERROR" bash -c "! grep -q ERROR '$HOME_'/.log/{access,db,cron,boot}.log"
check "config.json 內容為 {\"enable\": false}" bash -c "grep -qx '{\"enable\": false}' '$CFG'"
cnt=$(find "$HOME_/.config" -name config.json | wc -l)
[ "$cnt" -ge 3 ] && pass "find ~/.config -name config.json 有 $cnt 筆" || fail "config.json 只有 $cnt 筆"
cnt=$(find "$HOME_/.config" -mindepth 1 -maxdepth 1 -type d | wc -l)
[ "$cnt" -ge 6 ] && pass "~/.config 有 $cnt 個目錄" || fail "~/.config 只有 $cnt 個目錄"
cnt=$(ls "$HOME_/.config" | grep -c app)
[ "$cnt" -eq 1 ] && pass "ls ~/.config | grep app 只有一筆" || fail "ls ~/.config | grep app 有 $cnt 筆"
if [ -n "$(find "$HOME_/.log" "$HOME_/.config" ! -user "$U")" ]; then
    fail "~/.log、~/.config 內有檔案不屬於 $U"
else
    pass "~/.log、~/.config 全部屬於 $U"
fi

# ------------------------------------------------------------------ systemd user service
section "systemd user service"
check "linger 已啟用" bash -c "loginctl show-user '$U' -p Linger --value | grep -qx yes"
out=$(usvc status lab-app.service 2>&1)
if grep -q "Failed to connect to bus" <<<"$out"; then
    fail "systemctl --user status：Failed to connect to bus"
else
    pass "systemctl --user status 可執行"
fi
check "lab-app 為 global enabled" test -L /etc/systemd/user/default.target.wants/lab-app.service
st=$(state)
[ "$st" = failed ] && pass "服務狀態 failed" || fail "服務狀態 $st（預期 failed）"
grep -q 'ERROR: app is disabled, set "enable" to true in app/config.json' <<<"$(last_line)" \
    && pass "app.log 最後一筆是 app is disabled" || fail "app.log 最後一筆：$(last_line)"
ts=$(last_line | cut -c1-19)
age=$(( $(date +%s) - $(date -d "$ts" +%s 2>/dev/null || echo 0) ))
if [ "$age" -lt 0 ]; then
    fail "最後一筆時間戳在未來（$ts）"
elif [ "$age" -le 86400 ]; then
    pass "最後一筆時間戳 $ts（$((age / 60)) 分鐘前）"
else
    fail "最後一筆時間戳 $ts 已超過一天，開課前請重新產生（setup.sh --reseed 或還原腳本）"
fi

# ------------------------------------------------------------------ challange 初始狀態
section "challange 初始狀態"
check "/lab 為 root 755" bash -c "[ \"\$(stat -c '%U %a' /lab)\" = 'root 755' ]"
check "/lab/key.txt 為 root 644" bash -c "[ \"\$(stat -c '%U %a' /lab/key.txt)\" = 'root 644' ]"
check "學員可以 cat /lab/key.txt" as_user cat /lab/key.txt
check "學員不能修改 /lab/key.txt" not as_user test -w /lab/key.txt
check "學員不能刪除 /lab/key.txt（/lab 不可寫）" not as_user test -w /lab
key=$(head -n 1 /lab/key.txt)
if [ "${#key}" -eq 128 ] && [ "$(wc -l < /lab/key.txt)" -eq 1 ]; then
    pass "密鑰長度 128、只有一行"
else
    fail "密鑰長度 ${#key}、$(wc -l < /lab/key.txt) 行（預期 128 字、1 行）"
fi
if grep -q "[{}[:space:]\"'\\\\]" <<<"$key"; then
    fail "密鑰含大括號、空白、引號或反斜線"
else
    pass "密鑰不含大括號、空白、引號、反斜線"
fi
check "~/.challange 為 $U 755" bash -c "[ \"\$(stat -c '%U %a' '$CHAL')\" = '$U 755' ]"
got=$(ls -A "$CHAL" 2>/dev/null | sort | tr '\n' ' ')
[ "$got" = "README.txt decoder.sh " ] && pass "~/.challange 只有 README.txt、decoder.sh" \
    || fail "~/.challange 內容：$got（預期只有 README.txt decoder.sh）"
check "decoder.sh 為 $U 444（刻意沒有 x）" bash -c "[ \"\$(stat -c '%U %a' '$CHAL/decoder.sh')\" = '$U 444' ]"
found=$(grep -rlF --exclude=.bash_history -- "$MARK" "$HOME_" 2>/dev/null)
[ -z "$found" ] && pass "家目錄沒有任何檔案含 flag 標記" || fail "含 flag 標記的檔案：$found"
out=$(cd "$CHAL" && as_user ./decoder.sh 2>&1); rc=$?
[ "$rc" -eq 126 ] && grep -q 'Permission denied' <<<"$out" && pass "./decoder.sh → Permission denied" \
    || fail "./decoder.sh → rc=$rc：$out"
out=$(as_user bash "$CHAL/decoder.sh" 2>&1)
grep -q '找不到密鑰檔：~/.challange/key.txt' <<<"$out" && pass "沒放密鑰時 bash decoder.sh → 找不到密鑰檔" \
    || fail "沒放密鑰時輸出：$out"
got=$(ls -A "$CHAL" 2>/dev/null | sort | tr '\n' ' ')
[ "$got" = "README.txt decoder.sh " ] && pass "失敗時沒有留下檔案" || fail "失敗後 ~/.challange：$got"
check "evil-killer 沒在執行（等 lab --start）" not pgrep -u "$U" -x evil-killer
check "/opt/lab/evil-killer 為 root 755" bash -c "[ \"\$(stat -c '%U %a' /opt/lab/evil-killer)\" = 'root 755' ]"
check "/opt/lab/evil-killer 的 shebang 是 #!/bin/bash（comm 才會是 evil-killer）" \
    bash -c "[ \"\$(head -n 1 /opt/lab/evil-killer)\" = '#!/bin/bash' ]"
check "evil-killer.service 為 root 644" \
    bash -c "[ \"\$(stat -c '%U %a' /etc/systemd/user/evil-killer.service)\" = 'root 644' ]"
check "evil-killer 沒有 global enable" not test -e /etc/systemd/user/default.target.wants/evil-killer.service
check "/usr/local/bin/lab 為 root 755" bash -c "[ \"\$(stat -c '%U %a' /usr/local/bin/lab)\" = 'root 755' ]"
check "雜湊檔 /var/lib/lab/users/$U.json 為 root:$U 640" \
    bash -c "[ \"\$(stat -c '%U:%G %a' /var/lib/lab/users/$U.json)\" = 'root:$U 640' ]"
check "答案檔 /var/lib/lab/answers/$U.json 為 root 600" \
    bash -c "[ \"\$(stat -c '%U %a' /var/lib/lab/answers/$U.json)\" = 'root 600' ]"
if id "$OTHER" >/dev/null 2>&1; then
    check "$OTHER 讀不到 $U 的雜湊檔" not runuser -u "$OTHER" -- cat "/var/lib/lab/users/$U.json"
fi
check "學員可以執行 lab" as_user lab
check "教學檢查點基準時間 /var/lib/lab/lesson/$U 存在" test -s "/var/lib/lab/lesson/$U"

# ------------------------------------------------------------------ SSH
section "SSH"
eff=$(sshd -T 2>/dev/null)
for kv in "passwordauthentication yes" "pubkeyauthentication yes" "permitrootlogin no" "usepam yes" \
          "exposeauthinfo yes"; do
    grep -qx "$kv" <<<"$eff" && pass "$kv" || fail "$kv（目前：$(grep "^${kv%% *} " <<<"$eff")）"
done
grep -qi "^allowgroups .*labusers" <<<"$eff" && pass "$(grep -i '^allowgroups' <<<"$eff")" || fail "AllowGroups 未含 labusers"
pass "$(grep -i '^maxstartups' <<<"$eff")"
SFTP_LOG=0
if grep -qix "subsystem sftp internal-sftp -l INFO" <<<"$eff"; then
    SFTP_LOG=1
    pass "subsystem sftp internal-sftp -l INFO（第 3 段下載偵測）"
else
    # setup.sh 在 OpenSSH 不接受時會自動拿掉這行，屬於可接受的降級，不算 FAIL
    echo "  NOTE sftp 沒有記錄讀檔（$(grep -i '^subsystem ' <<<"$eff")），計分板第 3 段只會到 △"
fi
check "sshd 在 22 port 監聽" bash -c "ss -Hltn | grep -qE ':22\\b'"
if command -v fail2ban-client >/dev/null; then
    fail "安裝了 fail2ban：教室共用 IP 時請加白名單或暫停"
else
    pass "沒有 fail2ban"
fi

# ------------------------------------------------------------------ 資源限制
section "資源限制"
props=$(systemctl show "user-$UID_.slice" -p TasksMax -p MemoryMax)
grep -qx "TasksMax=$LAB_TASKS_MAX" <<<"$props" && pass "user-$UID_.slice TasksMax=$LAB_TASKS_MAX" \
    || fail "user-$UID_.slice $(grep TasksMax <<<"$props")"
want_mem=$(numfmt --from=iec "$LAB_MEMORY_MAX" 2>/dev/null || echo "$LAB_MEMORY_MAX")
grep -qx "MemoryMax=$want_mem" <<<"$props" && pass "user-$UID_.slice MemoryMax=$LAB_MEMORY_MAX" \
    || fail "user-$UID_.slice $(grep MemoryMax <<<"$props")"
cg=/sys/fs/cgroup/user.slice/user-$UID_.slice
if [ -d "$cg" ]; then
    [ "$(cat "$cg/pids.max" 2>/dev/null)" = "$LAB_TASKS_MAX" ] && pass "cgroup pids.max = $LAB_TASKS_MAX（核心實際生效）" \
        || fail "cgroup pids.max = $(cat "$cg/pids.max" 2>/dev/null || echo 無)（pids controller 沒委派給 CT？）"
    [ "$(cat "$cg/memory.max" 2>/dev/null)" = "$want_mem" ] && pass "cgroup memory.max = $LAB_MEMORY_MAX（核心實際生效）" \
        || fail "cgroup memory.max = $(cat "$cg/memory.max" 2>/dev/null || echo 無)"
else
    fail "找不到 $cg"
fi

# ------------------------------------------------------------------ 第 5 段情境
if [ "$SCENARIOS" -eq 1 ]; then
    section "第 5 段情境（會改動 $U 的 config.json，最後還原）"
    backup=$(mktemp); cp -p "$CFG" "$backup"
    set_cfg() { printf '%s\n' "$1" > "$CFG"; chown "$U:$U" "$CFG"; }
    try_cfg() {  # try_cfg <描述> <內容> <預期 log 片段>
        set_cfg "$2"
        usvc restart lab-app.service >/dev/null 2>&1
        wait_state failed 5
        grep -qF -- "$3" <<<"$(last_line)" && [ "$(state)" = failed ] \
            && pass "$1 → $3" || fail "$1 → 最後一筆：$(last_line)，狀態 $(state)"
    }

    set_cfg '{"enable": true}'
    usvc restart lab-app.service >/dev/null 2>&1
    wait_state active 5
    sleep 0.5
    grep -q 'INFO: started' <<<"$(tail -n 2 "$LOG")" && pass "改成 true 後 restart → INFO: started" \
        || fail "改成 true 後最後一筆：$(last_line)"
    [ "$(state)" = active ] && pass "狀態 active (running)" || fail "狀態 $(state)"
    [ "$(lab_json lesson service)" = ok ] && pass "lab --all：第 5 段 ✓" \
        || fail "lab --all：第 5 段是 $(lab_json lesson service)（$(lab_json lesson_notes service)）"
    h1=$(grep -c 'INFO: heartbeat' "$LOG"); sleep 11; h2=$(grep -c 'INFO: heartbeat' "$LOG")
    [ "$h2" -gt "$h1" ] && pass "heartbeat 持續增加（$h1 → $h2）" || fail "heartbeat 沒有增加"
    usvc stop lab-app.service >/dev/null 2>&1
    n1=$(wc -l < "$LOG"); sleep 6; n2=$(wc -l < "$LOG")
    [ "$n1" -eq "$n2" ] && pass "stop 後 log 不再增加" || fail "stop 後 log 仍在增加"

    try_cfg "壞 JSON（少右括號）" '{"enable": true' 'ERROR: invalid JSON in app/config.json (line 1)'
    try_cfg '"true" 字串' '{"enable": "true"}' 'ERROR: "enable" must be true or false (boolean)'
    try_cfg "大寫 True" '{"enable": True}' 'ERROR: "enable" must be true or false (boolean)'
    rm -f "$CFG"
    usvc restart lab-app.service >/dev/null 2>&1; wait_state failed 5
    grep -qF 'ERROR: app/config.json not found' <<<"$(last_line)" && pass "檔案不存在 → not found" \
        || fail "檔案不存在 → 最後一筆：$(last_line)"
    rc=$(usvc show -p ExecMainStatus --value lab-app.service)
    [ "$rc" = 78 ] && pass "結束碼 78" || fail "結束碼 $rc（預期 78）"

    # 還原：config 回到 false，服務再失敗一次，最後一筆回到 app is disabled
    cp -p "$backup" "$CFG"; rm -f "$backup"
    usvc restart lab-app.service >/dev/null 2>&1; wait_state failed 5
    grep -q 'app is disabled' <<<"$(last_line)" && [ "$(state)" = failed ] \
        && pass "已還原：failed + app is disabled" || fail "還原失敗：$(last_line)"
    echo "  （app.log 多了測試產生的行，開課前請重新產生預置檔）"
fi

# ------------------------------------------------------------------ fork 測試
if [ "$FORK" -eq 1 ]; then
    section "fork 測試（在 $U 嘗試開 $((LAB_TASKS_MAX + 100)) 個程序）"
    out=$(as_user systemd-run --user --quiet --wait --pipe python3 -c "
import os, signal, time
kids, failed = [], 0
for _ in range($LAB_TASKS_MAX + 100):
    try:
        pid = os.fork()
    except OSError:
        failed += 1
        continue
    if pid == 0:
        time.sleep(30); os._exit(0)
    kids.append(pid)
print(len(kids), failed)
for k in kids: os.kill(k, signal.SIGKILL)
for k in kids: os.waitpid(k, 0)
" 2>&1)
    read -r made failed <<<"$out"
    if [[ "${failed:-}" =~ ^[0-9]+$ ]] && [ "$failed" -gt 0 ]; then
        pass "$U 開到 $made 個就被擋下（$failed 次 fork 失敗）"
    else
        fail "沒有被 TasksMax 擋下：$out"
    fi
    if id "$OTHER" >/dev/null 2>&1; then
        check "$OTHER 不受影響，仍可執行 systemctl --user" \
            runuser -u "$OTHER" -- env XDG_RUNTIME_DIR="/run/user/$(id -u "$OTHER")" systemctl --user is-system-running
    fi
fi

# ------------------------------------------------------------------ challange 情境
if [ "$CHALLANGE" -eq 1 ]; then
    section "challange 情境（會動到 $U 的 ~/.challange，最後 lab --reset 還原）"
    ANS="/var/lib/lab/answers/$U.json"
    FLAG=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["flag"])' "$ANS")
    BONUS=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["bonus"])' "$ANS")
    dec() { as_user bash -c "cd '$CHAL' && ./decoder.sh" 2>&1; }
    no_leftover() { [ ! -e "$CHAL/flag.html" ] && [ -z "$(find "$CHAL" -name '.decoder.*')" ]; }

    lab --start "$U" >/dev/null 2>&1
    wait_for 5 pgrep -u "$U" -x evil-killer >/dev/null
    [ "$(usvc is-active evil-killer.service)" = active ] && pass "lab --start 後 evil-killer active" \
        || fail "lab --start 後 evil-killer 是 $(usvc is-active evil-killer.service)"
    check "pgrep -u $U -x evil-killer 找得到（程序名稱正確）" pgrep -u "$U" -x evil-killer
    if id "$OTHER" >/dev/null 2>&1; then
        pid=$(pgrep -u "$U" -x evil-killer | head -n 1)
        check "$OTHER 無法 kill $U 的 evil-killer" not runuser -u "$OTHER" -- kill "${pid:-0}"
    fi

    as_user chmod +x "$CHAL/decoder.sh"
    check "chmod +x 後 decoder.sh 有 x" test -x "$CHAL/decoder.sh"

    as_user ln -s /nonexistent "$CHAL/key.txt"
    out=$(dec)
    grep -q '讀不到密鑰檔' <<<"$out" && pass "符號連結斷掉 → 讀不到密鑰檔" || fail "符號連結斷掉 → $out"
    rm -f "$CHAL/key.txt"

    as_user bash -c "echo hi > '$CHAL/key.txt'; cat /lab/key.txt >> '$CHAL/key.txt'"
    out=$(dec)
    grep -q '密鑰不正確' <<<"$out" && no_leftover && pass "第一行不是密鑰 → 密鑰不正確，沒留下檔案" \
        || fail "第一行不是密鑰 → $out；$(ls -A "$CHAL" | tr '\n' ' ')"
    rm -f "$CHAL/key.txt"

    check "硬連結 ln /lab/key.txt 失敗（預期）" not as_user ln /lab/key.txt "$CHAL/key.txt"
    rm -f "$CHAL/key.txt"

    for how in cp 'cat >>' 'ln -s'; do
        rm -f "$CHAL/key.txt"
        case "$how" in
            cp) as_user cp /lab/key.txt "$CHAL/key.txt" ;;
            'cat >>') as_user bash -c "cat /lab/key.txt >> '$CHAL/key.txt'" ;;
            'ln -s') as_user ln -s /lab/key.txt "$CHAL/key.txt" ;;
        esac
        out=$(dec)
        if grep -q '\[成功\] 已解密到 ~/.challange/flag.html' <<<"$out" && wait_for 3 test ! -e "$CHAL/flag.html"; then
            pass "$how 放密鑰 → 解密成功，3 秒內 flag.html 被吃掉"
        else
            fail "$how 放密鑰 → $out；flag.html $( [ -e "$CHAL/flag.html" ] && echo 還在 || echo 不在)"
        fi
    done
    wait_for 3 evil_ok && pass "evil.txt 出現且內容正確" || fail "evil.txt：$(cat "$CHAL/evil.txt" 2>&1)"
    as_user rm -f "$CHAL/evil.txt"
    wait_for 3 evil_ok && pass "刪除 evil.txt → 恢復" || fail "刪除 evil.txt 後沒有恢復"
    as_user bash -c "echo hacked > '$CHAL/evil.txt'"
    wait_for 3 evil_ok && pass "修改 evil.txt → 蓋回原內容" || fail "修改 evil.txt 後沒有恢復"

    T="/tmp/lab-verify-$U"
    hist="$HOME_/.bash_history"; hist_bak=$(mktemp)
    had_hist=0; [ -f "$hist" ] && { cp -p "$hist" "$hist_bak"; had_hist=1; }
    as_user bash -c "
        mkdir -p '$T/a/b' '$HOME_/notes' '$HOME_/.lab'
        echo 'flag{verify}' > '$T/a/copy.txt'
        echo 'flag{verify}' > '$T/a/b/deep.txt'
        { head -c 1100000 /dev/zero | tr '\\0' a; echo 'flag{verify}'; } > '$T/big.txt'
        echo 'flag{verify}' > '$HOME_/notes/copy.txt'
        echo 'flag{verify}' > '$HOME_/.lab/keep'
        echo \"lab flag 'flag{verify}'\" >> '$hist'
    "
    sleep 3
    check "/tmp 深度 3 的 flag 被吃" test ! -e "$T/a/copy.txt"
    check "家目錄其他位置的 flag 被吃" test ! -e "$HOME_/notes/copy.txt"
    check "/tmp 深度 4 的不吃" test -e "$T/a/b/deep.txt"
    check "/tmp 大於 1 MB 的不吃" test -e "$T/big.txt"
    check "~/.lab/ 不吃" test -e "$HOME_/.lab/keep"
    check "~/.bash_history 不吃" test -e "$hist"
    rm -rf "$T" "$HOME_/notes" "$HOME_/.lab"
    if [ "$had_hist" -eq 1 ]; then cp -p "$hist_bak" "$hist"; else rm -f "$hist"; fi
    rm -f "$hist_bak"

    usvc disable evil-killer.service >/dev/null 2>&1
    sleep 1
    check "systemctl --user disable 之後仍在執行（stop 與 disable 的差別）" pgrep -u "$U" -x evil-killer
    t0=$(date +%s%N)
    usvc stop evil-killer.service >/dev/null 2>&1
    ms=$(( ($(date +%s%N) - t0) / 1000000 ))
    [ "$ms" -lt 3000 ] && [ "$(usvc is-active evil-killer.service)" != active ] \
        && pass "systemctl --user stop 在 ${ms} ms 內停止" || fail "stop 花了 ${ms} ms，狀態 $(usvc is-active evil-killer.service)"
    check "停止後沒有 evil-killer 程序" not pgrep -u "$U" -x evil-killer
    as_user rm -f "$CHAL/evil.txt"
    sleep 2
    check "停止後刪 evil.txt 不再出現" test ! -e "$CHAL/evil.txt"
    out=$(dec)
    sleep 2
    grep -q '\[成功\]' <<<"$out" && grep -qF -- "$FLAG" "$CHAL/flag.html" 2>/dev/null \
        && pass "停止後再解密，flag.html 保留且內容是正確的 flag" || fail "停止後再解密：$out"
    check "flag.html 為 644" bash -c "[ \"\$(stat -c %a '$CHAL/flag.html')\" = 644 ]"
    check "flag.html 含 bonus 的 box-shadow 像素" grep -q 'box-shadow' "$CHAL/flag.html"

    check "lab flag 錯的被拒" not as_user lab flag 'flag{wrong}'
    check "lab flag 正確" as_user lab flag "$FLAG"
    check "lab bonus 錯的被拒" not as_user lab bonus XXXXX
    check "lab bonus 小寫也算對" as_user lab bonus "${BONUS,,}"
    [ "$(lab_json challange flag)" = ok ] && [ "$(lab_json challange bonus)" = ok ] \
        && pass "lab --all：flag、bonus 都是 ✓" \
        || fail "lab --all：flag=$(lab_json challange flag) bonus=$(lab_json challange bonus)"
    found=$(grep -rlF --exclude=.bash_history -- "$MARK" "$HOME_" 2>/dev/null | grep -v "^$HOME_/.lab/\|^$CHAL/flag.html$")
    [ -z "$found" ] && pass "家目錄只有 flag.html 與 ~/.lab 含 flag 標記" || fail "其他含 flag 標記的檔案：$found"

    lab --start "$U" >/dev/null 2>&1
    wait_for 5 pgrep -u "$U" -x evil-killer >/dev/null
    lab --stop >/dev/null 2>&1
    sleep 1
    check "lab --stop 後全部學員都沒有 evil-killer" not pgrep -x evil-killer

    lab --reset "$U" >/dev/null 2>&1
    got=$(ls -A "$CHAL" 2>/dev/null | sort | tr '\n' ' ')
    [ "$got" = "README.txt decoder.sh " ] && pass "lab --reset 後 ~/.challange 回到初始狀態" \
        || fail "lab --reset 後 ~/.challange：$got"
    check "lab --reset 後 decoder.sh 為 444" bash -c "[ \"\$(stat -c %a '$CHAL/decoder.sh')\" = 444 ]"
    check "lab --reset 後 ~/.lab 已清掉" test ! -e "$HOME_/.lab"
    new_flag=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["flag"])' "$ANS")
    [ "$new_flag" != "$FLAG" ] && pass "lab --reset 產生新的 flag" || fail "lab --reset 後 flag 沒變"
    check "lab --reset 後 evil-killer 沒在執行" not pgrep -u "$U" -x evil-killer
fi

# ------------------------------------------------------------------ 教學檢查點偵測
if [ "$PROGRESS" -eq 1 ]; then
    section "教學檢查點偵測（會動到 $U 的 ~/.ssh、~/reports，最後刪掉）"
    if [ -e "$HOME_/.ssh" ] || [ -e "$HOME_/reports" ]; then
        fail "$U 已有 ~/.ssh 或 ~/reports，略過（避免蓋掉學員的東西；先 setup.sh --reseed 或換 --user）"
    else
        kd=$(mktemp -d)
        ssh-keygen -q -t ed25519 -N '' -f "$kd/id" -C lab-verify
        install -d -m 700 -o "$U" -g "$U" "$HOME_/.ssh"
        install -m 600 -o "$U" -g "$U" "$kd/id.pub" "$HOME_/.ssh/authorized_keys"
        [ "$(lab_json lesson key)" = part ] && pass "放好 authorized_keys → 第 2 段 △" \
            || fail "放好 authorized_keys → 第 2 段是 $(lab_json lesson key)（$(lab_json lesson_notes key)）"
        SO=(-i "$kd/id" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
        check "金鑰 ssh $U@localhost 成功" ssh "${SO[@]}" "$U@localhost" true
        sleep 1
        [ "$(lab_json lesson login)" = ok ] && pass "lab --all：第 1 段 ✓" || fail "lab --all：第 1 段是 $(lab_json lesson login)"
        [ "$(lab_json lesson key)" = ok ] && pass "lab --all：第 2 段 ✓（journal 有 Accepted publickey）" \
            || fail "lab --all：第 2 段是 $(lab_json lesson key)"
        as_user bash -c "mkdir -p ~/reports && grep ERROR ~/.log/app.log > ~/reports/error.txt"
        [ "$(lab_json lesson report)" = part ] && pass "~/reports/error.txt 做好 → 第 3 段 △" \
            || fail "~/reports/error.txt 做好 → 第 3 段是 $(lab_json lesson report)"
        check "sftp 下載 ~/reports/error.txt 成功" \
            bash -c "sftp $(printf '%q ' "${SO[@]}") -b - '$U@localhost' <<<'get reports/error.txt $kd/'"
        sleep 1
        if [ "$SFTP_LOG" -eq 1 ]; then
            [ "$(lab_json lesson report)" = ok ] && pass "lab --all：第 3 段 ✓（偵測到下載）" \
                || fail "lab --all：第 3 段是 $(lab_json lesson report)（journal 裡沒有 sftp 的 open 紀錄？）"
        else
            echo "  NOTE sftp 下載偵測停用（見 SSH 段），略過第 3 段 ✓ 的檢查"
        fi
        rm -rf "$HOME_/.ssh" "$HOME_/reports" "$kd"
        echo "  （journal 已有 $U 的登入與下載紀錄，計分板會一直顯示 ✓，開課前請 setup.sh --reseed 重設基準時間）"
    fi
fi

printf '\n\033[1m結果：%d PASS，%d FAIL\033[0m\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
