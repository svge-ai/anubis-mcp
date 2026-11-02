# Fork sync

`main` is an exact mirror of upstream [anubis-mcp](https://github.com/zoedsoupe/anubis-mcp) and stays the default branch. `svge-main` is the integration branch. It was cut from upstream `cdb9cd6498b5b1e0d9ccb0924aadb4cc74719570` (`chore: release 2.2.0`, #327), not from the tip of `main`.

Do not push tags.

## Status

| Feature | Commits on svge-main | Upstream PR | Status | Ticket |
| --- | --- | --- | --- | --- |
| Fork setup | none yet | none | in review | SVG-1085 |

### SVG-1089

| Feature | Commits on svge-main | Upstream PR | Status | Ticket |
| --- | --- | --- | --- | --- |

## Sync

Add the upstream remote once:

```sh
git remote add upstream https://github.com/zoedsoupe/anubis-mcp.git
```

Fast-forward `main` to upstream `main`, then push it:

```sh
git checkout main
git merge --ff-only upstream/main
git push origin main
```

If `main` can't fast-forward, stop and move the stray commit to a feature branch first. No fork commits on `main`, no force-push, and no tags.

Never rebase `svge-main`; it is shared and pinned by downstream apps.

Upstream releases come into `svge-main` by merging their release commit, one release per pull request.

`feat/*` rebases onto `svge-main` before review.

`upstream/*` rebases onto upstream `main`, never onto `svge-main`, so each can be opened upstream on its own.

The version scheme is `2.2.0-svge.N`, bumped per merged feature.

## Branches

Pull requests target `svge-main`.

| Branch | Role |
| --- | --- |
| `main` | Exact mirror of upstream `main`. Default branch. Fast-forward only. |
| `svge-main` | Integration branch. Pull requests target `svge-main`. Never rebase it. |
| `feat/<topic>` | One feature, cut from `svge-main`. Rebase onto `svge-main` before review. The pull request targets `svge-main`. |
| `upstream/<topic>` | One change for upstream. Rebase onto upstream `main`, never onto `svge-main`, so each can be opened upstream on its own. |

## Keeping branches upstreamable

- No app names or concepts. `mix anubis.boundary` enforces this.
- Keep upstream's format, Credo, and Dialyzer settings.
- One feature per commit series.
- Tests follow upstream's style.

## CI

`.github/workflows/ci.yml` is upstream's workflow, also triggered on pushes to `svge-main` and on pull requests into `svge-main`. It compiles, checks formatting, runs Credo, Dialyzer, and tests, and runs `mix anubis.boundary` in the lint job. Publish and release workflows stay on `main` only. Actions on this fork stay off for now; run those checks locally and record the results on the pull request.

## Branch protection

Protection on `svge-main` needs a repository admin. The settings to apply are in the pull request that added this file. This document does not change the default branch.
