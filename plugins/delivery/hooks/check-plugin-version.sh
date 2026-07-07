#!/usr/bin/env bash
#
# SessionStart hook — warn when the installed plugin version lags the marketplace.
#
# Why: for third-party (git) marketplaces, Claude Code's autoUpdate pulls the marketplace
# clone but does NOT roll the installed plugin forward, and a restart does not reliably fix
# it, so teammates end up running a stale plugin. This hook detects the gap and tells the
# user how to update. It only NOTIFIES — the fix is a manual `/plugin update` + restart.
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

# --- up to date when the installed sha is a prefix of the full latest sha ---
case "$latest" in
  "$installed_sha"*) exit 0 ;;
esac

installed_short="${installed_sha:0:7}"
latest_short="${latest:0:7}"
update_cmd="/plugin update ${plugin}@${marketplace}"

# --- emit the nudge as SessionStart additionalContext (the model relays it) ---
# No double quotes / backslashes in the message => valid JSON without escaping.
msg="IMPORTANT — a plugin update is available. The «${plugin}» plugin is out of date (installed ${installed_short}, latest ${latest_short}). At the very START of your first reply this session, show the user — in their language — a SHORT, friendly, numbered how-to written for a COMPLETE BEGINNER. Make crystal clear this is done in a terminal, and that «${update_cmd}» is a Claude Code command typed INSIDE Claude Code (not a plain shell/Terminal command). Use exactly these steps, one per line: (1) open the app «Terminal»; (2) type «claude» and press Enter — Claude Code starts; (3) type «${update_cmd}» and press Enter, then wait until it finishes; (4) close Claude Code and open it again so the new version loads. Output only one short intro line plus the 4 numbered steps — nothing else."

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$msg"
exit 0
