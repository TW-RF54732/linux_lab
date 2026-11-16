# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Two independent deliverables for a Linux Server club course (all docs, comments and user-facing strings are Traditional Chinese — keep it that way):

1. **Lab environment** — bash + Python scripts that provision an Ubuntu 24.04 Proxmox CT (unprivileged LXC, `nesting=1`) with N student accounts, a broken-on-purpose `lab-app` systemd user service, seeded logs/configs, SSH config and per-user cgroup limits. Students practice: read log → find ERROR → fix `~/.config/app/config.json` → restart service.
2. **Docs site** (`site/`) — student-facing reference built by a zero-dependency Node script into `dist/` and deployed to GitHub Pages.

The source of truth for requirements is `docs/Linux Server 社課 Lab 環境需求規格.md` (spec) and `docs/Linux Server 社課 教學流程（講師版）.md` (instructor flow; "第 N 段" = section N of the lesson). Intentional deviations from the spec are tabled in README.md ("和規格不同或補充的地方") — update that table when you diverge further.

## Commands

Docs site (Node ≥ 20, no `npm install` needed):

```bash
node scripts/build-site.mjs      # build site/ → dist/; fails on broken internal links or #anchors
npm run preview:site             # build + serve http://127.0.0.1:4173 (404 behaves like GitHub Pages)
```

`.claude/launch.json` has a `docs` preview config (serves an already-built `dist/` on 4173 — run the build first).

Lab scripts only run **inside the CT as root** (they need systemd, logind, sshd); they cannot be exercised on this Windows dev machine. There is no test suite; `verify.sh` is the acceptance check:

```bash
./setup.sh                 # idempotent deploy; existing students' seed files untouched
./setup.sh --reseed        # regenerate every student's ~/.log, ~/.config and service state
./verify.sh                # check lab01: perms, home contents, service failed, sshd -T, cgroup limits
./verify.sh --user lab05 --scenarios --fork-test   # also run lesson-5 fix scenarios / TasksMax fork bomb
CTID=240 IP=192.168.10.50/24 GW=192.168.10.1 ./proxmox/create-ct.sh   # on the Proxmox host
```

`lab-seed` can be run locally for testing without root/chown: `python3 files/lab-seed --home /tmp/x --now "2026-11-21 14:00:00"`.

## Architecture: lab environment

- `lab.conf` is sourced by both `setup.sh` and `verify.sh` (student count/prefix, admins, TZ, seed, resource limits, sshd MaxStartups, roster path).
- `setup.sh` installs `files/lab-app` → `/opt/lab/lab-app`, `files/lab-app.service` → `/etc/systemd/user/` (enabled `--global`), `files/lab-seed` → `/opt/lab/admin/lab-seed`, writes `user-.slice.d/lab.conf` and `sshd_config.d/00-lab.conf` (validated with `sshd -t`/`-T` before restart), creates `labNN` users, then `init_user` per student.
- **Initial-state trick**: `lab-seed` writes `app.log` *without* the final ERROR, then setup actually starts `lab-app` as the student so the daemon itself appends `ERROR: app is disabled …` and exits 78 (EX_CONFIG), leaving the unit `failed`. Don't fake this by writing the line directly.
- `lab-app` (stdlib-only Python) reads `~/.config/app/config.json`; `enable: true` → `INFO: started` + heartbeat every 5 s; anything else → one ERROR line + exit 78. `Restart=no` and `ConditionGroup=labusers` are deliberate (failure must stay visible; admins' user managers must not run it).
- Groups: students in `labusers`, admins in `labadmins`; sshd `AllowGroups labusers labadmins`; root cannot SSH.
- `lab-seed` is deterministic from `LAB_SEED`; only timestamps shift (anchored to `--now`). Other logs deliberately contain no uppercase `ERROR`, and `~/.config` has decoy dirs (one with `"enable": false`) whose names don't contain `app` — preserve these properties, the lesson depends on them.

**Cross-file coupling**: `lab-app`'s exact ERROR strings are asserted in `verify.sh` (`--scenarios`), reproduced in `files/lab-seed` (`FINAL_ERROR`), and documented for students in `site/content/environment/lab-app.md`. Change all of them together.

LXC gotchas (details in README): without `nesting=1`, logind/`user@.service` fail ("Failed to connect to bus"); testing as a student must use `ssh labNN@localhost` or set `XDG_RUNTIME_DIR` (scripts use `runuser` + explicit `XDG_RUNTIME_DIR`).

## Architecture: docs site

- `scripts/build-site.mjs` implements its own Markdown *subset* — only the syntax listed in `site/README.md` works (no nested lists; `##` headings require `{#id}`; fenced block kinds `command`/`output`/`config`/`reference`; `[[Key]]`, `{lab}`/`{lab:N}` tags, `{{index}}`; GitHub-style `> [!NOTE]` callouts). Extending syntax means editing the build script.
- A page = `site/content/<slug>.md` with frontmatter (`title`, `description` required) **plus** an entry in `site/site.json` `nav` (which also defines prev/next order). The build iterates `site.json`, not the filesystem: a `.md` not listed there is silently not built; a slug listed twice is an error.
- Internal links are written root-absolute (`/commands/ls/#basics`) and rewritten to relative URLs at build time; only `404.html` uses `site.json` `base`.
- Command pages follow a fixed section order: `常用 {#basics}` → `進階 {#advanced}` → `範例 {#examples}` → optional `常見錯誤 {#errors}`. Aim for beginner usefulness, not completeness.
- CI (`.github/workflows/pages.yml`) builds on PRs and deploys on `main` when `site/**` or the build script changes.

`.gitattributes` forces LF — shell/Python files are executed in Linux, so never introduce CRLF.
