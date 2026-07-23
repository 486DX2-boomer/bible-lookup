# TODO

Feature ideas, roughly ordered by value-to-effort. No ELPA/MELPA submission planned.

## Lookup at point (high priority)

`bible-lookup-at-point`: grab a reference under the cursor and open it directly.
Also make the regular `bible-lookup` prompt pre-fill with the reference at point
as its default.

Implementation notes (from design discussion):

- Not lookahead/guessing — match a regex against text already in the buffer.
  Take the current line as the search window, walk matches forward from
  line-beginning, and pick the match whose bounds contain point
  (`(<= (match-beginning 0) point (match-end 0))`).
- Pattern shape: optional leading `1 `/`2 `/`3 `, book name, whitespace, chapter
  digits, optional `:verse` and `-range`.
- Build the book-name part from the 66 book names + standard abbreviations via
  `regexp-opt`, not `[A-Za-z]+` — prevents false positives like `Windows 11:30`
  or `ratio 16:9`.
- No chapter/verse-length validation needed: the match can only capture
  characters literally present in the buffer, and invalid references just get a
  "no results" page from BibleGateway (same delegation philosophy as the prompt).

## Book name completion

`completing-read` over the 66 book names so `gen TAB` → `Genesis`, then append
`1:1` freehand. Shares the book-name data with lookup-at-point.

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
