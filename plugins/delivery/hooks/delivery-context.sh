#!/usr/bin/env bash
#
# Shared gate for the delivery plugin's session/prompt hooks.
#
# in_delivery_context succeeds (returns 0) only when the current project is one where you
# actually run this delivery flow. The version-check (SessionStart) and language-reminder
# (UserPromptSubmit) hooks source this file and run `in_delivery_context || exit 0` up front,
# so the plugin stays completely silent in unrelated projects on the same machine.
#
# Why: the plugin installs at user scope, so without this gate its hooks fire in every session
# and every prompt of every project. Claude Code has no native per-directory hook matcher, and
# disabling the plugin per project would also hide its skills/commands — so the hooks self-scope.
#
# Detection is fail-closed: only a positive signal enables the hooks. Signals, cheapest first:
# explicit opt-out (env / marker) -> explicit opt-in marker -> project-path match -> git-remote
# match. Out of the box only the opt-in marker and this plugin's own repo match; adapt the path
# and remote patterns below to your repo so auto-detection works without a marker. Pure bash 3.2,
# no jq, git optional.

# Walk from $1 up to "/" looking for an entry named $2; return 0 as soon as one is found.
_dc_find_marker_up() {
  local d="$1" name="$2"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    [ -e "$d/$name" ] && return 0
    d="${d%/*}"
  done
  return 1
}

in_delivery_context() {
  local dir="${CLAUDE_PROJECT_DIR:-$PWD}"

  # 1. Explicit opt-out wins everywhere.
  [ "${DELIVERY_FLOW_QUIET:-}" = "1" ] && return 1
  _dc_find_marker_up "$dir" ".delivery-flow-off" && return 1

  # 2. Explicit opt-in marker — the simplest way to turn the hooks on for a project
  #    (drop an empty file named .delivery-flow at the project root, or let the setup skill do it).
  _dc_find_marker_up "$dir" ".delivery-flow" && return 0

  # 3. Path signal: a component of the project path matches one of your workspace folder names.
  #    ⟪ADAPT: replace "delivery-flow" with a lowercase substring of the folder name(s) of the
  #    workspace(s) where you run this flow, e.g. your product/repo slug. Add more *…* patterns.⟫
  case "$(printf '%s' "$dir" | tr '[:upper:]' '[:lower:]')" in
    *delivery-flow*) return 0 ;;
  esac

  # 4. Git-remote signal: a configured remote points at a repo you deliver to.
  #    ⟪ADAPT: replace "delivery-flow" with a lowercase substring of your git remote(s),
  #    e.g. "your-org/your-repo". Add more *…* patterns as needed.⟫
  if command -v git >/dev/null 2>&1; then
    case "$(git -C "$dir" remote -v 2>/dev/null | tr '[:upper:]' '[:lower:]')" in
      *delivery-flow*) return 0 ;;
    esac
  fi

  return 1
}
