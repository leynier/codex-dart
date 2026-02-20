#!/usr/bin/env bash
set -euo pipefail

readonly MARKER="<!-- codex-sdk-sync:typescript -->"
readonly LABEL="upstream-sync"
readonly UPSTREAM_URL="https://github.com/openai/codex.git"
readonly UPSTREAM_SCOPE="sdk/typescript"

readonly FILES_LIMIT=200
readonly COMMITS_LIMIT=200
readonly PATCH_LIMIT=400

readonly REPO="${GITHUB_REPOSITORY:-leynier/codex-dart}"
FORCE_CHECK="${FORCE_CHECK:-false}"
OVERRIDE_NEW_VERSION="${OVERRIDE_NEW_VERSION:-}"
DRY_RUN="${DRY_RUN:-false}"

FORCE_CHECK="$(printf "%s" "${FORCE_CHECK}" | tr "[:upper:]" "[:lower:]")"
DRY_RUN="$(printf "%s" "${DRY_RUN}" | tr "[:upper:]" "[:lower:]")"

is_true() {
  case "$1" in
    1 | true | yes | on) return 0 ;;
    *) return 1 ;;
  esac
}

require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "error: required command not found: ${cmd}" >&2
    exit 1
  fi
}

require_command git
require_command gh
require_command jq
require_command npm
require_command awk
require_command sed

if ! gh auth status >/dev/null 2>&1; then
  echo "error: gh authentication is required." >&2
  exit 1
fi

if [[ ! -f "pubspec.yaml" ]]; then
  echo "error: pubspec.yaml not found in current directory." >&2
  exit 1
fi

dart_current_version="$(awk -F': *' '/^version:/{print $2; exit}' pubspec.yaml | tr -d '[:space:]')"
if [[ -z "${dart_current_version}" ]]; then
  echo "error: unable to read version from pubspec.yaml." >&2
  exit 1
fi

if [[ -n "${OVERRIDE_NEW_VERSION}" ]]; then
  npm_latest_version="${OVERRIDE_NEW_VERSION}"
else
  npm_latest_version="$(npm view @openai/codex-sdk version 2>/dev/null | tr -d '[:space:]')"
  if [[ -z "${npm_latest_version}" ]]; then
    echo "error: unable to query npm latest version for @openai/codex-sdk." >&2
    exit 1
  fi
fi

if [[ "${npm_latest_version}" == "${dart_current_version}" ]] && ! is_true "${FORCE_CHECK}"; then
  echo "no update: pubspec.yaml (${dart_current_version}) matches npm latest (${npm_latest_version})."
  exit 0
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

upstream_dir="${tmp_dir}/openai-codex"
git clone --quiet --filter=blob:none --no-checkout "${UPSTREAM_URL}" "${upstream_dir}"
git -C "${upstream_dir}" fetch --quiet --tags --force

resolve_ref() {
  local repo_dir="$1"
  local version="$2"
  local candidate
  for candidate in "rust-v${version}" "v${version}"; do
    if git -C "${repo_dir}" rev-parse -q --verify "refs/tags/${candidate}^{commit}" >/dev/null 2>&1; then
      printf "refs/tags/%s" "${candidate}"
      return 0
    fi
  done
  return 1
}

old_ref=""
new_ref=""
if resolved="$(resolve_ref "${upstream_dir}" "${dart_current_version}")"; then
  old_ref="${resolved}"
fi
if resolved="$(resolve_ref "${upstream_dir}" "${npm_latest_version}")"; then
  new_ref="${resolved}"
fi

refs_note=""
if [[ -z "${old_ref}" || -z "${new_ref}" ]]; then
  refs_note="exact ref diff unavailable"
fi

changed_files_raw=""
commits_raw=""
patch_raw=""

if [[ -n "${old_ref}" && -n "${new_ref}" ]]; then
  changed_files_raw="$(git -C "${upstream_dir}" diff --name-status "${old_ref}" "${new_ref}" -- "${UPSTREAM_SCOPE}" || true)"
  commits_raw="$(git -C "${upstream_dir}" log --oneline "${old_ref}..${new_ref}" -- "${UPSTREAM_SCOPE}" || true)"
  patch_raw="$(git -C "${upstream_dir}" diff "${old_ref}" "${new_ref}" -- "${UPSTREAM_SCOPE}/src" || true)"
fi

trimmed_non_empty_lines() {
  local input="$1"
  local limit="$2"
  printf "%s\n" "${input}" | sed '/^[[:space:]]*$/d' | sed -n "1,${limit}p"
}

count_non_empty_lines() {
  local input="$1"
  printf "%s\n" "${input}" | sed '/^[[:space:]]*$/d' | wc -l | tr -d '[:space:]'
}

files_count="$(count_non_empty_lines "${changed_files_raw}")"
commits_count="$(count_non_empty_lines "${commits_raw}")"
patch_count="$(count_non_empty_lines "${patch_raw}")"

