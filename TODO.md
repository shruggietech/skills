# To Do

A running list of follow-ups not yet scheduled for a release. Items move out of here either when they land (paired with a `CHANGELOG.md` entry under `## [Unreleased]`) or when they're explicitly dropped (with a brief note in the commit that removes them).

This file is for engineering follow-ups that span more than one PR or aren't urgent enough to open a GitHub issue. For user-reported bugs and feature requests, open a GitHub issue instead.

## Release tooling

- [ ] **`scripts/release.{sh,ps1}` does not create a GitHub Release by default.** When run without `--gh-release` / `-GhRelease`, the script pushes the tag and the release commit but stops there. The per-skill zips and `SHA256SUMS.txt` stay in the local `dist/vX.Y.Z/` directory and never reach GitHub, so the Releases tab shows only GitHub's auto-generated source-code archive. This happened on `v1.0.0`: the release was published manually after the fact with `gh release create v1.0.0 dist/v1.0.0/*.zip dist/v1.0.0/SHA256SUMS.txt --notes-file release-notes/v1.0.0.md --title v1.0.0`. Decide between: (a) flipping the default to on so `--no-gh-release` is the opt-out, (b) keeping the default off but printing a prominent post-run hint with the exact `gh release create` command when the flag wasn't passed, or (c) both. Whichever path, update `CONTRIBUTING.md` "Cutting a Release" to match.
