# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`aero-dhbw` is a **Typst template package** (published to the Typst Universe registry as `@preview/aero-dhbw`) for writing theses/papers at DHBW Ravensburg. It is a library, not an application: the deliverable is the `src/` package plus the `template/` starter scaffold that `typst init` copies for end users.

The package is bilingual (German default, English) and single-author only.

## Layout

- `src/aero-dhbw.typ` — the package entrypoint (`entrypoint` in `typst.toml`). Exports `aero-dhbw` (the document show-function users apply via `#show: aero-dhbw.with(...)`) and `pa-figure`. This single file orchestrates the **entire document flow and all global styling**.
- `src/titlepage.typ` — `titlepage()` cover-page function.
- `src/declaration.typ` — `declaration()` Declaration of Authorship / Erklärung (legally-worded, references specific DHBW regulations — do not casually reword the legal sentences).
- `src/themes/acronym-theme.typ` — `theme-pa`, the rendering theme passed to the `glossy` glossary package.
- `template/` — the starter project scaffold (`[template]` in `typst.toml`, entrypoint `main.typ`). `main.typ` declares config vars and applies the show-function; chapter content lives in `template/chapters/`, acronyms in `template/acronyms.typ`. This is what users get, so keep it minimal and well-commented rather than feature-complete.

## Dependencies

- `@preview/glossy:0.9.0` — acronyms/glossary (acronyms are referenced like labels: `@usa`; use `@usa:both` in headings to avoid the long-form leaking into the outline).
- Default font is **Libertinus Serif**; default bib/citation style is IEEE.

## Build & test

There is no unit-test suite. The smoke test is "does the template still compile against the current source", and it's scripted:

```sh
scripts/test    # installs the working tree to @local and compiles the template against it
```

This is the canonical check. It runs in CI (`.github/workflows/ci.yml`) on every push and PR, and `scripts/release.sh` runs it before tagging — so the same compile gate guards both everyday commits and releases.

**Why a plain compile isn't enough — `@preview` vs `@local`:** `template/main.typ` and `template/chapters/*.typ` import the package as `@preview/aero-dhbw:<version>`, which pulls the **published** version from the registry, *not* your local `src/` edits. So `typst compile template/main.typ` does **not** test your `src/` changes. `scripts/test` works around this by installing the working tree under the `@local` namespace and rewriting the imports in a throwaway copy of the template.

For interactive work, `scripts/package @local` installs the working tree to `~/.local/share/typst/packages/local/aero-dhbw/<version>`; then point a scratch file at `@local/aero-dhbw:<version>` (the git-ignored `cur-dev/` dir is for this). **Never commit `@local` imports** — `release.sh` normalises them back to `@preview`, but historically several bugs came from a stray `@local` slipping into a release.

## Releasing / version bumps

Publishing to Typst Universe is a **PR to the `typst/packages` repo** (there is no `typst publish`): files land under `packages/preview/aero-dhbw/<version>/`, a maintainer merges, and it's live within ~30 min. **Published versions are immutable** — you can never edit `0.1.1`, only ship a strictly-greater version.

Cut a release with the script — do not hand-edit version strings:

```sh
scripts/release.sh 0.1.2     # bump + sync + smoke-test + lint + commit + tag
git push --follow-tags       # triggers .github/workflows/release.yml
```

`scripts/release.sh` is the single entry point. It bumps `typst.toml`, rewrites **every** `@preview/aero-dhbw:<version>` import in `template/**/*.typ` and `README.md` to match (also normalising any stray `@local` import back to `@preview`), smoke-compiles the template against a `@local` install of the new source, runs `typst-package-check` if present, then commits + tags `v<version>`. The version is duplicated across those files only because Universe requires templates to use absolute `@preview` imports — the script is what keeps them in sync, which was historically the #1 source of bugs (see commits "i forgor to change version in manifest").

`scripts/package <target>` is the shared bundler: `scripts/package @local` installs the working tree into the local Typst dir for testing; `scripts/package out` stages the bundle for CI. The `contents` allowlist in that script and `exclude` in `typst.toml` must agree on what ships.

On `git push --follow-tags`, `release.yml` builds the bundle, makes a GitHub release, and pushes a branch to your fork of `typst/packages` — you then open the PR by hand. **One-time setup:** fork `typst/packages`, set `REGISTRY_FORK` in the workflow to that fork, and add a push-capable PAT as the `REGISTRY_TOKEN` repo secret. The merge itself is done by a Typst maintainer and cannot be automated.

## Conventions when editing `aero-dhbw.typ`

- **Localization pattern:** strings (`outline-title`, `bib-title`, AI-usage labels, …) are assigned in an `if text-lang == "en" { ... } else { ... }` block near the top, then referenced below. `titlepage.typ` and `declaration.typ` follow the same philosophy: each assigns only the language-specific strings in an `if`/`else`, then renders one shared layout — so add/change a layout element **once**, and only edit the `if`/`else` to add a translated string.
- **Dual captions:** `pa-figure` + `flex-caption` + the `_in-outline` state implement short-vs-long captions (short shows in the List of Figures/Tables, long shows under the figure). Captions may be `content` (used in both places) or a `(long:, short:)` dictionary.
- **Document flow is fixed and ordered** inside `aero-dhbw()`: titlepage → (optional) confidentiality notice → declaration → (optional) abstract → ToC → list of figures → list of tables → glossary → body → bibliography → (optional) AI-usage table → (optional) annex. Page numbering resets and `set page(...)`/heading `show` rules are reconfigured at specific points in this sequence — moving a block can break numbering or heading styling.
- Annex numbering switches headings to `A.1` and resets the heading counter; figure numbering is `<chapter>.<n>` in the body and `A.<n>` in the annex.

## Config surface

All user-facing options (with required/optional/default) are documented in `README.md`'s "Configuration Options" table — keep that table in sync when you add, rename, or change defaults for any `aero-dhbw()` parameter.