files_trimmed="$(trimmed_non_empty_lines "${changed_files_raw}" "${FILES_LIMIT}")"
commits_trimmed="$(trimmed_non_empty_lines "${commits_raw}" "${COMMITS_LIMIT}")"
patch_trimmed="$(trimmed_non_empty_lines "${patch_raw}" "${PATCH_LIMIT}")"

if [[ -z "${files_trimmed}" ]]; then
  files_trimmed="none"
fi
if [[ -z "${commits_trimmed}" ]]; then
  commits_trimmed="none"
fi
if [[ -z "${patch_trimmed}" ]]; then
  patch_trimmed="none"
fi

files_truncation_note=""
commits_truncation_note=""
patch_truncation_note=""

if (( files_count > FILES_LIMIT )); then
  files_truncation_note="(truncated to first ${FILES_LIMIT} lines out of ${files_count})"
fi
if (( commits_count > COMMITS_LIMIT )); then
  commits_truncation_note="(truncated to first ${COMMITS_LIMIT} lines out of ${commits_count})"
fi
if (( patch_count > PATCH_LIMIT )); then
  patch_truncation_note="(truncated to first ${PATCH_LIMIT} lines out of ${patch_count})"
fi

title="chore: sync typescript sdk to ${npm_latest_version}"
detected_at="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"

old_ref_display="${old_ref:-not found}"
new_ref_display="${new_ref:-not found}"
version_gap="${dart_current_version} -> ${npm_latest_version}"

body_file="${tmp_dir}/issue_body.md"
cat >"${body_file}" <<EOF
${MARKER}

## metadata

- current dart version: \`${dart_current_version}\`
- latest npm version: \`${npm_latest_version}\`
- version gap: \`${version_gap}\`
- detected at: \`${detected_at}\`
- compared refs: \`${old_ref_display}\` .. \`${new_ref_display}\`

$(if [[ -n "${refs_note}" ]]; then printf "> note: %s\n" "${refs_note}"; fi)

## agent task prompt

You are assigned to sync this Dart SDK with the latest upstream TypeScript SDK changes.

### goal
- port relevant changes from \`openai/codex\` under \`sdk/typescript\` into this Dart package.

### constraints
- keep Dart API parity with the TypeScript SDK.
- preserve backward compatibility unless upstream changes require a breaking update.
- update tests, docs, versioning, and changelog as needed.
- do not modify unrelated files.

### required output
- list of implemented changes mapped from TypeScript to Dart.
- test results (\`dart analyze\`, \`dart test\`).
- remaining gaps, risks, or follow-up tasks.

## upstream change summary

### changed files in sdk/typescript ${files_truncation_note}

\`\`\`text
${files_trimmed}
\`\`\`

### commits touching sdk/typescript ${commits_truncation_note}

\`\`\`text
${commits_trimmed}
\`\`\`

### patch excerpt (sdk/typescript/src) ${patch_truncation_note}

\`\`\`diff
${patch_trimmed}
\`\`\`

## checklist

- [ ] map TypeScript SDK changes to Dart equivalents
- [ ] implement code updates in the Dart package
- [ ] update/add tests
- [ ] run \`dart analyze\` and \`dart test\`
- [ ] update version/changelog if needed
- [ ] provide migration notes if behavior changed
EOF

if is_true "${DRY_RUN}"; then
  echo "dry run enabled; skipping issue mutations."
  echo "title: ${title}"
  echo "----- issue body begin -----"
  cat "${body_file}"
  echo "----- issue body end -----"
  exit 0
fi

gh label create "${LABEL}" \
  --repo "${REPO}" \
  --color "0e8a16" \
  --description "Tracks upstream TypeScript SDK sync work." >/dev/null 2>&1 || true

open_issues_json="$(gh issue list --repo "${REPO}" --state open --limit 200 --json number,title,body,url)"

mapfile -t matching_issues < <(
  printf "%s\n" "${open_issues_json}" \
    | jq -r --arg marker "${MARKER}" '.[] | select((.body // "") | contains($marker)) | .number' \
    | sort -n
)

primary_issue_number=""
if (( ${#matching_issues[@]} > 0 )); then
  primary_issue_number="${matching_issues[0]}"
  gh issue edit "${primary_issue_number}" \
    --repo "${REPO}" \
    --title "${title}" \
    --body-file "${body_file}" \
    --add-label "${LABEL}" >/dev/null

  if (( ${#matching_issues[@]} > 1 )); then
    for issue_number in "${matching_issues[@]:1}"; do
      gh issue close "${issue_number}" \
        --repo "${REPO}" \
        --comment "superseded by #${primary_issue_number} for typescript sdk sync tracking." >/dev/null
    done
  fi

  echo "updated issue #${primary_issue_number} in ${REPO}"
else
  created_url="$(gh issue create \
    --repo "${REPO}" \
    --title "${title}" \
    --body-file "${body_file}" \
    --label "${LABEL}")"
  echo "created issue: ${created_url}"
fi
