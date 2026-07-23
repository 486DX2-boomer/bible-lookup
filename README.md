# bible-lookup

Look up Bible passages on [BibleGateway](https://www.biblegateway.com/) from Emacs.

## Usage

- `M-x bible-lookup` — prompt for a reference and open it in your default browser. Accepts chapter and verse (`Genesis 1:1`), a range (`John 3:16-17`), or just a chapter (`Psalm 23`). Book names complete with TAB, and the reference at point (if any) is the default.
- `M-x bible-lookup-at-point` — open the reference under the cursor directly. Recognizes full book names and common abbreviations (`Isa 23:1`, `1 Cor 13`, `Gen. 1:1-5`).
- `M-x bible-lookup-again` — reopen the last reference you looked up. With `C-u`, same passage in a different translation.
- `M-x bible-lookup-parallel` — prompt for a reference and two translations, then open them side by side on BibleGateway.
- `M-x bible-lookup-search` — keyword search across the whole text (`amazing grace`), not a reference lookup. With `C-u`, prompts for the translation.

With a prefix argument (`C-u`), either command first prompts for the translation for that one lookup, without changing `bible-lookup-version`.

## Installation

```elisp
(add-to-list 'load-path "/path/to/bible-lookup/")
(autoload 'bible-lookup "bible-lookup" "Look up a Bible passage on BibleGateway." t)
(autoload 'bible-lookup-at-point "bible-lookup" "Look up the Bible reference at point." t)
```

Or with `use-package`:

```elisp
(use-package bible-lookup
  :load-path "/path/to/bible-lookup/"
  :commands (bible-lookup bible-lookup-at-point bible-lookup-again
             bible-lookup-parallel bible-lookup-search))
```

## Configuration

The translation defaults to KJV. Set `bible-lookup-version` to any version code BibleGateway recognizes:

```elisp
(setq bible-lookup-version "ESV")
```

`bible-lookup-version-codes` holds the translations offered by the `C-u` prompt; completion is not strict, so any code BibleGateway recognizes works.

Both are also available via `M-x customize-group RET bible-lookup`.
