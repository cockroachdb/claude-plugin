#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# validate-marketplace-install.sh
#
# Simulates exactly what the Claude Code marketplace does when installing a
# plugin: git clone (NO submodule init) + checkout at a specific SHA.
# Then verifies whether skills are discoverable as real files.
#
# Usage:
#   ./scripts/validate-marketplace-install.sh                  # tests both SHAs
#   ./scripts/validate-marketplace-install.sh <sha>            # tests one SHA
#   ./scripts/validate-marketplace-install.sh <sha1> <sha2>    # tests two SHAs
###############################################################################

REPO_URL="https://github.com/cockroachdb/claude-plugin.git"
OLD_SHA="a54566e03c852567589ef85bb449d1e4de229667"
NEW_SHA="413d4fe"
WORK_DIR=$(mktemp -d)

cleanup() {
  echo ""
  echo "Cleaning up ${WORK_DIR} ..."
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

# Allow overriding SHAs via args
if [[ $# -eq 1 ]]; then
  SHAS=("$1")
elif [[ $# -eq 2 ]]; then
  SHAS=("$1" "$2")
else
  SHAS=("${OLD_SHA}" "${NEW_SHA}")
fi

###############################################################################
# test_sha <sha> <label>
###############################################################################
test_sha() {
  local sha="$1"
  local label="$2"
  local clone_dir="${WORK_DIR}/${label}"

  echo "=================================================================="
  echo " TEST: ${label} (SHA: ${sha})"
  echo "=================================================================="
  echo ""

  # Step 1: Clone WITHOUT --recurse-submodules (mimics marketplace)
  echo "[1/5] Cloning repo (no submodule init, like marketplace does)..."
  git clone --quiet --no-checkout "${REPO_URL}" "${clone_dir}" 2>&1
  cd "${clone_dir}"
  git checkout --quiet "${sha}" 2>&1
  echo "      Checked out ${sha}"
  echo ""

  # Step 2: Check if skills/ is a symlink or real directory
  echo "[2/5] Checking skills/ type..."
  if [[ -L "${clone_dir}/skills" ]]; then
    local target
    target=$(readlink "${clone_dir}/skills")
    echo "      skills/ is a SYMLINK -> ${target}"
    if [[ -d "${clone_dir}/skills" ]]; then
      echo "      Symlink target EXISTS"
    else
      echo "      Symlink target BROKEN (does not exist)"
    fi
  elif [[ -d "${clone_dir}/skills" ]]; then
    echo "      skills/ is a REAL DIRECTORY"
  else
    echo "      skills/ DOES NOT EXIST"
  fi
  echo ""

  # Step 3: Check submodule state
  echo "[3/5] Checking submodule state..."
  if [[ -f "${clone_dir}/.gitmodules" ]]; then
    local sub_dir="${clone_dir}/submodules/cockroachdb-skills"
    local sub_count
    sub_count=$(find "${sub_dir}" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "      .gitmodules exists"
    echo "      submodules/cockroachdb-skills/ contains ${sub_count} files"
    if [[ "${sub_count}" -eq 0 ]]; then
      echo "      (empty -- submodule NOT initialized, as expected for marketplace)"
    fi
  else
    echo "      No .gitmodules found"
  fi
  echo ""

  # Step 4: Count SKILL.md files
  echo "[4/5] Discovering skills..."
  local skill_count=0
  local broken_count=0
  local symlink_count=0

  if [[ -d "${clone_dir}/skills" ]]; then
    while IFS= read -r skill_md; do
      local skill_name
      skill_name=$(basename "$(dirname "${skill_md}")")
      local size
      size=$(wc -c < "${skill_md}" 2>/dev/null | tr -d ' ')

      if [[ -L "${skill_md}" ]]; then
        symlink_count=$((symlink_count + 1))
        if [[ ! -e "${skill_md}" ]]; then
          broken_count=$((broken_count + 1))
          echo "      [BROKEN]  ${skill_name}/SKILL.md (broken symlink)"
        else
          echo "      [SYMLINK] ${skill_name}/SKILL.md (${size} bytes)"
        fi
      elif [[ -f "${skill_md}" ]]; then
        echo "      [OK]      ${skill_name}/SKILL.md (${size} bytes)"
      fi
      skill_count=$((skill_count + 1))
    done < <(find "${clone_dir}/skills" -name "SKILL.md" 2>/dev/null | sort)
  fi

  # Also check for directories without SKILL.md
  if [[ -d "${clone_dir}/skills" ]]; then
    while IFS= read -r dir; do
      local name
      name=$(basename "${dir}")
      if [[ ! -f "${dir}/SKILL.md" ]]; then
        echo "      [MISSING] ${name}/ (no SKILL.md)"
      fi
    done < <(find "${clone_dir}/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  fi
  echo ""

  # Step 5: Verify other plugin components
  echo "[5/5] Checking other components..."
  local agents_count=0
  [[ -d "${clone_dir}/agents" ]] && agents_count=$(find "${clone_dir}/agents" -name "*.md" | wc -l | tr -d ' ')
  echo "      Agents:      ${agents_count}"
  echo "      hooks.json:  $(test -f "${clone_dir}/hooks/hooks.json" && echo "YES" || echo "NO")"
  echo "      .mcp.json:   $(test -f "${clone_dir}/.mcp.json" && echo "YES" || echo "NO")"
  echo "      tools.yaml:  $(test -f "${clone_dir}/tools.yaml" && echo "YES" || echo "NO")"
  echo "      plugin.json: $(test -f "${clone_dir}/.claude-plugin/plugin.json" && echo "YES" || echo "NO")"

  if [[ -f "${clone_dir}/.claude-plugin/plugin.json" ]]; then
    local version
    version=$(python3 -c "import json; print(json.load(open('${clone_dir}/.claude-plugin/plugin.json'))['version'])" 2>/dev/null || echo "unknown")
    echo "      Version:     ${version}"
  fi
  echo ""

  # Summary
  echo "------------------------------------------------------------------"
  echo " SUMMARY: ${label}"
  echo "------------------------------------------------------------------"
  echo "  Total SKILL.md files found: ${skill_count}"
  echo "  Real files:                 $((skill_count - symlink_count))"
  echo "  Symlinks:                   ${symlink_count}"
  echo "  Broken symlinks:            ${broken_count}"
  echo ""

  if [[ ${skill_count} -eq 29 && ${broken_count} -eq 0 && ${symlink_count} -eq 0 ]]; then
    echo "  RESULT: PASS -- All 29 skills present as real files"
  elif [[ ${skill_count} -eq 0 ]]; then
    echo "  RESULT: FAIL -- 0 skills discovered (broken symlinks to empty submodule)"
  else
    echo "  RESULT: PARTIAL -- Expected 29 real files, got ${skill_count} (${broken_count} broken)"
  fi
  echo ""
}

###############################################################################
# Main
###############################################################################
echo ""
echo "=================================================================="
echo " CockroachDB Claude Plugin - Marketplace Install Validator"
echo " Repo: ${REPO_URL}"
echo " Work dir: ${WORK_DIR}"
echo " Date: $(date)"
echo "=================================================================="
echo ""

for i in "${!SHAS[@]}"; do
  sha="${SHAS[$i]}"
  if [[ "${sha}" == "${OLD_SHA}" || "${sha}" == "${OLD_SHA:0:7}" ]]; then
    label="OLD_v0.1.1_${sha:0:7}"
  elif [[ "${sha}" == "${NEW_SHA}" || "${sha}" == "${NEW_SHA:0:7}" ]]; then
    label="NEW_v0.1.2_${sha:0:7}"
  else
    label="SHA_${sha:0:7}"
  fi
  test_sha "${sha}" "${label}"
done

echo "=================================================================="
echo " COMPARISON COMPLETE"
echo "=================================================================="
