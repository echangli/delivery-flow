#!/usr/bin/env bash
# verify-stage-deploy.sh — Phase 2 "what is REALLY deployed on the shared stage" via the GitLab API.
#
# WHY: backend services roll onto the shared stage independently (job "Deploy Stage" from a release tag
# or an MR pipeline), so "gargantua is fresh but forex-deals is stale" is a normal state, not a
# hypothesis. Testing against a stale service yields a false PASS/FAIL. This script makes the check
# mechanical instead of something the agent must remember. Read-only: GET requests only.
#
# Written for GitLab CI (jobs API). ⟪ADAPT: on another git host / CI rewrite latest_deploy() and
# resolve_sha() against your API (GitHub Actions/Deployments, Jenkins, ArgoCD …); the verdict logic is generic⟫.
#
# USAGE
#   verify-stage-deploy.sh <svc>[:<branch|tag|sha>] ...
#     svc   = project name inside $GITLAB_GROUP (e.g. orders) or a full path (group/sub/project)
#     ref   = what you EXPECT on stage (feature branch, release tag or commit sha); omitted → just report
#   Examples:
#     verify-stage-deploy.sh orders:master gateway:1a2b3c4d
#     DEPLOY_JOB='Deploy Prod' verify-stage-deploy.sh orders            # what is on prod (report only)
#
# ENV
#   GIT_API_TOKEN     required (read scope is enough); keep it in your shell profile, never in files of the task
#                     (GITLAB_API_TOKEN is accepted as a fallback)
#   GITLAB_HOST       required, e.g. gitlab.example.com
#   GITLAB_GROUP      required, e.g. team/backend
#   DEPLOY_JOB        default 'Deploy Stage' (exact job name)
#   REPOS_DIR         directory with local clones (<REPOS_DIR>/<svc>); enables the ancestor check.
#                     Default: parent of the current directory.
#   PAGES             how many pages of 100 successful jobs to scan for the deploy job (default 5)
#
# VERDICTS (per service)
#   ✅ deployed == expected           exact sha / ref match
#   ✅ expected ⊂ deployed            expected commit is an ancestor of the deployed one (stage is ahead)
#   ❌ STALE                          deployed commit is an ancestor of expected → stage is behind
#   ❌ OTHER LINE                     neither contains the other → a different branch is on stage
#   ❓ cannot compare                 no local clone / sha unresolvable → equality check only
#
# EXIT: 0 all expected refs present on stage · 1 at least one ❌ · 2 usage/config error
set -uo pipefail

GITLAB_API_TOKEN="${GIT_API_TOKEN:-${GITLAB_API_TOKEN:-}}"
GITLAB_HOST="${GITLAB_HOST:-}"
GITLAB_GROUP="${GITLAB_GROUP:-}"
DEPLOY_JOB="${DEPLOY_JOB:-Deploy Stage}"
REPOS_DIR="${REPOS_DIR:-$(cd .. 2>/dev/null && pwd)}"
PAGES="${PAGES:-5}"
API="https://${GITLAB_HOST}/api/v4"

die() { printf 'verify-stage-deploy: %s\n' "$1" >&2; exit "$2"; }
[ "$#" -ge 1 ] || die "usage: verify-stage-deploy.sh <svc>[:<ref>] ..." 2
[ -n "${GITLAB_API_TOKEN:-}" ] || die "GIT_API_TOKEN is empty — export it in your shell profile (read scope)" 2
[ -n "$GITLAB_HOST" ] || die "GITLAB_HOST is empty — set it to your GitLab host (see the header)" 2
[ -n "$GITLAB_GROUP" ] || die "GITLAB_GROUP is empty — set it to your backend group path (see the header)" 2
command -v jq >/dev/null 2>&1 || die "jq is required" 2

api() { curl -sS -m 30 -H "PRIVATE-TOKEN: ${GITLAB_API_TOKEN}" "${API}$1"; }
urlenc() { printf '%s' "$1" | sed 's#/#%2F#g'; }

# newest successful job named $DEPLOY_JOB → "ref<TAB>sha<TAB>finished_at<TAB>pipeline_id" or empty
latest_deploy() {
  local proj="$1" page=1 out=""
  while [ "$page" -le "$PAGES" ]; do
    out="$(api "/projects/${proj}/jobs?scope[]=success&per_page=100&page=${page}" \
      | jq -r --arg n "$DEPLOY_JOB" '[.[] | select(.name == $n)][0] // empty
              | [.ref, .commit.id, .finished_at, (.pipeline.id|tostring)] | @tsv' 2>/dev/null)"
    [ -n "$out" ] && { printf '%s\n' "$out"; return 0; }
    page=$((page + 1))
  done
  return 1
}

