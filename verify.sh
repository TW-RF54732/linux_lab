#!/usr/bin/env bash
# Linux Server 社課 lab：在 CT 內以 root 跑「開課前驗證清單」中能自動化的部分。
#
# 用法：
#   ./verify.sh                      # 檢查 lab01 的初始狀態、權限、SSH、資源限制設定
#   ./verify.sh --user lab05         # 改用其他測試帳號
#   ./verify.sh --scenarios          # 另外跑第 5 段的修復情境（改 true / 壞 JSON / "true" …），結束後還原
#   ./verify.sh --fork-test          # 另外在測試帳號實際超過 TasksMax，確認只影響自己
#
# 需要從學員網段外部電腦手動確認的項目（密碼登入、公鑰登入、多人同時登入）見 README。

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lab.conf
source "$HERE/lab.conf"

WIDTH=$(( ${#LAB_COUNT} < 2 ? 2 : ${#LAB_COUNT} ))
U=$(printf '%s%0*d' "$LAB_PREFIX" "$WIDTH" 1)
OTHER=$(printf '%s%0*d' "$LAB_PREFIX" "$WIDTH" 2)
SCENARIOS=0
FORK=0
while [ $# -gt 0 ]; do
    case "$1" in
        --user) U=$2; shift ;;
        --scenarios) SCENARIOS=1 ;;
        --fork-test) FORK=1 ;;
        -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done
[ "$OTHER" = "$U" ] && OTHER=$(printf '%s%0*d' "$LAB_PREFIX" "$WIDTH" 1)

PASS=0; FAIL=0
pass() { printf '  \033[32mPASS\033[0m %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; FAIL=$((FAIL + 1)); }
check() { local desc=$1; shift; if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi; }
section() { printf '\n\033[1m%s\033[0m\n' "$*"; }

[ "$(id -u)" -eq 0 ] || { echo "請用 root 執行" >&2; exit 1; }
id "$U" >/dev/null 2>&1 || { echo "帳號 $U 不存在" >&2; exit 1; }
UID_=$(id -u "$U")
HOME_=$(getent passwd "$U" | cut -d: -f6)
LOG="$HOME_/.log/app.log"
CFG="$HOME_/.config/app/config.json"

as_user() { runuser -u "$U" -- env HOME="$HOME_" XDG_RUNTIME_DIR="/run/user/$UID_" "$@"; }
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

# ------------------------------------------------------------------ SSH
section "SSH"
eff=$(sshd -T 2>/dev/null)
for kv in "passwordauthentication yes" "pubkeyauthentication yes" "permitrootlogin no" "usepam yes"; do
    grep -qx "$kv" <<<"$eff" && pass "$kv" || fail "$kv（目前：$(grep "^${kv%% *} " <<<"$eff")）"
done
grep -qi "^allowgroups .*labusers" <<<"$eff" && pass "$(grep -i '^allowgroups' <<<"$eff")" || fail "AllowGroups 未含 labusers"
pass "$(grep -i '^maxstartups' <<<"$eff")"
check "sshd 在 22 port 監聽" bash -c "ss -Hltn | grep -qE ':22\\b'"
check "ssh 服務運作中（ssh.service 或 ssh.socket）" bash -c "systemctl is-active --quiet ssh.service || systemctl is-active --quiet ssh.socket"
check "127.0.0.1:22 回應 SSH banner" bash -c "timeout 3 bash -c 'exec 3<>/dev/tcp/127.0.0.1/22 && head -n1 <&3' | grep -q '^SSH-'"
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

printf '\n\033[1m結果：%d PASS，%d FAIL\033[0m\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
