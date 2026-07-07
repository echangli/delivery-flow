#!/usr/bin/env bash
#
# SessionStart hook — report plugin freshness at session start.
#
# Up to date  => confirm in one short line, including the installed version's commit date.
# Out of date => the agent OFFERS to run the update itself (shell `claude plugin update`),
#                then asks the user to restart; falls back to a how-to if it has no shell.
#
# Why: for third-party (git) marketplaces, Claude Code's autoUpdate pulls the marketplace
# clone but does NOT roll the installed plugin forward, and a restart does not reliably fix
# it, so teammates end up running a stale plugin. This hook detects the gap and tells the
# user how to update. It only NOTIFIES — the fix is manual `claude plugin update` + restart.
#
# IMPORTANT: the fix is a SHELL command (`claude plugin update …`), NOT the slash-command
# `/plugin update …` typed inside Claude Code — the slash form only opens the plugin menu
# and does not update. And an update needs a full restart (`/reload-plugins` is not enough).
#
# Generic: plugin name, marketplace name and installed SHA are all derived from
# CLAUDE_PLUGIN_ROOT, so this exact file works in every variant of the plugin.
#
# Fail-silent by design: any error / missing clone / offline / timeout => exit 0 with no
# output, so session startup is never broken. Targets bash 3.2 (macOS system bash).

set -u

root="${CLAUDE_PLUGIN_ROOT:-}"
[ -n "$root" ] || exit 0

# --- derive identifiers from the install path (pure bash, no external tools) ---
# CLAUDE_PLUGIN_ROOT = <plugins>/cache/<marketplace>/<plugin>/<installed_sha>
installed_sha="${root##*/}"
d1="${root%/*}";  plugin="${d1##*/}"
d2="${d1%/*}";    marketplace="${d2##*/}"
d3="${d2%/*}";    plugins_dir="${d3%/*}"
clone="$plugins_dir/marketplaces/$marketplace"

# git is required for the comparison; without it, stay silent.
command -v git >/dev/null 2>&1 || exit 0

# --- resolve the latest available SHA, capped so a hung network can't block startup ---
remote_latest() {
  local secs=3 out="" tmp
  if command -v timeout >/dev/null 2>&1; then
    out="$(timeout "$secs" git -C "$clone" ls-remote origin HEAD 2>/dev/null)"
  elif command -v gtimeout >/dev/null 2>&1; then
    out="$(gtimeout "$secs" git -C "$clone" ls-remote origin HEAD 2>/dev/null)"
  else
    # No timeout(1): background git into a temp file and kill it with a watchdog.
    tmp="$(mktemp 2>/dev/null || mktemp -t pvc)" || return 0
    git -C "$clone" ls-remote origin HEAD >"$tmp" 2>/dev/null &
    local pid=$!
    ( sleep "$secs"; kill -9 "$pid" 2>/dev/null ) >/dev/null 2>&1 &
    local wpid=$!
    wait "$pid" 2>/dev/null
    kill "$wpid" 2>/dev/null; wait "$wpid" 2>/dev/null
    out="$(head -n1 "$tmp" 2>/dev/null)"
    rm -f "$tmp"
  fi
  printf '%s' "${out%%$'\t'*}"
}

# Primary: true latest from the remote (reuses the clone's configured credentials).
latest="$(remote_latest)"
# Fallback: local clone HEAD (offline / VPN off / stale creds).
[ -n "$latest" ] || latest="$(git -C "$clone" rev-parse HEAD 2>/dev/null)"

[ -n "$latest" ] || exit 0

installed_short="${installed_sha:0:7}"

# --- up to date when the installed sha is a prefix of the full latest sha ---
# Confirm freshness (with the installed version's commit date) instead of staying silent.
case "$latest" in
  "$installed_sha"*)
    # commit date of the installed version, read from the marketplace clone (best-effort)
    version_date="$(git -C "$clone" show -s --format=%cd --date=short "$installed_sha" 2>/dev/null)"
    if [ -n "$version_date" ]; then
      ok_msg="The «${plugin}» plugin is up to date — latest version from ${version_date} (${installed_short}). At the very START of your first reply this session, tell the user, in their language, in ONE short friendly line that their «${plugin}» plugin is current and include that date (${version_date}). Output only that single line — do not turn it into a task or add anything else."
    else
      ok_msg="The «${plugin}» plugin is up to date (${installed_short}). At the very START of your first reply this session, tell the user, in their language, in ONE short friendly line that their «${plugin}» plugin is current. Output only that single line — do not turn it into a task or add anything else."
    fi
    printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$ok_msg"
    exit 0
    ;;
esac

latest_short="${latest:0:7}"
mp_cmd="claude plugin marketplace update ${marketplace}"
up_cmd="claude plugin update ${plugin}@${marketplace}"

# --- emit the nudge as SessionStart additionalContext (the model relays it) ---
# No double quotes / backslashes in the message => valid JSON without escaping.
msg="IMPORTANT — a plugin update is available. The «${plugin}» plugin is out of date (installed ${installed_short}, latest ${latest_short}). At the very START of your first reply this session, tell the user this in their language, then OFFER to do the update yourself — these are plain SHELL commands you can run with your terminal/Bash tool, not something the user must type. With the user's go-ahead (or right away if they clearly want it), run «${mp_cmd}» then «${up_cmd}», then tell the user to FULLY RESTART Claude Code to apply — a restart is required, you cannot restart it yourself and /reload-plugins is not enough. If you cannot run shell commands here, or they fail (e.g. no network/VPN to the marketplace), FALL BACK to a short numbered how-to for the user: (1) open the app «Terminal»; (2) run «${mp_cmd}»; (3) run «${up_cmd}»; (4) restart Claude Code. Keep it short. NEVER tell the user to type «/plugin update» inside Claude Code — that only opens a menu and does NOT update."

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$msg"
exit 0
