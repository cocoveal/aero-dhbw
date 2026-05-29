# Multiple Authors Support — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let `aero-dhbw` render a thesis with multiple authors (name + matriculation number + course acronym each), while single-author documents stay byte-for-byte identical.

**Architecture:** `author` becomes polymorphic (string → single, array of dicts → multiple). `aero-dhbw()` normalizes it to a list of author dicts via a new `normalize-authors` helper, then passes that list to the internal `titlepage`/`declaration` functions, which iterate it. The declaration switches to plural wording for >1 author.

**Tech Stack:** Typst 0.14.x. No unit-test framework exists; verification is (a) `#assert` for the pure helper and (b) deterministic PNG-hash comparison for rendered output (single-author must match a pre-change baseline; multi-author confirmed visually). Spec: `docs/superpowers/specs/2026-05-29-multiple-authors-design.md`.

---

## File Structure

- `src/aero-dhbw.typ` — add top-level `normalize-authors`; in `aero-dhbw()`, compute `authors`, set document name array, pass `authors` to sub-functions.
- `src/titlepage.typ` — swap `author`/`mat-number`/`course-acronym` params for `authors`; stacked names; per-author ID rows.
- `src/declaration.typ` — swap `author` param for `authors`; singular/plural wording; per-author signatures.
- `README.md`, `template/main.typ`, `CLAUDE.md`, `typst.toml` — docs + metadata.
- Verification harness lives in `/tmp/ma-verify` (throwaway, never committed).

---

### Task 1: Establish the single-author regression baseline

Renders the **current** `titlepage` + `declaration` (single author, EN + DE) to PNGs and records their hashes. Tasks 3 and 5 must reproduce these exactly.

**Files:**
- Create: `/tmp/ma-verify/test-title.typ`, `/tmp/ma-verify/test-decl.typ` (harness; not committed)

- [ ] **Step 1: Set up the harness dir with current src**

```bash
cd /home/kyon/dev/projects/aero-dhbw
WORK=/tmp/ma-verify
mkdir -p "$WORK/src" "$WORK/template/resources"
cp src/*.typ "$WORK/src/"
cp template/resources/dhbw-logo.png "$WORK/template/resources/"
```

- [ ] **Step 2: Write the single-author harness files (CURRENT API)**

Create `/tmp/ma-verify/test-title.typ`:

```typst
#import "src/titlepage.typ": titlepage
#let args = (
  title: [A Sample Thesis Title], course: "Computer Science",
  start-date: "01.01.2025", end-date: "01.01.2026", company-location: "Stuttgart",
  project: "T1000", project-type: "Bachelor Thesis", supervisor: "John Smith",
  university-supervisor: "Prof. Dr. Mueller", company: "ACME Corp",
  university: "DHBW Ravensburg",
  company-logo: image("template/resources/dhbw-logo.png"),
  university-logo: image("template/resources/dhbw-logo.png"),
)
#titlepage(author: "Jane Doe", mat-number: "123456", course-acronym: "TINF22", text-lang: "en", ..args)
#pagebreak()
#titlepage(author: "Jane Doe", mat-number: "123456", course-acronym: "TINF22", text-lang: "de", ..args)
```

Create `/tmp/ma-verify/test-decl.typ`:

```typst
#import "src/declaration.typ": declaration
#let d = (title: [A Sample Thesis Title], project: "T1000", project-type: "Bachelor Thesis", place-of-authorship: "Stuttgart", date: datetime(year: 2026, month: 1, day: 1))
#declaration(author: "Jane Doe", lang: "en", ..d)
#pagebreak()
#declaration(author: "Jane Doe", lang: "de", ..d)
```

- [ ] **Step 3: Render baseline + confirm determinism**

