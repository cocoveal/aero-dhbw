# Multiple authors support — design

**Date:** 2026-05-29
**Status:** Approved (pending spec review)

## Goal

Let `aero-dhbw` produce a thesis authored by more than one student (DHBW joint
theses / "Gruppenarbeit"), where each author has their own name, matriculation
number, and course acronym. Single-author documents must render **byte-for-byte
identically** to today.

Weighted to the README philosophy: lightweight (no new top-level params),
straightforward (one obvious way per case), easily extensible (each author is a
self-contained record).

## Public API

`aero-dhbw()`'s parameters are unchanged. The `author` parameter becomes
**polymorphic**:

- **String** → single author. Uses the existing top-level `mat-number` and
  `course-acronym`. Current behaviour, untouched.
- **Array of dicts** → multiple authors. Each entry is
  `(name: …, mat-number: …, course-acronym: …)`. Top-level `mat-number` /
  `course-acronym` are ignored in this case. Missing dict keys default to empty;
  a bare string array entry is treated as a name-only author.

`course`, `university`, `company`, `supervisor`, `university-supervisor`,
`place-of-authorship`, dates, etc. remain shared (one program / company / date
per thesis).

### Examples

```typst
// Single author — unchanged
author: "Jane Doe",
mat-number: "123456",
course-acronym: "TINF22",

// Multiple authors
author: (
  (name: "Jane Doe",       mat-number: "123456", course-acronym: "TINF22"),
  (name: "Max Mustermann", mat-number: "789012", course-acronym: "TINF22"),
),
```

## Internal representation

A single normalization helper turns `author` into a **list of author dicts** —
the one shape every downstream function consumes:

```typst
#let normalize-authors(author, mat-number, course-acronym) = {
  if type(author) == array {
    author.map(a => if type(a) == dictionary {
      (
        name: a.at("name", default: ""),
        mat-number: a.at("mat-number", default: ""),
        course-acronym: a.at("course-acronym", default: ""),
      )
    } else {
      (name: a, mat-number: "", course-acronym: "")  // bare string => name only
    })
  } else {
    // string/content => single author using the top-level fields
    ((name: author, mat-number: mat-number, course-acronym: course-acronym),)
  }
}
```

`aero-dhbw()` computes `let authors = normalize-authors(author, mat-number,
course-acronym)` once and passes `authors` (the list) to `titlepage` and
`declaration`. Those two **internal** (non-exported) functions drop their
`author` / `mat-number` / `course-acronym` parameters in favor of a single
`authors` parameter, so each iterates one clean structure.

`set document(author: authors.map(a => a.name))` — Typst's document metadata
accepts an array of name strings.

## Title page

- Under "by" / "von", author names are **stacked**, one per line
  (`authors.map(a => a.name)` joined with line breaks).
- The "Student ID, Course" grid row repeats **per author**: the first author's
  row carries the label + their `mat-number, course-acronym`; each further
  author adds a row with an empty label cell + their values.

For a single author this produces exactly the current output (one name, one ID
row).

```
                  by
              Jane Doe
              Max Mustermann

Completion Period    01.01.2025 - 01.01.2026
Student ID, Course   123456, TINF22
                     789012, TINF22
Cooperation Partner  ACME Corp, Stuttgart
```

## Declaration of Authorship

The heading and the regulation-citation paragraph are unchanged. The declaration
body uses **plural wording when `authors.len() > 1`**, and renders one signature
block per author.

### Wording (verify these strings)

**English — singular (current):**
> I hereby declare that I have authored my {project-type} {project} on the topic: … independently and have used no other sources or aids than those indicated. I also declare that the submitted electronic version corresponds to the printed version.

**English — plural:**
> We hereby declare that we have authored our {project-type} {project} on the topic: … independently and have used no other sources or aids than those indicated. We also declare that the submitted electronic version corresponds to the printed version.

**German — singular (current):**
> Ich versichere hiermit, dass ich meine {project-type} {project} mit dem Thema: … selbstständig verfasst und keine anderen als die angegebenen Quellen und Hilfsmittel benutzt habe. Ich versichere zudem, dass alle eingereichten Fassungen übereinstimmen.

**German — plural:**
> Wir versichern hiermit, dass wir unsere {project-type} {project} mit dem Thema: … selbstständig verfasst und keine anderen als die angegebenen Quellen und Hilfsmittel benutzt haben. Wir versichern zudem, dass alle eingereichten Fassungen übereinstimmen.

(Plural diffs: I→We / Ich→Wir, my→our / meine→unsere, "I also"→"We also" /
"Ich versichere"→"Wir versichern", and the German verb "habe"→"haben".)

### Signatures

One shared place/date line, then a **stacked signature block per author**:

```
{place-of-authorship}, {date}

<gap>
______________________________
{author 1 name}

<gap>
______________________________
{author 2 name}
```

For a single author this is identical to the current layout (place/date, gap,
line, name).

## Documentation updates

- **README.md** — remove the "doesn't support multiple authors" note; in the
  config table, note that `author` accepts a name string or an array of author
  dicts; add a "Multiple authors" example.
- **template/main.typ** — add a brief commented multi-author example near the
  `author` field.
- **CLAUDE.md** — note the polymorphic `author` + normalized `authors` list, and
  that `titlepage`/`declaration` consume that list.
- **typst.toml** — add `docs` to `exclude` so the spec is not bundled (the
  publish allowlist in `scripts/package` already omits it; this is for parity).

## Verification

Reuse the deterministic-PNG harness from the de-dup work:

1. **Backward compatibility:** before any change, render the single-author title
   page + declaration in EN and DE → baseline hashes. After the change, confirm
   the single-author renders are **byte-for-byte identical**.
2. **New behaviour:** render a 2-author document (EN and DE) and visually confirm
   the stacked names, per-author ID rows, plural declaration wording, and two
   signature blocks.
3. `scripts/test` (full template compiles) and CI must stay green.

## Out of scope (YAGNI)

- No per-author affiliations, emails, ORCIDs, or titles — only
  `name + mat-number + course-acronym`.
- No per-author signing place/date (one shared place/date).
- No "who wrote which chapter" attribution in the declaration.

## Affected files

- `src/aero-dhbw.typ` — add `normalize-authors`; pass `authors` to sub-functions;
  `set document` name array.
- `src/titlepage.typ` — `authors` param; stacked names; per-author ID rows.
- `src/declaration.typ` — `authors` param; singular/plural wording; per-author
  signatures.
- `README.md`, `template/main.typ`, `CLAUDE.md`, `typst.toml` — docs/metadata.
