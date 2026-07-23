# TODO

Feature ideas, roughly ordered by value-to-effort. No ELPA/MELPA submission planned.

## Smaller conveniences

- Keyword search mode: `bible-search` command using BibleGateway's quicksearch
  for word/phrase queries, not just references.

## Rejected

- Fetch into a buffer: would mean API calls, then caching, then probably
  bundling the whole Bible as JSON — unwanted complexity. Staying a thin
  browser wrapper.
- Org-mode link type: Danny doesn't use Org.

## Done

- v0.5.0: `bible-lookup-parallel` opens a reference in two translations side by
  side (`&version=A;B`); `bible-lookup--build-url` takes an optional versions
  list.
- v0.4.0: `bible-lookup-again` reopens the last lookup (prefix arg = different
  translation); `bible-lookup-at-point` now records what it opens in
  `bible-lookup-history`.
- v0.3.0: version picker on prefix argument (`C-u` prompts for the translation
  for one lookup via non-strict completion over `bible-lookup-version-codes`,
  a defcustom; works in both commands).
- v0.2.0: `bible-lookup-at-point` (regex over the current line, match whose
  bounds contain point, book names + abbreviations via `regexp-opt`), book-name
  completion in the `bible-lookup` prompt, and at-point reference as the
  prompt's default.
