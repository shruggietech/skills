#!/usr/bin/env bash
#
# release.sh - Cut a formal release of the ShruggieTech skills repo.
#
# Rolls the Keep a Changelog Unreleased section into a new versioned
# section, generates release notes, builds one zip per skill in
# dist/vX.Y.Z/, computes SHA256 sums, commits, tags, and pushes.
#
# Defaults: patch bump, branch=main, zip artifacts built, push at end.
# Use --dry-run to preview without writing anything.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKILLS_SRC="${REPO_ROOT}/skills"
CHANGELOG_PATH="${REPO_ROOT}/CHANGELOG.md"
RELEASE_NOTES_DIR="${REPO_ROOT}/release-notes"
DIST_DIR="${REPO_ROOT}/dist"

# Defaults
BUMP="patch"
EXPLICIT_VERSION=""
NOTES_SUMMARY=""
BRANCH="main"
DRY_RUN=0
VERBOSE=0
QUIET=0
NO_ZIP=0
NO_PUSH=0
GH_RELEASE=0
BUMP_FLAG_COUNT=0

usage() {
    cat <<EOF
Usage: release.sh [options]

Cut a formal release: roll CHANGELOG, generate release notes, build
per-skill zips in dist/vX.Y.Z/, commit, tag, and push.

Version selection (mutually exclusive, default --patch):
  --major                 Bump MAJOR (X.0.0); reset minor and patch.
  --minor                 Bump MINOR (X.Y.0); reset patch.
  --patch                 Bump PATCH (X.Y.Z); the default.
  --version X.Y.Z         Use an explicit version. Must be strictly
                          greater than the highest existing tag.

  With no prior tags, every option above resolves to 1.0.0 unless
  --version overrides.

Release notes:
  --notes-summary "TEXT"  Optional summary paragraph inserted between
                          the H1 and the first section in the release
                          notes file. Default: no summary.

Branch / safety:
  --branch NAME           Branch to release from. Default: main.

Behavior toggles:
  -n, --dry-run           Preview every step. No files written, no
                          commit, no tag, no push. Preflight still
                          runs so wrong-branch / dirty-tree / tag-
                          exists conditions are caught.
  -v, --verbose           Print each preflight check and substep.
                          Mutually exclusive with --quiet.
  -q, --quiet             Suppress all non-error output. Mutually
                          exclusive with --verbose.
  --no-zip                Skip building per-skill zips.
  --no-push               Skip both git pushes at the end.
  --gh-release            After pushing, create a GitHub release with
                          \`gh release create\`. Attaches the zips and
                          SHA256SUMS.txt. Requires \`gh\` on PATH and
                          an authenticated session.

  -h, --help              Show this help and exit.

Examples:
  ./scripts/release.sh --dry-run --verbose
  ./scripts/release.sh
  ./scripts/release.sh --minor
  ./scripts/release.sh --version 2.0.0
  ./scripts/release.sh --major --no-push
  ./scripts/release.sh --gh-release
EOF
}

die() {
    printf "error: %s\n" "$*" >&2
    exit 1
}

info() {
    if [[ "$QUIET" -eq 0 ]]; then
        printf "%s\n" "$*"
    fi
}

verbose() {
    if [[ "$VERBOSE" -eq 1 ]]; then
        printf "  [verbose] %s\n" "$*"
    fi
}

dryrun() {
    info "[dry-run] $*"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --major)   BUMP="major"; BUMP_FLAG_COUNT=$((BUMP_FLAG_COUNT + 1)); shift ;;
            --minor)   BUMP="minor"; BUMP_FLAG_COUNT=$((BUMP_FLAG_COUNT + 1)); shift ;;
            --patch)   BUMP="patch"; BUMP_FLAG_COUNT=$((BUMP_FLAG_COUNT + 1)); shift ;;
            --version)
                if [[ $# -lt 2 ]]; then
                    printf "error: --version requires a value\n" >&2
                    usage >&2
                    exit 2
                fi
                if [[ ! "$2" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    printf "error: invalid version: %s (must be X.Y.Z)\n" "$2" >&2
                    exit 2
                fi
                EXPLICIT_VERSION="$2"
                BUMP_FLAG_COUNT=$((BUMP_FLAG_COUNT + 1))
                shift 2 ;;
            --notes-summary)
                [[ $# -ge 2 ]] || { usage >&2; die "--notes-summary requires a value" ; }
                NOTES_SUMMARY="$2"
                shift 2 ;;
            --branch)
                [[ $# -ge 2 ]] || { usage >&2; die "--branch requires a value" ; }
                BRANCH="$2"
                shift 2 ;;
            -n|--dry-run)  DRY_RUN=1; shift ;;
            -v|--verbose)  VERBOSE=1; shift ;;
            -q|--quiet)    QUIET=1; shift ;;
            --no-zip)      NO_ZIP=1; shift ;;
            --no-push)     NO_PUSH=1; shift ;;
            --gh-release)  GH_RELEASE=1; shift ;;
            -h|--help)     usage; exit 0 ;;
            *)
                printf "error: unknown option: %s\n" "$1" >&2
                usage >&2
                exit 2 ;;
        esac
    done

    if [[ "$BUMP_FLAG_COUNT" -gt 1 ]]; then
        printf "error: --major, --minor, --patch, and --version are mutually exclusive\n" >&2
        usage >&2
        exit 2
    fi

    if [[ "$VERBOSE" -eq 1 && "$QUIET" -eq 1 ]]; then
        printf "error: --verbose and --quiet are mutually exclusive\n" >&2
        usage >&2
        exit 2
    fi
}

require_cmd() {
    command -v "$1" > /dev/null 2>&1 || die "$1 not on PATH"
}

is_inside_git_tree() {
    git -C "$REPO_ROOT" rev-parse --is-inside-work-tree > /dev/null 2>&1
}

has_unreleased_content() {
    # Returns 0 if the CHANGELOG has a non-empty Unreleased section,
    # where "non-empty" means at least one non-blank, non-heading line.
    awk '
        BEGIN { found = 0; has_content = 0 }
        /^## (\[)?Unreleased(\])?[[:space:]]*$/ { found = 1; next }
        found && /^## / { exit }
        found && NF > 0 { has_content = 1 }
        END { exit has_content ? 0 : 1 }
    ' "$1"
}

get_latest_tag() {
    # Print the highest semver tag matching vX.Y.Z, or empty if none.
    # Tolerant of empty tag list: never propagates a non-zero exit.
    local tags
    tags="$(git -C "$REPO_ROOT" tag --list 'v*.*.*' 2>/dev/null || true)"
    if [[ -z "$tags" ]]; then
        return 0
    fi
    printf '%s\n' "$tags" \
        | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
        | sort -V \
        | tail -n1 \
        || true
}

detect_repo_slug() {
    local url
    url="$(git -C "$REPO_ROOT" config --get remote.origin.url 2>/dev/null || true)"
    [[ -n "$url" ]] || die "no remote 'origin' configured"

    # Strip trailing .git if present
    url="${url%.git}"

    # Handle git@github.com:owner/repo
    if [[ "$url" == git@github.com:* ]]; then
        echo "${url#git@github.com:}"
        return
    fi
    # Handle https://github.com/owner/repo
    if [[ "$url" == https://github.com/* ]]; then
        echo "${url#https://github.com/}"
        return
    fi
    # Handle ssh://git@github.com/owner/repo
    if [[ "$url" == ssh://git@github.com/* ]]; then
        echo "${url#ssh://git@github.com/}"
        return
    fi

    die "could not parse owner/repo from remote URL: $url"
}

semver_validate() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "invalid semver: $1"
}

semver_greater_than() {
    # Returns 0 if $1 > $2 in semver ordering, else 1.
    local a="$1" b="$2"
    if [[ "$a" == "$b" ]]; then
        return 1
    fi
    local sorted
    sorted="$(printf '%s\n%s\n' "$a" "$b" | sort -V | tail -n1)"
    [[ "$sorted" == "$a" ]]
}

compute_version() {
    local latest_tag latest_version
    latest_tag="$(get_latest_tag)"
    if [[ -n "$latest_tag" ]]; then
        latest_version="${latest_tag#v}"
    else
        latest_version=""
    fi
    verbose "latest tag: ${latest_tag:-<none>}"

    if [[ -n "$EXPLICIT_VERSION" ]]; then
        semver_validate "$EXPLICIT_VERSION"
        if [[ -n "$latest_version" ]]; then
            semver_greater_than "$EXPLICIT_VERSION" "$latest_version" \
                || die "--version $EXPLICIT_VERSION is not greater than current $latest_version"
        fi
        NEXT_VERSION="$EXPLICIT_VERSION"
        verbose "explicit version requested: $NEXT_VERSION"
        return
    fi

    if [[ -z "$latest_version" ]]; then
        NEXT_VERSION="1.0.0"
        verbose "no prior tags found, defaulting to first release: $NEXT_VERSION"
        return
    fi

    local major minor patch
    IFS='.' read -r major minor patch <<< "$latest_version"
    case "$BUMP" in
        major) major=$((major + 1)); minor=0; patch=0 ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        patch) patch=$((patch + 1)) ;;
    esac
    NEXT_VERSION="${major}.${minor}.${patch}"
    verbose "bump=$BUMP, next version: $NEXT_VERSION"
}

check_tag_does_not_exist() {
    local tag="v$1"
    if git -C "$REPO_ROOT" rev-parse "$tag" > /dev/null 2>&1; then
        die "tag $tag already exists locally"
    fi
    if git -C "$REPO_ROOT" ls-remote --tags origin "refs/tags/${tag}" \
            | grep -q "refs/tags/${tag}$"; then
        die "tag $tag already exists on origin"
    fi
}

preflight() {
    info "Preflight checks..."
    require_cmd git
    verbose "git ok"
    if [[ "$NO_ZIP" -eq 0 ]]; then
        require_cmd zip
        verbose "zip ok"
    else
        verbose "zip skipped (--no-zip)"
    fi

    is_inside_git_tree || die "not inside a git work tree"
    verbose "inside git tree ok"

    verbose "fetching origin (tags + refs)"
    if ! git -C "$REPO_ROOT" fetch origin --tags --quiet 2>/dev/null; then
        die "git fetch origin failed (network or auth issue?)"
    fi

    local current_branch
    current_branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
    [[ "$current_branch" == "$BRANCH" ]] \
        || die "current branch is '$current_branch', expected '$BRANCH'"
    verbose "on branch $BRANCH ok"

    local porcelain
    porcelain="$(git -C "$REPO_ROOT" status --porcelain)"
    if [[ -n "$porcelain" ]]; then
        printf "error: working tree is not clean:\n%s\n" "$porcelain" >&2
        exit 1
    fi
    verbose "working tree clean ok"

    local local_sha origin_sha
    local_sha="$(git -C "$REPO_ROOT" rev-parse HEAD)"
    if ! origin_sha="$(git -C "$REPO_ROOT" rev-parse "origin/${BRANCH}" 2>/dev/null)"; then
        die "origin/${BRANCH} not found; has the branch been pushed?"
    fi
    [[ "$local_sha" == "$origin_sha" ]] \
        || die "local ${BRANCH} (${local_sha:0:7}) is not in sync with origin/${BRANCH} (${origin_sha:0:7})"
    verbose "in sync with origin/${BRANCH} ok"

    [[ -f "$CHANGELOG_PATH" ]] || die "CHANGELOG.md not found at $CHANGELOG_PATH"
    has_unreleased_content "$CHANGELOG_PATH" \
        || die "CHANGELOG.md ## Unreleased section is missing or empty"
    verbose "CHANGELOG Unreleased section ok"

    if [[ "$GH_RELEASE" -eq 1 ]]; then
        require_cmd gh
        gh auth status > /dev/null 2>&1 || die "gh is not authenticated (run 'gh auth login')"
        verbose "gh authenticated ok"
    fi
}

# Extract the Unreleased section content (everything after the heading
# up to the next ## heading) into a string. Returns content without the
# Unreleased heading itself.
extract_unreleased_body() {
    awk '
        BEGIN { in_section = 0 }
        /^## (\[)?Unreleased(\])?[[:space:]]*$/ { in_section = 1; next }
        in_section && /^## / { exit }
        in_section { print }
    ' "$CHANGELOG_PATH"
}

# Strip any trailing footer link block ([foo]: url lines, possibly with
# blank separators) from the file content and emit the body. The footer
# is identified as the contiguous block of [...]:url lines (and the
# blank line before them) at end of file.
strip_footer_links() {
    awk '
        {
            buffer[NR] = $0
            total = NR
        }
        END {
            # Walk backwards: skip trailing blanks and link-ref lines.
            i = total
            while (i > 0) {
                line = buffer[i]
                if (line ~ /^[[:space:]]*$/ || line ~ /^\[[^]]+\]:[[:space:]]/) {
                    i--
                } else {
                    break
                }
            }
            # Now buffer[1..i] is the body; trim trailing blanks within it.
            while (i > 0 && buffer[i] ~ /^[[:space:]]*$/) i--
            for (j = 1; j <= i; j++) print buffer[j]
        }
    ' "$CHANGELOG_PATH"
}

# Find all existing ## [X.Y.Z] - DATE headings and print just the versions,
# in the order they appear in the file (newest first by convention).
list_existing_versions() {
    grep -E '^## \[[0-9]+\.[0-9]+\.[0-9]+\][[:space:]]+-' "$1" \
        | sed -E 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\].*$/\1/' || true
}

build_footer_block() {
    local version="$1" repo_slug="$2" tmp_body="$3"
    local -a versions=()
    while IFS= read -r v; do
        [[ -n "$v" ]] && versions+=("$v")
    done < <(list_existing_versions "$tmp_body")

    printf "[unreleased]: https://github.com/%s/compare/v%s...HEAD\n" \
        "$repo_slug" "${versions[0]}"

    local count="${#versions[@]}"
    local i
    for (( i = 0; i < count; i++ )); do
        local cur="${versions[i]}"
        if (( i + 1 < count )); then
            local prev="${versions[i + 1]}"
            printf "[%s]: https://github.com/%s/compare/v%s...v%s\n" \
                "$cur" "$repo_slug" "$prev" "$cur"
        else
            printf "[%s]: https://github.com/%s/releases/tag/v%s\n" \
                "$cur" "$repo_slug" "$cur"
        fi
    done
}

roll_changelog() {
    local version="$1" date_str="$2" repo_slug="$3"

    info "Rolling CHANGELOG.md..."

    local body_no_footer
    body_no_footer="$(strip_footer_links)"

    # Promote ## Unreleased -> ## [Unreleased] + insert new version heading.
    local rolled
    rolled="$(printf '%s\n' "$body_no_footer" \
        | awk -v ver="$version" -v dt="$date_str" '
            BEGIN { done = 0 }
            /^## (\[)?Unreleased(\])?[[:space:]]*$/ && !done {
                print "## [Unreleased]"
                print ""
                print "## [" ver "] - " dt
                done = 1
                next
            }
            { print }
        ')"

    if [[ "$rolled" == "$body_no_footer" ]]; then
        die "could not find ## Unreleased heading in CHANGELOG.md"
    fi

    # Build the new footer block using the rolled body as the version source.
    local rolled_tmp footer
    rolled_tmp="$(mktemp)"
    printf '%s\n' "$rolled" > "$rolled_tmp"
    footer="$(build_footer_block "$version" "$repo_slug" "$rolled_tmp")"
    rm -f "$rolled_tmp"

    local final_content
    final_content="${rolled}"$'\n\n'"${footer}"$'\n'

    if [[ "$DRY_RUN" -eq 1 ]]; then
        dryrun "would write CHANGELOG.md ($(printf '%s' "$final_content" | wc -l | tr -d ' ') lines)"
        if [[ "$VERBOSE" -eq 1 ]]; then
            printf '%s\n' "----- CHANGELOG preview (first 40 lines) -----"
            printf '%s\n' "$final_content" | head -n 40
            printf '%s\n' "----- (end preview) -----"
        fi
        return
    fi

    printf '%s' "$final_content" > "$CHANGELOG_PATH"
    info "  wrote     CHANGELOG.md"
}

write_release_notes() {
    local version="$1" date_str="$2"
    local notes_file="${RELEASE_NOTES_DIR}/v${version}.md"

    info "Writing release notes..."

    # Body = the just-rolled section under ## [VERSION]. But we already
    # rolled the file; safer to derive from the pre-roll Unreleased body
    # which we extracted at the very start. Re-extract here defensively.
    # However, after roll_changelog, ## Unreleased is empty. So we must
    # read from the new ## [VERSION] section instead.
    local section_body
    if [[ "$DRY_RUN" -eq 1 ]]; then
        # In dry-run, CHANGELOG was not modified; pull from Unreleased.
        section_body="$(extract_unreleased_body)"
    else
        # CHANGELOG has been rolled; pull from the new [VERSION] section.
        local heading_prefix="## [${version}] - "
        section_body="$(awk -v prefix="$heading_prefix" '
            BEGIN { in_section = 0 }
            index($0, prefix) == 1 { in_section = 1; next }
            in_section && /^## / { exit }
            in_section { print }
        ' "$CHANGELOG_PATH")"
    fi

    # Promote ### -> ## in the extracted body
    local promoted
    promoted="$(printf '%s\n' "$section_body" | sed -E 's/^### /## /')"
    # Trim leading and trailing blanks
    promoted="$(printf '%s' "$promoted" | awk 'BEGIN{p=0} NF{p=1} p{print}' | awk '{lines[NR]=$0} END{n=NR; while(n>0 && lines[n] ~ /^[[:space:]]*$/) n--; for(i=1;i<=n;i++) print lines[i]}')"

    local notes_content
    notes_content="# v${version} - ${date_str}"$'\n'
    if [[ -n "$NOTES_SUMMARY" ]]; then
        notes_content+=$'\n'"${NOTES_SUMMARY}"$'\n'
    fi
    notes_content+=$'\n'"${promoted}"$'\n'

    if [[ "$DRY_RUN" -eq 1 ]]; then
        dryrun "would write ${notes_file} ($(printf '%s' "$notes_content" | wc -l | tr -d ' ') lines)"
        if [[ "$VERBOSE" -eq 1 ]]; then
            printf '%s\n' "----- release-notes preview -----"
            printf '%s\n' "$notes_content"
            printf '%s\n' "----- (end preview) -----"
        fi
        return
    fi

    mkdir -p "$RELEASE_NOTES_DIR"
    printf '%s' "$notes_content" > "$notes_file"
    info "  wrote     release-notes/v${version}.md"
}

build_zips() {
    local version="$1"
    local version_dist="${DIST_DIR}/v${version}"

    if [[ "$NO_ZIP" -eq 1 ]]; then
        info "Skipping zip build (--no-zip)."
        return
    fi

    info "Building per-skill zips..."

    if [[ "$DRY_RUN" -eq 0 ]]; then
        mkdir -p "$version_dist"
    fi

    shopt -s nullglob
    local skill_dirs=("${SKILLS_SRC}"/*/)
    shopt -u nullglob

    local zipped=0 skipped=0 failed=0
    for skill_path in "${skill_dirs[@]}"; do
        local skill_name
        skill_name="$(basename "${skill_path%/}")"

        if [[ "$skill_name" == "_template" ]]; then
            skipped=$((skipped + 1))
            verbose "skipped _template"
            continue
        fi

        local zip_name="${skill_name}-v${version}.zip"
        local zip_full="${version_dist}/${zip_name}"

        if [[ "$DRY_RUN" -eq 1 ]]; then
            dryrun "would zip skills/${skill_name} -> dist/v${version}/${zip_name}"
            zipped=$((zipped + 1))
            continue
        fi

        rm -f "$zip_full"
        if ( cd "${SKILLS_SRC}" && zip -r -q "$zip_full" "${skill_name}" ); then
            local size
            size="$(wc -c < "$zip_full" | tr -d ' ')"
            info "  zipped    ${zip_name} (${size} bytes)"
            zipped=$((zipped + 1))
        else
            printf "  failed    %s\n" "$zip_name" >&2
            failed=$((failed + 1))
        fi
    done

    info "Zipped ${zipped}, Skipped ${skipped}, Failed ${failed}."
    if [[ "$failed" -gt 0 ]]; then
        die "one or more zip operations failed"
    fi
}

compute_checksums() {
    local version="$1"
    local version_dist="${DIST_DIR}/v${version}"
    local sums_path="${version_dist}/SHA256SUMS.txt"

    if [[ "$NO_ZIP" -eq 1 ]]; then
        return
    fi

    info "Computing SHA256 checksums..."

    if [[ "$DRY_RUN" -eq 1 ]]; then
        dryrun "would write ${sums_path}"
        return
    fi

    local hasher=""
    if command -v sha256sum > /dev/null 2>&1; then
        hasher="sha256sum"
    elif command -v shasum > /dev/null 2>&1; then
        hasher="shasum -a 256"
    else
        die "no SHA256 utility found (need sha256sum or shasum)"
    fi

    ( cd "$version_dist" && eval "$hasher *.zip" > SHA256SUMS.txt )
    info "  wrote     dist/v${version}/SHA256SUMS.txt"
}

do_commit() {
    local version="$1"
    local msg="chore(release): cut v${version}"
    local notes_rel="release-notes/v${version}.md"

    info "Committing release..."

    if [[ "$DRY_RUN" -eq 1 ]]; then
        dryrun "would: git add CHANGELOG.md ${notes_rel}"
        dryrun "would: git commit -m \"${msg}\""
        return
    fi

    git -C "$REPO_ROOT" add CHANGELOG.md "${notes_rel}"
    git -C "$REPO_ROOT" commit -m "$(printf '%s\n\nCo-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>\n' "$msg")" \
        > /dev/null
    local sha
    sha="$(git -C "$REPO_ROOT" rev-parse HEAD)"
    info "  commit    ${sha:0:7} ${msg}"
}

do_tag() {
    local version="$1"
    local tag="v${version}"
    local notes_file="${RELEASE_NOTES_DIR}/v${version}.md"

    info "Tagging..."

    if [[ "$DRY_RUN" -eq 1 ]]; then
        dryrun "would: git tag -a ${tag} -F ${notes_file}"
        return
    fi

    git -C "$REPO_ROOT" tag -a "$tag" -F "$notes_file"
    info "  tag       ${tag} (annotated)"
}

do_push() {
    local version="$1"
    local tag="v${version}"

    if [[ "$NO_PUSH" -eq 1 ]]; then
        info "Skipping push (--no-push)."
        return
    fi

    info "Pushing to origin..."

    if [[ "$DRY_RUN" -eq 1 ]]; then
        dryrun "would: git push origin ${BRANCH}"
        dryrun "would: git push origin ${tag}"
        return
    fi

    git -C "$REPO_ROOT" push origin "$BRANCH"
    git -C "$REPO_ROOT" push origin "$tag"
    info "  pushed    ${BRANCH} and ${tag}"
}

do_gh_release() {
    local version="$1"
    local tag="v${version}"
    local notes_file="${RELEASE_NOTES_DIR}/v${version}.md"
    local version_dist="${DIST_DIR}/v${version}"

    if [[ "$GH_RELEASE" -eq 0 ]]; then
        return
    fi

    info "Creating GitHub release..."

    local -a assets=()
    if [[ "$NO_ZIP" -eq 0 ]]; then
        shopt -s nullglob
        local zip
        for zip in "${version_dist}"/*.zip; do
            assets+=("$zip")
        done
        if [[ -f "${version_dist}/SHA256SUMS.txt" ]]; then
            assets+=("${version_dist}/SHA256SUMS.txt")
        fi
        shopt -u nullglob
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        dryrun "would: gh release create ${tag} --title ${tag} --notes-file ${notes_file} ${assets[*]:-}"
        return
    fi

    if [[ "${#assets[@]}" -eq 0 ]]; then
        gh release create "$tag" --title "$tag" --notes-file "$notes_file"
    else
        gh release create "$tag" --title "$tag" --notes-file "$notes_file" "${assets[@]}"
    fi
    info "  released  ${tag} on GitHub"
}

summary() {
    local version="$1"
    info ""
    if [[ "$DRY_RUN" -eq 1 ]]; then
        info "Dry run complete. Target version: v${version}. No changes were made."
    else
        info "Release v${version} cut successfully."
        if [[ "$NO_PUSH" -eq 1 ]]; then
            info "Local-only (--no-push). Push with: git push origin ${BRANCH} && git push origin v${version}"
        fi
    fi
}

main() {
    parse_args "$@"

    info "release.sh: cutting release from ${REPO_ROOT}"
    preflight

    compute_version
    check_tag_does_not_exist "$NEXT_VERSION"

    local repo_slug date_str
    repo_slug="$(detect_repo_slug)"
    date_str="$(date -u +%Y-%m-%d)"
    verbose "repo slug: ${repo_slug}"
    verbose "release date (UTC): ${date_str}"

    roll_changelog "$NEXT_VERSION" "$date_str" "$repo_slug"
    write_release_notes "$NEXT_VERSION" "$date_str"
    build_zips "$NEXT_VERSION"
    compute_checksums "$NEXT_VERSION"
    do_commit "$NEXT_VERSION"
    do_tag "$NEXT_VERSION"
    do_push "$NEXT_VERSION"
    do_gh_release "$NEXT_VERSION"
    summary "$NEXT_VERSION"
}

main "$@"
