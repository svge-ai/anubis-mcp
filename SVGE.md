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

`main` only fast-forwards to upstream `main` (`git merge --ff-only`, then a plain push). No fork commits, no force-push, and no tags.

Upstream releases come into `svge-main` by merging their release commit, one release per pull request.

`feat/*` rebases onto `svge-main` before review.

`upstream/*` rebases onto upstream `main`.

The version scheme is `2.2.0-svge.N`.

## CI

`.github/workflows/ci.yml` is upstream's workflow, also triggered on pushes to `svge-main` and on pull requests into `svge-main`. It compiles, checks formatting, runs Credo, Dialyzer, and tests, and runs `mix anubis.boundary` in the lint job. Publish and release workflows stay on `main` only.

## Branch protection

Protection on `svge-main` needs a repository admin. The settings to apply are in the pull request that added this file. This document does not change the default branch.