```bash
cd /tmp/ma-verify
for f in test-title test-decl; do
  typst compile --root . "$f.typ" "base-$f-{p}.png"
  typst compile --root . "$f.typ" "recheck-$f-{p}.png"
done
for b in base-*.png; do
  r="${b/base/recheck}"
  [ "$(sha256sum <"$b")" = "$(sha256sum <"$r")" ] && echo "det ok: $b" || echo "NON-DET: $b"
done
sha256sum base-*.png | tee /tmp/ma-verify/BASELINE.sha
```
Expected: every line "det ok"; `BASELINE.sha` lists hashes for `base-test-title-1/2` (EN/DE title) and `base-test-decl-1/2` (EN/DE declaration). **Do not commit anything in this task.**

---

### Task 2: Add the `normalize-authors` helper

**Files:**
- Modify: `src/aero-dhbw.typ` (add a top-level `#let` before `#let aero-dhbw(`)
- Test: `/tmp/ma-verify/test-normalize.typ`

- [ ] **Step 1: Write the failing test**

Create `/tmp/ma-verify/test-normalize.typ`:

```typst
#import "src/aero-dhbw.typ": normalize-authors

// string -> single author using top-level fields
#assert.eq(
  normalize-authors("Jane", "123", "TINF22"),
  ((name: "Jane", mat-number: "123", course-acronym: "TINF22"),),
)
// array of dicts -> as-is (top-level fields ignored)
#assert.eq(
  normalize-authors(((name: "A", mat-number: "1", course-acronym: "X"),
                     (name: "B", mat-number: "2", course-acronym: "Y")), [], []),
  ((name: "A", mat-number: "1", course-acronym: "X"),
   (name: "B", mat-number: "2", course-acronym: "Y")),
)
// missing dict keys default to ""
#assert.eq(
  normalize-authors(((name: "A"),), [], []),
  ((name: "A", mat-number: "", course-acronym: ""),),
)
// bare string array entry -> name-only author
#assert.eq(
  normalize-authors(("A", "B"), [], []),
  ((name: "A", mat-number: "", course-acronym: ""),
   (name: "B", mat-number: "", course-acronym: "")),
)
#"ok"
```

- [ ] **Step 2: Run the test, verify it fails**

```bash
cd /tmp/ma-verify && cp /home/kyon/dev/projects/aero-dhbw/src/aero-dhbw.typ src/ && typst compile --root . test-normalize.typ /dev/null
```
Expected: FAIL — `error: unknown variable: normalize-authors` (not yet defined).

- [ ] **Step 3: Implement the helper**

In `src/aero-dhbw.typ`, immediately after the `pa-figure` definition and before `#let aero-dhbw(`, add:

```typst
// Normalize the polymorphic `author` argument into a list of author dicts.
// String -> single author using the top-level mat-number / course-acronym.
// Array  -> multiple authors; each entry a (name, mat-number, course-acronym)
//           dict (missing keys default to ""); a bare string entry is name-only.
#let normalize-authors(author, mat-number, course-acronym) = {
  if type(author) == array {
    author.map(a => if type(a) == dictionary {
      (
        name: a.at("name", default: ""),
        mat-number: a.at("mat-number", default: ""),
        course-acronym: a.at("course-acronym", default: ""),
      )
    } else {
      (name: a, mat-number: "", course-acronym: "")
    })
  } else {
    ((name: author, mat-number: mat-number, course-acronym: course-acronym),)
  }
}
```

- [ ] **Step 4: Run the test, verify it passes**

```bash
cd /tmp/ma-verify && cp /home/kyon/dev/projects/aero-dhbw/src/aero-dhbw.typ src/ && typst compile --root . test-normalize.typ /dev/null && echo PASS
```
Expected: PASS (no assertion errors, prints nothing but exits 0, `echo PASS`).

- [ ] **Step 5: Commit**

```bash
cd /home/kyon/dev/projects/aero-dhbw
git add src/aero-dhbw.typ
git commit -m "feat: add normalize-authors helper"
```

---

### Task 3: Refactor `titlepage` to consume an `authors` list

