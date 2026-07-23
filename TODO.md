# TODO

Feature ideas, roughly ordered by value-to-effort. No ELPA/MELPA submission planned.

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

- v0.3.0: version picker on prefix argument (`C-u` prompts for the translation
  for one lookup via non-strict completion over `bible-lookup-version-codes`,
  a defcustom; works in both commands).
- v0.2.0: `bible-lookup-at-point` (regex over the current line, match whose
  bounds contain point, book names + abbreviations via `regexp-opt`), book-name
  completion in the `bible-lookup` prompt, and at-point reference as the
  prompt's default.
