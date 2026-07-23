# TODO

Feature ideas, roughly ordered by value-to-effort. No ELPA/MELPA submission planned.

## Version picker on prefix argument

`C-u M-x bible-lookup` prompts for the translation for that one lookup
(completing-read over common codes: KJV, ESV, NIV, NASB, NKJV, ...) without
changing `bible-lookup-version`.

## Fetch into a buffer (larger scope — decide deliberately)

Display the passage in an Emacs buffer instead of the browser. Scraping
BibleGateway HTML is brittle; bible-api.com's JSON is the cleaner source for
this mode. Substantially changes the package's "thin wrapper" scope.

## Smaller conveniences

- Parallel passage view: BibleGateway supports `version=KJV;ESV` for
  side-by-side translations; prompt for two versions.
- `bible-lookup-again`: reopen the last reference (or same reference in a
  different version) using the existing history variable.
- Org-mode link type: register a `bible:` link so `[[bible:John 3:16]]` is
  clickable and exports properly.
- Keyword search mode: `bible-search` command using BibleGateway's quicksearch
  for word/phrase queries, not just references.

## Done

- v0.2.0: `bible-lookup-at-point` (regex over the current line, match whose
  bounds contain point, book names + abbreviations via `regexp-opt`), book-name
  completion in the `bible-lookup` prompt, and at-point reference as the
  prompt's default.
