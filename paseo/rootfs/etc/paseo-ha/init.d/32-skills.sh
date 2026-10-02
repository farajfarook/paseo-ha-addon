#!/usr/bin/env bash
# shellcheck shell=bash
# ==============================================================================
# 32-skills (design D12/D14): per-skill symlinks for the bundled skills
# (/opt/paseo-ha/skills/*) and the user's skills (/config/skills/*) into
#   ~/.agents/skills   (Pi, Codex, OpenCode)
#   $CLAUDE_CONFIG_DIR/skills  (Claude Code; = ~/.claude/skills here)
# A user skill with the same name as a bundled one wins. Links we create are
# recorded in a manifest in /data; on each start links from earlier runs that are
# no longer wanted (or dangle) are removed. Paseo-managed skill folders (real
# directories written by the daemon's skill sync) are never touched.
# ==============================================================================

PASEO_HA_CONFIG_DIR="${PASEO_HA_CONFIG_DIR:-/config}"
bundled_skills_dir="${PASEO_HA_OPT_DIR}/skills"
user_skills_dir="${PASEO_HA_CONFIG_DIR}/skills"
manifest="${PASEO_HA_DATA}/paseo-ha/skill-links.manifest"

skill_roots=("${HOME}/.agents/skills" "${CLAUDE_CONFIG_DIR:-${HOME}/.claude}/skills")

# Names of the skills Paseo itself syncs; never shadow them with a link (Paseo's
# sync refuses to write through symlinks).
ph_paseo_skill_names() {
  local dir
  for dir in /opt/node/lib/node_modules/@getpaseo/cli/node_modules/@getpaseo/server/dist/server/skills \
             /opt/node/lib/node_modules/@getpaseo/server/dist/server/skills; do
    [[ -d "${dir}" ]] || continue
    find "${dir}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;
  done
}

# Is PATH one of the links we manage (recorded, or pointing into a source dir)?
ph_is_our_link() {
  local link="$1" target
  [[ -L "${link}" ]] || return 1
  grep -Fxq "${link}" "${manifest}" 2>/dev/null && return 0
  target="$(readlink "${link}")"
  [[ "${target}" == "${bundled_skills_dir}/"* || "${target}" == "${user_skills_dir}/"* ]]
}

ph_sync_skill_links() {
  mkdir -p "$(dirname "${manifest}")"
  touch "${manifest}"

  local -A wanted=()   # skill name -> source dir
  local -A reserved=()
  local name dir src root link

  while IFS= read -r name; do
    [[ -n "${name}" ]] && reserved["${name}"]=1
  done < <(ph_paseo_skill_names)

  # Bundled first, user second: the user's entry replaces the bundled one.
  for src in "${bundled_skills_dir}" "${user_skills_dir}"; do
    [[ -d "${src}" ]] || continue
    for dir in "${src}"/*/; do
      dir="${dir%/}"
      [[ -f "${dir}/SKILL.md" ]] || continue
      name="$(basename "${dir}")"
      if [[ -n "${reserved[${name}]:-}" ]]; then
        ph_log_warn "Skill '${name}' in ${src} has the same name as a Paseo built-in skill; skipped (rename the folder)"
        continue
      fi
      wanted["${name}"]="${dir}"
    done
  done

  local new_manifest
  new_manifest="$(mktemp)"

  for root in "${skill_roots[@]}"; do
    mkdir -p "${root}"
    for name in "${!wanted[@]}"; do
      link="${root}/${name}"
      src="${wanted[${name}]}"
      if [[ -L "${link}" ]]; then
        if ! ph_is_our_link "${link}"; then
          ph_log_warn "Not replacing existing symlink ${link} (not created by the add-on)"
          continue
        fi
        if [[ "$(readlink "${link}")" != "${src}" ]]; then
          rm -f "${link}"
          ln -s "${src}" "${link}"
        fi
      elif [[ -e "${link}" ]]; then
        ph_log_warn "Not replacing existing ${link} (not created by the add-on); skill '${name}' from ${src} is not linked there"
        continue
      else
        ln -s "${src}" "${link}"
      fi
      echo "${link}" >> "${new_manifest}"
    done
  done

  # Remove links from earlier runs that are no longer wanted or now dangle.
  while IFS= read -r link; do
    [[ -z "${link}" ]] && continue
    grep -Fxq "${link}" "${new_manifest}" && continue
    if [[ -L "${link}" ]]; then
      rm -f "${link}"
      ph_log_info "Removed stale skill link ${link}"
    fi
  done < "${manifest}"
  # Also sweep links into our source dirs that a lost manifest no longer lists.
  for root in "${skill_roots[@]}"; do
    for link in "${root}"/*; do
      [[ -L "${link}" ]] || continue
      grep -Fxq "${link}" "${new_manifest}" && continue
      if ph_is_our_link "${link}"; then
        rm -f "${link}"
        ph_log_info "Removed stale skill link ${link}"
      fi
    done
  done

  sort -u "${new_manifest}" > "${manifest}"
  rm -f "${new_manifest}"
  ph_log_info "Linked ${#wanted[@]} skill(s) for all agents"
}

ph_sync_skill_links