**Files:**
- Modify: `src/titlepage.typ` (signature + names block + grid ID rows)
- Test: `/tmp/ma-verify/test-title.typ` (update calls to new API), compare to Task 1 baseline

- [ ] **Step 1: Replace `src/titlepage.typ` with the `authors`-based version**

```typst
#let titlepage(
  title: [],
  authors: (),
  course: [],
  start-date: datetime,
  end-date: datetime,
  company-location: [],
  project: [],
  project-type: [],
  supervisor: [],
  university-supervisor: [],
  company: [],
  university: [],
  company-logo: [],
  university-logo: [],
  text-lang: []
) = {

  let cover(source) = {
    set image(height: 2cm, fit: "contain")
    source
  }

  set text(size: 14pt)

  // Localization: only the strings differ between languages; the layout below
  // is written once (same philosophy as the main file, aero-dhbw.typ).
  let degree-line = []
  let by-word = ""
  let supervisor-label = []
  let university-supervisor-label = []
  let period-label = []
  let id-course-label = []
  let partner-label = []

  if text-lang == "en" {
    degree-line = [of Degree Course #course \ at #university]
    by-word = "by"
    supervisor-label = [Company Supervisor]
    university-supervisor-label = [University Supervisor]
    period-label = [Completion Period]
    id-course-label = [Student ID, Course]
    partner-label = [Cooperation Partner]
  } else {
    degree-line = [Des Studienganges #course \ an der #university]
    by-word = "von"
    supervisor-label = [Betreuer der Ausbildungsfirma]
    university-supervisor-label = [Gutachter der DHBW]
    period-label = [Bearbeitungszeitraum]
    id-course-label = [Matrikelnummer, Kurs]
    partner-label = [Dualer Partner]
  }

  v(-1cm)

  align(top,
    block(
      width: 100%,
      inset: (x: -1cm))[
        #stack(
        dir: ltr,
        if company-logo != [] {
          align(left, cover(company-logo))
        },
        align(right, cover(university-logo)),
      )
    ]
  )

  v(6em)

  set align(center)

  par(leading: 1em, text(20pt)[*#title*])

  v(4em)

  text(size: 16pt)[#project-type (#project)]

  v(2em)

  degree-line

  v(4em)

  [#by-word \ #authors.map(a => a.name).join(linebreak())]

  v(2em)
  end-date

  v(2em)

  set rect(width: 100%, inset: 0.5em)

  let parsed = ()

  if supervisor != [] {
    parsed.push(supervisor-label)
    parsed.push(supervisor)
  }

  if university-supervisor != [] {
    parsed.push(university-supervisor-label)
    parsed.push(university-supervisor)
  }

  // One "Student ID, Course" row per author: label on the first row only.
  let id-rows = ()
  for (i, a) in authors.enumerate() {
    id-rows.push(if i == 0 { id-course-label } else { [] })
    id-rows.push([#a.mat-number, #a.course-acronym])
  }

  align(left,
    grid(
      columns: (1fr, 1fr),
      align: left,
      inset: 0.5em,
      period-label,
      [#start-date - #end-date],
      ..id-rows,
      partner-label,
      [#par(justify: true)[#company, #company-location]],
      ..parsed
    )
  )
}
```

- [ ] **Step 2: Update the title harness to the new API**

Replace `/tmp/ma-verify/test-title.typ` with:

```typst
#import "src/titlepage.typ": titlepage
#let args = (
  title: [A Sample Thesis Title], course: "Computer Science",
  start-date: "01.01.2025", end-date: "01.01.2026", company-location: "Stuttgart",
  project: "T1000", project-type: "Bachelor Thesis", supervisor: "John Smith",
  university-supervisor: "Prof. Dr. Mueller", company: "ACME Corp",
  university: "DHBW Ravensburg",
  company-logo: image("template/resources/dhbw-logo.png"),
  university-logo: image("template/resources/dhbw-logo.png"),
)
#let one = ((name: "Jane Doe", mat-number: "123456", course-acronym: "TINF22"),)
#titlepage(authors: one, text-lang: "en", ..args)
#pagebreak()
#titlepage(authors: one, text-lang: "de", ..args)
```

