# .github

Account-wide **default community health files**. GitHub falls back to this repository for any
`richardwooding/*` repo that does not ship its own copy of a given file, so a convention lives here
once instead of being copied into eighty repos.

| File | Serves |
| --- | --- |
| `.github/FUNDING.yml` | the **Sponsor** button on every repo without a `FUNDING.yml` of its own |
| `scripts/sponsor-sweep.sh` | adds the standard `## Sponsor` README section to a named repo; idempotent |

## Precedence

A repo-level file **wins outright** — there is no merge. Two forks rely on that and must keep their
own files, because they name the *upstream* maintainers rather than this account:

- `richardwooding/go-app` → `maxence-charriere`
- `richardwooding/gotreesitter` → `odvcencio`

A fork advertising the upstream author's sponsorship is the correct behaviour, not a bug to tidy up.

## Two things deliberately absent

**No `profile/README.md`.** The GitHub profile README lives in
[`richardwooding/richardwooding`](https://github.com/richardwooding/richardwooding). A `profile/`
directory here would silently take over the profile page.

**No default `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` or issue templates.** Each of
those would hand ~80 repos — toys and experiments included — a policy they have never stated, and a
security policy that nobody is actually operating is worse than none. That is a larger decision than
a Sponsor button and should be taken on its own, per file, if ever.

## Adding funding to a new repo

Nothing to do. The default applies the moment the repo exists. Add a per-repo
`.github/FUNDING.yml` **only** when a repo needs a *different* target — a co-maintained project, or
a fork where the button should point elsewhere.
