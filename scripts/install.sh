#!/usr/bin/env bash
#
# install.sh - Symlink ShruggieTech skills into the user's personal Claude
#              skills directory on Linux and macOS.
#
# Source:      <repo>/skills/<skill-name>/
# Destination: ~/.claude/skills/<skill-name>/
#
# Skips the _template directory. Re-running is safe: existing correct
# symlinks are reported and left alone. Use --force to replace symlinks
# that point elsewhere. Refuses to clobber real files or directories.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKILLS_SRC="${REPO_ROOT}/skills"
SKILLS_DST="${HOME}/.claude/skills"

FORCE=0

usage() {
    cat <<EOF
Usage: install.sh [-f|--force] [-h|--help]

Symlinks each skill in ${SKILLS_SRC} into ${SKILLS_DST}.
The _template directory is skipped.

Options:
  -f, --force   Replace existing symlinks that point somewhere else
  -h, --help    Show this message and exit
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--force) FORCE=1; shift ;;
        -h|--help)  usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [[ ! -d "${SKILLS_SRC}" ]]; then
    echo "Error: source directory not found: ${SKILLS_SRC}" >&2
    exit 1
fi

mkdir -p "${SKILLS_DST}"

linked=0
replaced=0
skipped=0
failed=0

# Use nullglob so we get an empty list rather than the literal pattern if
# the skills directory is empty.
shopt -s nullglob
skill_dirs=("${SKILLS_SRC}"/*/)
shopt -u nullglob

if [[ ${#skill_dirs[@]} -eq 0 ]]; then
    echo "No skills found in ${SKILLS_SRC}"
    exit 0
fi

echo "Installing skills from: ${SKILLS_SRC}"
echo "                   to: ${SKILLS_DST}"
echo ""

for skill_path in "${skill_dirs[@]}"; do
    skill_name="$(basename "${skill_path}")"
    source_abs="${skill_path%/}"
    target="${SKILLS_DST}/${skill_name}"

    if [[ "${skill_name}" == "_template" ]]; then
        continue
    fi

    if [[ -L "${target}" ]]; then
        current="$(readlink "${target}")"
        if [[ "${current}" == "${source_abs}" ]]; then
            printf "  ok        %s (already linked)\n" "${skill_name}"
            skipped=$((skipped + 1))
            continue
        fi

        if [[ ${FORCE} -eq 1 ]]; then
            rm "${target}"
            if ln -s "${source_abs}" "${target}"; then
                printf "  replaced  %s (was -> %s)\n" "${skill_name}" "${current}"
                replaced=$((replaced + 1))
            else
                printf "  failed    %s\n" "${skill_name}" >&2
                failed=$((failed + 1))
            fi
            continue
        fi

        printf "  skip      %s (existing symlink to %s; use --force to replace)\n" \
            "${skill_name}" "${current}" >&2
        skipped=$((skipped + 1))
        continue
    fi

    if [[ -e "${target}" ]]; then
        printf "  skip      %s (existing file or directory at target; refusing to clobber)\n" \
            "${skill_name}" >&2
        skipped=$((skipped + 1))
        continue
    fi

    if ln -s "${source_abs}" "${target}"; then
        printf "  linked    %s\n" "${skill_name}"
        linked=$((linked + 1))
    else
        printf "  failed    %s\n" "${skill_name}" >&2
        failed=$((failed + 1))
    fi
done

echo ""
echo "Done. Linked: ${linked}, Replaced: ${replaced}, Skipped: ${skipped}, Failed: ${failed}"

if [[ ${failed} -gt 0 ]]; then
    exit 1
fi