Also create `/tmp/ma-verify/test-title-multi.typ` (visual check, 2 authors):

```typst
#import "src/titlepage.typ": titlepage
#let args = (
  title: [A Sample Thesis Title], course: "Computer Science",
  start-date: "01.01.2025", end-date: "01.01.2026", company-location: "Stuttgart",
  project: "T1000", project-type: "Bachelor Thesis", supervisor: "John Smith",
  university-supervisor: "Prof. Dr. Mueller", company: "ACME Corp",
  university: "DHBW Ravensburg",
  company-logo: image("template/resources/dhbw-logo.png"),
  university-logo: image("template/resources/dhbw-logo.png"),
)
#let two = (
  (name: "Jane Doe", mat-number: "123456", course-acronym: "TINF22"),
  (name: "Max Mustermann", mat-number: "789012", course-acronym: "TINF22"),
)
#titlepage(authors: two, text-lang: "en", ..args)
#pagebreak()
#titlepage(authors: two, text-lang: "de", ..args)
```

- [ ] **Step 3: Render and compare single-author title to baseline**

```bash
cd /tmp/ma-verify
cp /home/kyon/dev/projects/aero-dhbw/src/titlepage.typ src/
typst compile --root . test-title.typ now-test-title-{p}.png
for p in 1 2; do
  base=$(sha256sum <"base-test-title-$p.png"); now=$(sha256sum <"now-test-title-$p.png")
  [ "$base" = "$now" ] && echo "IDENTICAL title-$p" || echo "DIFFERS title-$p"
done
```
Expected: `IDENTICAL title-1` (EN) and `IDENTICAL title-2` (DE). If either DIFFERS, the names-block or grid-row construction changed the layout — diff against the baseline image and adjust whitespace until identical before continuing.

- [ ] **Step 4: Render the 2-author title and eyeball it**

```bash
cd /tmp/ma-verify && typst compile --root . test-title-multi.typ multi-title-{p}.png && echo "rendered multi-title-1 (en) / multi-title-2 (de)"
```
Open `multi-title-1.png` / `multi-title-2.png`: confirm both names stacked under "by"/"von", and two "Student ID, Course" rows (label on the first only): `123456, TINF22` then `789012, TINF22`.

- [ ] **Step 5: Commit**

```bash
cd /home/kyon/dev/projects/aero-dhbw
git add src/titlepage.typ
git commit -m "feat: render multiple authors on the title page"
```

---

### Task 4: Refactor `declaration` to consume `authors` (plural + per-author signatures)

**Files:**
- Modify: `src/declaration.typ` (signature + plural wording + signature loop)
- Test: `/tmp/ma-verify/test-decl.typ` (new API), compare to Task 1 baseline; `/tmp/ma-verify/test-decl-multi.typ` (visual)

- [ ] **Step 1: Replace `src/declaration.typ` with the `authors`-based version**

