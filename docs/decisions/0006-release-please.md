# 6. Automatic versioning with release-please

Date: 2026-11-06 · Status: accepted

## Context
F-Droid builds release tags (`vX.Y.Z`) and needs Android's versionCode to go
up every release. Commits already follow Conventional Commits.

## Decision
Use release-please (`.github/workflows/release.yml`, `release-type: dart`).
It keeps a release PR open that bumps `pubspec.yaml` and `CHANGELOG.md`;
merging it tags the release.

- `feat:` bumps the minor version and `fix:` the patch while we're below 1.0
  (`bump-minor-pre-major`). A breaking change (`feat!:`) also only bumps
  minor before 1.0.
- The `+N` build number (Android versionCode) goes up by one each release;
  release-please's Dart updater does this.
- The in-app version comes from `package_info_plus`, so nothing else needs
  editing by hand.

- The web version deploys only when a release is created (called from
  `release.yml`), so `main` can hold unreleased work.
- Changes land through pull requests with required CI and squash merges, so
  each PR title becomes one conventional commit.

## Consequences
- Never edit `version:` in `pubspec.yaml` or the tags by hand.
- Commit types matter: a feature committed as `chore:` won't trigger a release.
- The manifest starts at 0.1.0 (the scaffold version), so the first
  release PR, with all the `feat:` commits so far, becomes 0.2.0.
