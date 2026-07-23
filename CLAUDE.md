# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`bible-lookup` is a single-file Emacs Lisp package (`bible-lookup.el`). It provides one interactive command, `bible-lookup`, which prompts in the minibuffer for a Bible reference (chapter-and-verse like "Genesis 1:1", a range, or just a chapter like "Psalm 23") and opens the matching passage on biblegateway.com via `browse-url`.

## Architecture

- `bible-lookup--build-url` constructs the BibleGateway URL: `https://www.biblegateway.com/passage/?search=<url-encoded reference>&version=<version>`. The reference is passed through verbatim (URL-encoded) — BibleGateway does the parsing, so the package deliberately does no reference validation beyond rejecting blank input.
- `bible-lookup-version` (defcustom, default `"KJV"`) selects the translation; it must be a version code BibleGateway recognizes (e.g. `ESV`, `NIV`).
- The package targets Emacs 25.1+ and must keep `lexical-binding: t`.

## Development

Emacs is installed on this machine but **not on PATH**; invoke it with its full path (e.g. `& "C:\Program Files\Emacs\...\bin\emacs.exe"`) or test interactively inside a running Emacs.

Byte-compile / lint check (adjust the emacs path):

```
emacs -Q --batch -f batch-byte-compile bible-lookup.el
```

Quick smoke test of URL building without a browser:

```
emacs -Q --batch -l bible-lookup.el --eval "(princ (bible-lookup--build-url \"Genesis 1:1\"))"
```

Interactive test: `M-x load-file RET bible-lookup.el RET`, then `M-x bible-lookup`.

There is no test suite, package manifest, or build tooling beyond the single `.el` file. Follow standard Emacs Lisp packaging conventions: `;;;###autoload` on user-facing commands, `bible-lookup-` prefix on all symbols (double-dash for internals), checkdoc-clean docstrings.