```typst
#let declaration(
  title: [],
  authors: (),
  project: [],
  project-type: [],
  place-of-authorship: [],
  date: [],
  lang: "de"
) = {
  set align(left)

  let plural = authors.len() > 1

  // Localization: language-specific strings assigned here, layout written once.
  let heading-title = ""
  let regulation = []
  let intro = []
  let closing = []
  let date-line = []

  if lang == "en" {
    heading-title = "Declaration of Authorship"
    regulation = [In accordance with Section 1.1.14 of Appendix 1 to §§ 3, 4 and 5 of the Study and Examination Regulations for Bachelor’s Degree Programs in the Technical Field of the Baden-Württemberg Cooperative State University dated September 2017, as amended on July 24, 2023.]
    if plural {
      intro = [We hereby declare that we have authored our #project-type #project on the topic:]
      closing = [independently and have used no other sources or aids than those indicated. We also declare that the submitted electronic version corresponds to the printed version.]
    } else {
      intro = [I hereby declare that I have authored my #project-type #project on the topic:]
      closing = [independently and have used no other sources or aids than those indicated. I also declare that the submitted electronic version corresponds to the printed version.]
    }
    date-line = [#place-of-authorship, #datetime.display(date, "[month repr:long] [day], [year]")]
  } else {
    heading-title = "Erklärung"
    regulation = [gemäß Ziffer 1.1.14 der Anlage 1 zu §§ 3, 4 und 5 der Studien- und Prüfungsordnung für die Bachelorstudiengänge im Studienbereich Technik der Dualen Hochschule Baden-Württemberg vom 29.09.2017 in der Fassung vom 24.07.2023.]
    if plural {
      intro = [Wir versichern hiermit, dass wir unsere #project-type #project mit dem Thema:]
      closing = [selbstständig verfasst und keine anderen als die angegebenen Quellen und Hilfsmittel benutzt haben. Wir versichern zudem, dass alle eingereichten Fassungen übereinstimmen.]
    } else {
      intro = [Ich versichere hiermit, dass ich meine #project-type #project mit dem Thema:]
      closing = [selbstständig verfasst und keine anderen als die angegebenen Quellen und Hilfsmittel benutzt habe. Ich versichere zudem, dass alle eingereichten Fassungen übereinstimmen.]
    }
    date-line = [#place-of-authorship, den #datetime.display(date, "[day].[month].[year]")]
  }

  // One shared place/date line, then a stacked signature block per author.
  let signatures = []
  for a in authors {
    signatures = signatures + [
      #v(4em)

      #line(length: 14em, stroke: 0.5pt)

      #v(2em)

      #a.name
    ]
  }

  set text(lang: lang)
  [
    #heading(heading-title, outlined: false)
    #set par(justify: true)

    #regulation

    #v(2em)
    #intro

    #v(2em)
    #align(center, block(inset: (x: 3em), emph(title)))
    #v(2em)

    #closing

    #v(6em)

    #date-line

    #signatures
  ]
}
```

- [ ] **Step 2: Update the declaration harness to the new API**

Replace `/tmp/ma-verify/test-decl.typ`:

```typst
#import "src/declaration.typ": declaration
#let d = (title: [A Sample Thesis Title], project: "T1000", project-type: "Bachelor Thesis", place-of-authorship: "Stuttgart", date: datetime(year: 2026, month: 1, day: 1))
#let one = ((name: "Jane Doe", mat-number: "123456", course-acronym: "TINF22"),)
#declaration(authors: one, lang: "en", ..d)
#pagebreak()
#declaration(authors: one, lang: "de", ..d)
```

Create `/tmp/ma-verify/test-decl-multi.typ`:

```typst
#import "src/declaration.typ": declaration
#let d = (title: [A Sample Thesis Title], project: "T1000", project-type: "Bachelor Thesis", place-of-authorship: "Stuttgart", date: datetime(year: 2026, month: 1, day: 1))
#let two = (
  (name: "Jane Doe", mat-number: "123456", course-acronym: "TINF22"),
  (name: "Max Mustermann", mat-number: "789012", course-acronym: "TINF22"),
)
#declaration(authors: two, lang: "en", ..d)
#pagebreak()
#declaration(authors: two, lang: "de", ..d)
```

- [ ] **Step 3: Render and compare single-author declaration to baseline**