resolve_sha() {  # <proj> <ref> → full sha (or empty)
  local proj="$1" ref="$2"
  if printf '%s' "$ref" | grep -Eq '^[0-9a-f]{7,40}$'; then printf '%s' "$ref"; return 0; fi
  api "/projects/${proj}/repository/commits/$(urlenc "$ref")" | jq -r '.id // empty'
}

fail=0; checked=0
printf '%-22s %-14s %-44s %-10s %-20s %s\n' "SERVICE" "JOB" "DEPLOYED (ref @ sha)" "EXPECTED" "FINISHED" "VERDICT"
for arg in "$@"; do
  svc="${arg%%:*}"; want="${arg#*:}"; [ "$want" = "$arg" ] && want=""
  case "$svc" in */*) path="$svc"; name="${svc##*/}";; *) path="${GITLAB_GROUP}/${svc}"; name="$svc";; esac
  proj="$(urlenc "$path")"

  if ! dep="$(latest_deploy "$proj")"; then
    printf '%-22s %-14s %-44s %-10s %-20s %s\n' "$name" "$DEPLOY_JOB" "<none in last $((PAGES*100)) ok jobs>" "${want:--}" "-" "❓ no deploy job found"
    [ -n "$want" ] && fail=1
    continue
  fi
  dref="$(printf '%s' "$dep" | cut -f1)"; dsha="$(printf '%s' "$dep" | cut -f2)"
  dfin="$(printf '%s' "$dep" | cut -f3 | cut -c1-19)"
  shown="${dref} @ ${dsha:0:8}"

  if [ -z "$want" ]; then
    printf '%-22s %-14s %-44s %-10s %-20s %s\n' "$name" "$DEPLOY_JOB" "$shown" "-" "$dfin" "ℹ️ report only"
    continue
  fi

  checked=$((checked + 1))
  wsha="$(resolve_sha "$proj" "$want")"
  if [ -z "$wsha" ]; then
    printf '%-22s %-14s %-44s %-10s %-20s %s\n' "$name" "$DEPLOY_JOB" "$shown" "$want" "$dfin" "❓ expected ref unresolvable"
    fail=1; continue
  fi
  wshort="${wsha:0:8}"

  if [ "${dsha#"$wsha"}" != "$dsha" ] || [ "${wsha#"$dsha"}" != "$wsha" ]; then
    printf '%-22s %-14s %-44s %-10s %-20s %s\n' "$name" "$DEPLOY_JOB" "$shown" "$wshort" "$dfin" "✅ deployed == expected"
    continue
  fi

  repo="${REPOS_DIR}/${name}"
  if [ -d "$repo/.git" ]; then
    for s in "$dsha" "$wsha"; do
      git -C "$repo" cat-file -e "${s}^{commit}" 2>/dev/null || git -C "$repo" fetch -q origin 2>/dev/null || true
    done
    if git -C "$repo" cat-file -e "${dsha}^{commit}" 2>/dev/null && git -C "$repo" cat-file -e "${wsha}^{commit}" 2>/dev/null; then
      if git -C "$repo" merge-base --is-ancestor "$wsha" "$dsha"; then
        printf '%-22s %-14s %-44s %-10s %-20s %s\n' "$name" "$DEPLOY_JOB" "$shown" "$wshort" "$dfin" "✅ expected ⊂ deployed (stage ahead by $(git -C "$repo" rev-list --count "${wsha}..${dsha}"))"
      elif git -C "$repo" merge-base --is-ancestor "$dsha" "$wsha"; then
        printf '%-22s %-14s %-44s %-10s %-20s %s\n' "$name" "$DEPLOY_JOB" "$shown" "$wshort" "$dfin" "❌ STALE — stage behind by $(git -C "$repo" rev-list --count "${dsha}..${wsha}") commit(s)"
        fail=1
      else
        printf '%-22s %-14s %-44s %-10s %-20s %s\n' "$name" "$DEPLOY_JOB" "$shown" "$wshort" "$dfin" "❌ OTHER LINE — a different branch is deployed"
        fail=1
      fi
      continue
    fi
  fi
  printf '%-22s %-14s %-44s %-10s %-20s %s\n' "$name" "$DEPLOY_JOB" "$shown" "$wshort" "$dfin" "❓ sha differs; no local clone at $repo for an ancestor check"
  fail=1
done

if [ "$fail" -ne 0 ]; then
  printf '\n❌ At least one service is NOT verified on its expected code. Do not run the matrix against it —\n   results would be a false PASS/FAIL. Ask for a (re)deploy or fix the expected ref, then re-run.\n' >&2
  exit 1
fi
if [ "$checked" -eq 0 ]; then
  printf '\nℹ️ Report only (no expected refs given). Pass svc:<ref> to get a verdict.\n'
else
  printf '\n✅ Every expected ref is on %s. Re-run before each run phase and on sudden mass 5xx (drift).\n' "$DEPLOY_JOB"
fi
