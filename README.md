# bible-lookup

An Emacs package for looking up Bible passages on [BibleGateway](https://www.biblegateway.com/).

`M-x bible-lookup` prompts in the minibuffer for a reference — chapter and verse (`Genesis 1:1`), a range (`John 3:16-17`), or just a chapter (`Psalm 23`) — and opens the matching passage in your default browser. The prompt completes book names (`gen TAB` → `Genesis`), and when the cursor is already on a reference, that reference is offered as the default.

`M-x bible-lookup-at-point` skips the prompt entirely: it opens the reference under the cursor, recognizing full book names and common abbreviations (`Isa 23:1`, `1 Cor 13`, `Gen. 1:1-5`).

## Installation

Load the file and you're done:

```elisp
(load-file "/path/to/bible-lookup.el")
```

Or with `use-package` from a local checkout:

```elisp
(use-package bible-lookup
  :load-path "/path/to/bible-lookup/"
  :commands (bible-lookup bible-lookup-at-point))
```

## Configuration

The translation defaults to KJV. Change it by setting `bible-lookup-version` to any version code BibleGateway recognizes:

```elisp
(setq bible-lookup-version "ESV")
```

Also available via `M-x customize-group RET bible-lookup`.

## Code walkthrough

A top-to-bottom tour of `bible-lookup.el`.

### The header

```elisp
;;; bible-lookup.el --- Look up Bible passages on BibleGateway  -*- lexical-binding: t; -*-
```

The first line is the standard Elisp package header. The `-*- lexical-binding: t; -*-` cookie tells Emacs to compile this file with lexical scoping (variables resolve like most modern languages) instead of Elisp's legacy dynamic scoping. Every new package should have it.

The comment block below it (`Version`, `Package-Requires`, etc.) is metadata that package managers like `package.el` and MELPA read. `Package-Requires: ((emacs "25.1"))` declares the minimum Emacs version — 25.1 is a safe floor since everything used here is old, stable API. The `;;; Commentary:` section is what users see on the describe-package screen.

### Requires

```elisp
(require 'browse-url)
(require 'url-util)
```

These load the two libraries we depend on: `browse-url` gives us the `browse-url` function (opens URLs in the user's default browser), and `url-util` gives us `url-hexify-string` (URL percent-encoding). Both ship with Emacs, so there are no third-party dependencies.

### Customization

```elisp
(defgroup bible-lookup nil ...)
```

A `defgroup` creates a named bucket in Emacs's Customize UI. It's what makes `M-x customize-group RET bible-lookup` work. The `:prefix` tells the UI it can hide the repetitive `bible-lookup-` prefix when displaying option names.

```elisp
(defcustom bible-lookup-version "KJV" ...)
```

This is the user-facing configuration point. A `defcustom` is like a `defvar` (a global variable with a default), but it additionally registers the variable with Customize, documents its `:type` (a string here) so the UI can offer the right editing widget, and signals to users "this is meant to be changed." Users can set it either through the Customize UI or plainly with `(setq bible-lookup-version "ESV")`.

```elisp
(defconst bible-lookup-base-url "https://www.biblegateway.com/passage/" ...)
```

A `defconst` is a variable that's declared as "not meant to change" — pure documentation of intent, Elisp doesn't actually enforce it. Pulling the URL out of the function body gives it a name and one place to change.

```elisp
(defvar bible-lookup-history nil ...)
```

This holds minibuffer history for our prompt. Emacs's `read-string` can take a history variable, and when given one, `M-p` / `M-n` at the prompt cycle through your previous lookups. We just need to provide an empty variable for it to store them in.

### URL building

```elisp
(defun bible-lookup--build-url (reference)
  (concat bible-lookup-base-url
          "?search=" (url-hexify-string reference)
          "&version=" (url-hexify-string bible-lookup-version)))
```

The double dash in `bible-lookup--build-url` is the Elisp naming convention for "private/internal function" — not part of the public API. Elisp has no real access control, so it's convention only, but tooling and reviewers respect it.

The function itself just string-concatenates the URL. `url-hexify-string` percent-encodes anything unsafe, so `"genesis 1:1"` becomes `genesis%201%3A1` (space → `%20`, colon → `%3A`). Encoding the version too is defensive; version codes are normally plain ASCII, but it costs nothing.

A key design decision lives here: **the reference is not parsed or validated at all.** The string the user types goes straight into `?search=`. That's why chapter-only (`Psalm 23`), chapter-and-verse (`Genesis 1:1`), and even ranges (`John 3:16-17`) all work without any book-name or reference-format logic — BibleGateway's own parser does that work server-side.

### The command

```elisp
;;;###autoload
(defun bible-lookup (reference) ...)
```

The `;;;###autoload` magic comment matters for packaging: when the package is installed via `package.el`, this marks `bible-lookup` to be registered immediately at startup *without* loading the rest of the file. The first time someone runs `M-x bible-lookup`, Emacs loads the file on demand. It keeps startup fast and is expected on every user-facing command.

```elisp
  (interactive
   (list (read-string
          (format "Bible reference (%s): " bible-lookup-version)
          nil 'bible-lookup-history)))
```

The `interactive` form is what turns a plain function into a *command* — something invocable via `M-x` and bindable to keys. Its body runs before the function proper and produces the argument list. Here it prompts with `read-string`, embedding the current version into the prompt (`Bible reference (KJV): `) so you always know which translation you're about to get. The `nil` is "no prefilled default text", and `'bible-lookup-history` wires up that history variable from earlier.

Because the interactive spec is separate from the function body, the function is also callable programmatically — `(bible-lookup "John 1:1")` works from other Elisp, which makes it easy to test and to build on.

```elisp
  (when (string-blank-p reference)
    (user-error "No reference given"))
  (browse-url (bible-lookup--build-url (string-trim reference))))
```

If the user just hits RET on an empty prompt, `user-error` aborts with a message in the echo area. It's deliberately `user-error` rather than `error` — it signals "you did something wrong," not "the code is broken," so it doesn't trigger the debugger even when debugging is enabled. Otherwise stray whitespace is trimmed and the built URL is handed to `browse-url`, which dispatches to the OS default browser (respecting any user customization of `browse-url-browser-function`).

### Reference detection and completion (v0.2.0)

Three pieces power `bible-lookup-at-point` and the smarter prompt:

- `bible-lookup--reference-re` is built at load time with `regexp-opt` over the
  66 book names plus common abbreviations, followed by chapter digits and an
  optional `:verse` / `-range`. Restricting the book part to known names is what
  prevents false positives like `Windows 11:30`.
- `bible-lookup--reference-at-point` scans the current line for matches of that
  regex and returns the one whose bounds contain point. It only ever captures
  text literally present in the buffer — invalid references simply produce a
  "no results" page on BibleGateway, consistent with the package's
  no-validation philosophy.
- `bible-lookup--completion-table` is a programmed completion table: while the
  input still looks like a partial book name it completes against the book
  list; once a chapter number follows the book, the string is accepted as-is so
  `Genesis 1:1` can be finished freehand.

### The footer

```elisp
(provide 'bible-lookup)
;;; bible-lookup.el ends here
```

`provide` registers the feature so `(require 'bible-lookup)` in someone's config succeeds after loading this file. The `ends here` comment line is a package-lint requirement — a formal end-of-file marker that guards against truncated files.

That's the whole thing: two variables of configuration, one pure function that builds a URL, and one command that glues the minibuffer to the browser. The minimalism is the point — by delegating reference parsing to BibleGateway, the package stays at ~80 lines with no data files and no third-party dependencies.