```bash
cd /tmp/ma-verify
cp /home/kyon/dev/projects/aero-dhbw/src/declaration.typ src/
typst compile --root . test-decl.typ now-test-decl-{p}.png
for p in 1 2; do
  base=$(sha256sum <"base-test-decl-$p.png"); now=$(sha256sum <"now-test-decl-$p.png")
  [ "$base" = "$now" ] && echo "IDENTICAL decl-$p" || echo "DIFFERS decl-$p"
done
```
Expected: `IDENTICAL decl-1` (EN) and `IDENTICAL decl-2` (DE). If DIFFERS, the most likely cause is the parbreak spacing around `#signatures`; the single-author `signatures` must reduce to `v(4em)`, parbreak, line, parbreak, `v(2em)`, parbreak, name (the exact pre-change tail). Adjust the blank lines inside the `for` body / before `#signatures` until identical.

- [ ] **Step 4: Render the 2-author declaration and eyeball it**

```bash
cd /tmp/ma-verify && typst compile --root . test-decl-multi.typ multi-decl-{p}.png && echo "rendered multi-decl-1 (en) / multi-decl-2 (de)"
```
Open `multi-decl-1.png`: text reads "**We** hereby declare that **we** have authored **our** …" and there are **two** signature lines (Jane Doe, Max Mustermann). Open `multi-decl-2.png`: "**Wir** versichern hiermit, dass **wir unsere** … verfasst und … benutzt **haben**. **Wir** versichern zudem …" with two signature lines.

- [ ] **Step 5: Commit**

```bash
cd /home/kyon/dev/projects/aero-dhbw
git add src/declaration.typ
git commit -m "feat: plural declaration wording and a signature per author"
```

---

### Task 5: Wire `aero-dhbw()` to normalize and pass `authors`

**Files:**
- Modify: `src/aero-dhbw.typ` (compute `authors`; `set document`; `titlepage`/`declaration` calls)

- [ ] **Step 1: Compute `authors` near the top of the function body**

In `src/aero-dhbw.typ`, inside `aero-dhbw(...) = {`, immediately after the package imports (the `import "@preview/glossy..."` / `import "themes/acronym-theme.typ"` block), add:

```typst
  // Normalize the polymorphic author argument into a list of author dicts.
  let authors = normalize-authors(author, mat-number, course-acronym)
```

- [ ] **Step 2: Update `set document` to a name array**

Change:

```typst
  set document(
    author: author,
    title: title,
  )
```
to:

```typst
  set document(
    author: authors.map(a => a.name),
    title: title,
  )
```

- [ ] **Step 3: Update the `titlepage(...)` call**

In the `titlepage(` call, remove the `author:`, `mat-number:`, and `course-acronym:` lines and add an `authors:` line. The argument block becomes:

```typst
  titlepage(
    title: title,
    authors: authors,
    course: course,
    start-date: show_date(start-date),
    end-date: show_date(end-date),
    company-location: company-location,
    project: project,
    project-type: project-type,
    supervisor: supervisor,
    university-supervisor: university-supervisor,
    company: company,
    university: university,
    company-logo: company-logo,
    university-logo: university-logo,
    text-lang: text-lang
  )
```

- [ ] **Step 4: Update the `declaration(...)` call**

Change the `author: author,` line in the `declaration(` call to:

```typst
    authors: authors,
```
so the call reads:

```typst
  declaration(
    title: title,
    authors: authors,
    project: project,
    project-type: project-type,
    date: end-date,
    place-of-authorship: place-of-authorship,
    lang: text-lang
  )
```

- [ ] **Step 5: Verify the full template still compiles (single author)**

