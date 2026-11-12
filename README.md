# bible-lookup

Look up Bible passages on [BibleGateway](https://www.biblegateway.com/) from Emacs.

## Usage

- `M-x bible-lookup` — prompt for a reference and open it in your default browser. Accepts chapter and verse (`Genesis 1:1`), a range (`John 3:16-17`), or just a chapter (`Psalm 23`). Book names complete with TAB, and the reference at point (if any) is the default.
- `M-x bible-lookup-at-point` — open the reference under the cursor directly. Recognizes full book names and common abbreviations (`Isa 23:1`, `1 Cor 13`, `Gen. 1:1-5`).
- `M-x bible-lookup-again` — reopen the last reference you looked up. With `C-u`, same passage in a different translation.
- `M-x bible-lookup-parallel` — prompt for a reference and two translations, then open them side by side on BibleGateway.
- `M-x bible-lookup-search` — keyword search across the whole text (`in Christ`), not a reference lookup. With `C-u`, prompts for the translation.
- `M-x bible-lookup-search-at-point` — keyword search of the word under the cursor.
- `M-x bible-lookup-lexicon` — lexical concordance search on [Blue Letter Bible](https://www.blueletterbible.org/), linking each hit to its Hebrew or Greek word. With `C-u`, prompts for the translation.
- `M-x bible-lookup-lexicon-at-point` — lexicon search of the word under the cursor.

With a prefix argument (`C-u`), either command first prompts for the translation for that one lookup, without changing `bible-lookup-version`.

## Installation

If you want autoloads:

```elisp
(use-package bible-lookup
  :load-path "/path/to/bible-lookup/"
  :commands (bible-lookup bible-lookup-at-point bible-lookup-again
             bible-lookup-parallel bible-lookup-search
             bible-lookup-search-at-point bible-lookup-lexicon
             bible-lookup-lexicon-at-point))
```

Otherwise use `:demand t`:

```elisp
(use-package bible-lookup
  :load-path "/path/to/bible-lookup/"
  :demand t)
```

For example if you have `.emacs.d/lisp/bible-lookup.el`, do:

```elisp
(use-package bible-lookup
  :load-path "lisp"
  :demand t)
```

## Configuration

The translation defaults to KJV. Set `bible-lookup-version` to any version code BibleGateway recognizes:

```elisp
(setq bible-lookup-version "ESV")
```

`bible-lookup-version-codes` holds the translations offered by the `C-u` prompt; completion is not strict, so any code BibleGateway recognizes works.

Both are also available via `M-x customize-group RET bible-lookup`.

## Offline KJV

The repo bundles the full KJV as `kjv.tsv`. To read it inside Emacs instead of the browser:

```elisp
(setq bible-lookup-backend 'local)
```

`bible-lookup`, `-at-point`, `-again` and `-search` then use the bundled text. A lookup opens a read-only `*KJV*` buffer in a split window, showing the whole chapter with the requested verses highlighted. Search lists the matching verses in `*KJV search*`, matching whole words and ignoring case (`in Christ` finds 77 verses). `C-u` with a translation other than KJV still goes to BibleGateway. `bible-lookup-parallel` and the lexicon commands are always web-only.

References accepted: `Psalm 23`, `John 3:16`, `John 3:16-18`, `Gen 1:31-2:3`, `Ruth 1-2`, `1Cor 13:4`, `Jude 5`.

Keys in `*KJV*`:

| Key | Action |
|---|---|
| `n` / `p` | next / previous chapter (crosses books) |
| `g` | look up another reference |
| `s` | search |
| `w` | copy verse at point with its reference: `For God so loved… (John 3:16 KJV)` |
| `q` | close the window |

In `*KJV search*`, `RET` opens the result at point in the reader.

### kjv.tsv

UTF-8, one verse per line, four tab-separated fields: book, chapter, verse, text.

```
Genesis	1	1	In the beginning God created the heaven and the earth.
1 John	4	8	He that loveth not knoweth not God; for God is love.
```

66 books, 1,189 chapters, 31,102 verses in canonical order, with no header row. Book names are spelled out in full (`1 John`, `Song of Solomon`, `Psalms`). Generated from [eBible.org's public-domain KJV](https://ebible.org/Scriptures/eng-kjv_vpl.zip) (1769 standard text) by `tools/make-kjv-tsv.py`, which drops the Apocrypha, removes italics brackets (`[was]` → `was`) and pilcrows, and validates the counts. Use it for anything you like. Point `bible-lookup-local-file` at another file in the same format to use a different text.
