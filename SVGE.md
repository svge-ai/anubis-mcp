# Fork sync

`main` is an exact mirror of upstream [anubis-mcp](https://github.com/zoedsoupe/anubis-mcp) and stays the default branch. `svge-main` is the integration branch for this fork. It was cut from upstream `cdb9cd6498b5b1e0d9ccb0924aadb4cc74719570` (`chore: release 2.2.0`, #327), not from the tip of `main`. Do not retarget the default branch at `svge-main`.

Do not push tags. `svge-main` was created with no tags, and fork work does not publish tags.

## Status

| | |
| --- | --- |
| Upstream | https://github.com/zoedsoupe/anubis-mcp |
| Default branch | `main` |
| `svge-main` base | `cdb9cd6498b5b1e0d9ccb0924aadb4cc74719570` |
| `origin/main` at setup | `b7aaee2` — `deps:(deps): bump redix from 1.9.2 to 1.10.0` (#334), one upstream commit ahead of the `svge-main` base |
| `svge-main` at setup | the base above, with no fork commits yet |
| Tags | none pushed for fork work |

`origin/main` moving does not move `svge-main`. Catching up is the sync below, done on purpose.

## Branches

| Branch | Role | How it moves |
| --- | --- | --- |
| `main` | Upstream mirror. No fork commits. | Fast-forward from upstream `main` only. |
| `svge-main` | Integration branch. Feature branches come off it. Pull requests target it. Not the default. | Merge `main` into it. Do not rebase it. |
| `feat/*` | One phase each. | Cut from `svge-main`. Open the pull request against `svge-main`. |

Merges into `svge-main` are merge commits, on the maintainer's go, with CI green.

## Sync

Add the upstream remote once:

```sh
git remote add upstream https://github.com/zoedsoupe/anubis-mcp.git
```

Then:

1. `git fetch upstream`
2. Fast-forward `main`: `git checkout main && git merge --ff-only upstream/main`, then push `main`. If it is not a fast-forward, stop. `main` has a fork commit and must be reset to upstream before any other work. Never merge a fork branch into `main`. Never force-push `main`.
3. Update `svge-main`: `git checkout svge-main && git merge main`. Leave the merge commit. Do not rebase `svge-main`. Open feature branches and the recorded base depend on its history.
4. For a feature branch that already has an open pull request, merge the updated `svge-main` into that branch. Do not rebase a published branch.
5. A feature branch that has never been pushed may be rebased onto the updated `svge-main`, so the series stays easy to replay onto upstream later.

### When to merge, when to rebase

| | Merge | Rebase |
| --- | --- | --- |
| `main` catching upstream | No. Fast-forward only. | No. |
| `svge-main` catching `main` | Yes. This is the shared base. | No. It rewrites every open feature branch. |
| Feature branch, not yet pushed | Either. Rebase if you want a straight series. | Yes, onto `svge-main`. |
| Feature branch with an open pull request | Yes. Merge `svge-main` in. | No. |

### Staying upstreamable

- Keep fork-only files out of library commits: this file, `config/boundary_deny.txt`, `config/boundary_allow.txt`, and the `svge-main` CI trigger.
- A later upstream pull request is a fresh branch from upstream `main` with the library commits replayed onto it, without those fork-only files.
- `mix anubis.boundary` must pass on the fork. It fails if a denied word shows up outside the allow list.

## CI

`.github/workflows/ci.yml` is upstream's workflow, also triggered on pushes to `svge-main` and on pull requests into `svge-main`. It compiles, checks formatting, runs Credo, Dialyzer, and tests, and runs `mix anubis.boundary` in the lint job. Publish and release workflows stay on `main` only.

## Branch protection

Protection on `svge-main` needs a repository admin. The settings to apply are in the pull request that added this file. This document does not change the default branch.