```bash
cd /home/kyon/dev/projects/aero-dhbw && scripts/test
```
Expected: `template compiles against @local/aero-dhbw:0.1.1 ✔` (the template's `main.typ` uses a single `author` string — unchanged path).

- [ ] **Step 6: Verify a multi-author document compiles end-to-end via the public API**

```bash
cd /tmp/ma-verify
cp /home/kyon/dev/projects/aero-dhbw/src/*.typ src/
cat > test-full-multi.typ <<'EOF'
#import "src/aero-dhbw.typ": aero-dhbw
#show: aero-dhbw.with(
  title: "A Joint Thesis",
  project: "T1000", project-type: "Bachelor Thesis", course: "Computer Science",
  university: "DHBW Ravensburg", place-of-authorship: "Stuttgart",
  author: (
    (name: "Jane Doe", mat-number: "123456", course-acronym: "TINF22"),
    (name: "Max Mustermann", mat-number: "789012", course-acronym: "TINF22"),
  ),
  start-date: datetime(year: 2025, month: 1, day: 1),
  end-date: datetime(year: 2026, month: 1, day: 1),
  university-logo: image("template/resources/dhbw-logo.png"),
  text-lang: "en",
)
= Introduction
Body text.
EOF
typst compile --root . test-full-multi.typ test-full-multi.pdf && echo "FULL MULTI-AUTHOR COMPILES"
```
Expected: `FULL MULTI-AUTHOR COMPILES`. Open page 1 (title) + the declaration page to confirm both authors appear and the declaration is plural.

- [ ] **Step 7: Commit**

```bash
cd /home/kyon/dev/projects/aero-dhbw
git add src/aero-dhbw.typ
git commit -m "feat: wire multiple authors through aero-dhbw"
```

---

### Task 6: Documentation and packaging metadata

**Files:**
- Modify: `README.md`, `template/main.typ`, `CLAUDE.md`, `typst.toml`

- [ ] **Step 1: README — remove the single-author limitation note**

In `README.md`, delete the two lines under the intro:

```
Note: The template doesn't support multiple authors.
If I find the time in the future (and someone requests it), I'll add support for multiple authors.
```

- [ ] **Step 2: README — update the `author` row in the Configuration Options table**

Change the `author` table row to note the array form. Replace:

```
| author | ✓ | — | Specifies the full name of the author. |
```
with:

```
| author | ✓ | — | Author's full name (string) for a single author, or an array of `(name, mat-number, course-acronym)` dicts for multiple authors. [See example](#multiple-authors) |
```

- [ ] **Step 3: README — add a "Multiple authors" example section**

After the `### `acronym-list`` example block (end of the Examples section), add:

```markdown
### Multiple authors

For a joint thesis, pass an array of author dictionaries to `author`. Each author
carries their own `name`, `mat-number`, and `course-acronym`; the top-level
`mat-number` / `course-acronym` are ignored in this case.

#### Example

​```typ
#show: aero-dhbw.with(
  // other arguments...
  author: (
    (name: "Jane Doe",       mat-number: "123456", course-acronym: "TINF22"),
    (name: "Max Mustermann", mat-number: "789012", course-acronym: "TINF22"),
  ),
)
​```

The title page lists each author (with their own Student ID / Course row) and the
Declaration of Authorship switches to plural wording with one signature line per
author.
```

(Note: in the actual edit, the code fence uses three backticks — the zero-width chars above are only to keep this plan readable.)

- [ ] **Step 4: template/main.typ — show the multi-author option**

In `template/main.typ`, just below the `#let author = ""` line, add a comment:

```typst
// For a joint thesis, set author to an array of dicts instead of a string:
// #let author = (
//   (name: "", mat-number: "", course-acronym: ""),
//   (name: "", mat-number: "", course-acronym: ""),
// )
```

- [ ] **Step 5: CLAUDE.md — document the author model**

In `CLAUDE.md`, under "Conventions when editing `aero-dhbw.typ`", add a bullet:

```markdown
- **Authors:** `author` is polymorphic — a name string (single author, with top-level `mat-number`/`course-acronym`) or an array of `(name, mat-number, course-acronym)` dicts (multiple). `aero-dhbw()` runs it through `normalize-authors` into a list of dicts; `titlepage`/`declaration` consume that list (stacked names + per-author ID row; plural declaration + a signature per author).
```

- [ ] **Step 6: typst.toml — exclude the docs dir from the bundle**

In `typst.toml`, change the `exclude` line to include `docs`:

```toml
exclude = ["scripts", ".github", "CLAUDE.md", ".gitignore", "cur-dev", "docs"]
```

- [ ] **Step 7: Verify template still compiles, then commit**

```bash
cd /home/kyon/dev/projects/aero-dhbw && scripts/test
git add README.md template/main.typ CLAUDE.md typst.toml
git commit -m "docs: document multiple-authors support"
```
Expected: `scripts/test` prints the ✔ line; commit succeeds.

---

### Task 7: Final verification and cleanup

- [ ] **Step 1: Re-confirm single-author backward compatibility end-to-end**

```bash
cd /tmp/ma-verify
cp /home/kyon/dev/projects/aero-dhbw/src/*.typ src/
typst compile --root . test-title.typ fin-title-{p}.png
typst compile --root . test-decl.typ fin-decl-{p}.png
ok=1
for n in title-1 title-2 decl-1 decl-2; do
  [ "$(sha256sum <base-test-$n.png)" = "$(sha256sum <fin-test-$n.png 2>/dev/null || sha256sum <fin-$n.png)" ] && echo "IDENTICAL $n" || { echo "DIFFERS $n"; ok=0; }
done
[ "$ok" = 1 ] && echo "BACKWARD COMPAT HOLDS" || echo "REGRESSION"
```
Expected: four `IDENTICAL` lines + `BACKWARD COMPAT HOLDS`. (Filenames: `fin-title-{1,2}.png`, `fin-decl-{1,2}.png`.)

- [ ] **Step 2: Run the repo smoke test + push the branch**

```bash
cd /home/kyon/dev/projects/aero-dhbw
scripts/test
git push -u origin multiple-authors
```
Expected: ✔ line; branch pushed. CI (`ci.yml`) runs the compile gate on push.

- [ ] **Step 3: Confirm CI is green**

```bash
sleep 25
gh run list --workflow ci.yml --branch multiple-authors --limit 1
```
Expected: a `completed / success` row.

- [ ] **Step 4: Note for the human** — the `/tmp/ma-verify` harness is throwaway and was never committed; no cleanup needed in the repo. Open a PR when ready (`gh pr create --base main --head multiple-authors`).

---

## Self-Review

**Spec coverage:**
- Polymorphic `author` (string/array) → Task 2 (`normalize-authors`) + Task 5 (wiring). ✓
- Per-author `name`/`mat-number`/`course-acronym`, shared `course` → titlepage `authors` param keeps `course` (Task 3). ✓
- Internal list-of-dicts representation; `titlepage`/`declaration` take `authors` → Tasks 3–5. ✓
- `set document(author: array)` → Task 5 Step 2. ✓
- Title page: stacked names + per-author ID rows → Task 3. ✓
- Declaration: plural wording + per-author signatures, shared place/date → Task 4. ✓
- Backward compatibility (single-author byte-identical) → Task 1 baseline + Tasks 3/4/7 hash checks. ✓
- Docs (README, template, CLAUDE.md) + `exclude docs` → Task 6. ✓
- Verification harness (deterministic PNG) → Tasks 1, 3, 4, 5, 7. ✓
- Out of scope (no affiliations/emails, shared place/date) → respected (no such fields added). ✓

**Placeholder scan:** No TBD/TODO. Every code step shows complete code; every command shows expected output. (The README example's backtick-fence note is an authoring aid, not a placeholder.)

**Type consistency:** `normalize-authors(author, mat-number, course-acronym)` returns a list of `(name, mat-number, course-acronym)` dicts — consumed as `a.name` / `a.mat-number` / `a.course-acronym` in titlepage (Task 3) and `a.name` in declaration (Task 4); `authors.map(a => a.name)` in Task 5. `titlepage` param `authors`, `declaration` param `authors` — matches the calls in Task 5. Consistent throughout.
