;;; bible-lookup.el --- Look up Bible passages on BibleGateway  -*- lexical-binding: t; -*-

;; Author: Danny Feller <danny@dfeller.xyz>
;; Version: 0.10.0
;; Package-Requires: ((emacs "25.1"))
;; Keywords: convenience, hypermedia
;; URL: https://github.com/486DX2-boomer/bible-lookup

;; This file is not part of GNU Emacs.

;;; Commentary:

;; `bible-lookup' prompts for a Bible reference (with book-name
;; completion, defaulting to the reference at point) and opens it on
;; biblegateway.com in your default browser.  `bible-lookup-at-point'
;; opens the reference under the cursor directly.
;;
;; The translation defaults to KJV:
;;
;;   (setq bible-lookup-version "ESV")
;;
;; To read and search the bundled KJV text (kjv.tsv) offline, in a
;; read-only buffer in a split window instead of the browser:
;;
;;   (setq bible-lookup-backend 'local)

;;; Code:

(require 'browse-url)
(require 'subr-x)
(require 'thingatpt)
(require 'url-util)

(defgroup bible-lookup nil
  "Look up Bible passages on BibleGateway."
  :group 'convenience
  :prefix "bible-lookup-")

(defcustom bible-lookup-version "KJV"
  "Bible translation to use when looking up passages.
This is the version code BibleGateway expects, e.g. \"KJV\",
\"ESV\", \"NIV\", or \"NASB\"."
  :type 'string
  :group 'bible-lookup)

(defcustom bible-lookup-version-codes
  '("KJV" "NKJV" "ESV" "NIV" "NASB" "NLT" "CSB" "AMP" "MSG" "RSV")
  "Version codes offered when prompting for a translation.
Completion is not strict; any code BibleGateway recognizes may be
entered even if it is not in this list."
  :type '(repeat string)
  :group 'bible-lookup)

(defcustom bible-lookup-backend 'web
  "Where `bible-lookup' and `bible-lookup-search' show results.
`web' opens BibleGateway in the browser.  `local' shows the
bundled KJV text (see `bible-lookup-local-file') in a read-only
buffer.  With `local', a lookup still goes to BibleGateway when a
prefix argument requests a translation other than KJV.
`bible-lookup-parallel' and the lexicon commands always use the
web."
  :type '(choice (const :tag "BibleGateway in the browser" web)
                 (const :tag "Bundled KJV text in Emacs" local))
  :group 'bible-lookup)

(defconst bible-lookup--directory
  (file-name-directory (or load-file-name buffer-file-name default-directory))
  "Directory this library was loaded from.")

(defcustom bible-lookup-local-file
  (expand-file-name "kjv.tsv" bible-lookup--directory)
  "File holding the Bible text used by the `local' backend.
Each line is BOOK, CHAPTER, VERSE and TEXT separated by tabs, with
BOOK spelled as in `bible-lookup--book-names':

  John<TAB>3<TAB>16<TAB>For God so loved the world, ..."
  :type 'file
  :group 'bible-lookup)

(defconst bible-lookup-local-version "KJV"
  "Version code of the text in `bible-lookup-local-file'.")

(defface bible-lookup-chapter-heading
  '((t :inherit bold :height 1.2))
  "Face for chapter headings in the local Bible reader."
  :group 'bible-lookup)

(defface bible-lookup-verse-number
  '((t :inherit shadow))
  "Face for verse numbers in the local Bible reader."
  :group 'bible-lookup)

(defface bible-lookup-highlight
  '((t :inherit highlight))
  "Face for the requested verses in the local Bible reader."
  :group 'bible-lookup)

(defface bible-lookup-reference
  '((t :inherit font-lock-constant-face))
  "Face for references in local search results."
  :group 'bible-lookup)

(defface bible-lookup-match
  '((t :inherit match))
  "Face for matched words in local search results."
  :group 'bible-lookup)

(defconst bible-lookup-base-url "https://www.biblegateway.com/passage/"
  "Base URL for BibleGateway passage lookups.")

(defconst bible-lookup-search-url "https://www.biblegateway.com/quicksearch/"
  "Base URL for BibleGateway keyword searches.")

(defconst bible-lookup-lexicon-url "https://www.blueletterbible.org/search/search.cfm"
  "Base URL for Blue Letter Bible lexical concordance searches.")

(defconst bible-lookup--book-names
  '("Genesis" "Exodus" "Leviticus" "Numbers" "Deuteronomy"
    "Joshua" "Judges" "Ruth" "1 Samuel" "2 Samuel"
    "1 Kings" "2 Kings" "1 Chronicles" "2 Chronicles" "Ezra"
    "Nehemiah" "Esther" "Job" "Psalms" "Proverbs"
    "Ecclesiastes" "Song of Solomon" "Isaiah" "Jeremiah" "Lamentations"
    "Ezekiel" "Daniel" "Hosea" "Joel" "Amos"
    "Obadiah" "Jonah" "Micah" "Nahum" "Habakkuk"
    "Zephaniah" "Haggai" "Zechariah" "Malachi"
    "Matthew" "Mark" "Luke" "John" "Acts"
    "Romans" "1 Corinthians" "2 Corinthians" "Galatians" "Ephesians"
    "Philippians" "Colossians" "1 Thessalonians" "2 Thessalonians"
    "1 Timothy" "2 Timothy" "Titus" "Philemon" "Hebrews"
    "James" "1 Peter" "2 Peter" "1 John" "2 John" "3 John"
    "Jude" "Revelation")
  "The 66 book names, used for completion and at-point matching.")

(defconst bible-lookup--book-abbreviations
  '(("Gen" . "Genesis") ("Exod" . "Exodus") ("Ex" . "Exodus")
    ("Lev" . "Leviticus") ("Num" . "Numbers")
    ("Deut" . "Deuteronomy") ("Dt" . "Deuteronomy")
    ("Josh" . "Joshua") ("Judg" . "Judges") ("Jdg" . "Judges")
    ("Ru" . "Ruth") ("1 Sam" . "1 Samuel") ("2 Sam" . "2 Samuel")
    ("1 Kgs" . "1 Kings") ("2 Kgs" . "2 Kings")
    ("1 Chron" . "1 Chronicles") ("2 Chron" . "2 Chronicles")
    ("1 Chr" . "1 Chronicles") ("2 Chr" . "2 Chronicles")
    ("Neh" . "Nehemiah") ("Esth" . "Esther")
    ("Ps" . "Psalms") ("Psa" . "Psalms") ("Psalm" . "Psalms")
    ("Prov" . "Proverbs") ("Eccl" . "Ecclesiastes")
    ("Song" . "Song of Solomon") ("Song of Songs" . "Song of Solomon")
    ("Isa" . "Isaiah") ("Jer" . "Jeremiah") ("Lam" . "Lamentations")
    ("Ezek" . "Ezekiel") ("Dan" . "Daniel") ("Hos" . "Hosea")
    ("Obad" . "Obadiah") ("Jon" . "Jonah") ("Mic" . "Micah")
    ("Nah" . "Nahum") ("Hab" . "Habakkuk") ("Zeph" . "Zephaniah")
    ("Hag" . "Haggai") ("Zech" . "Zechariah") ("Mal" . "Malachi")
    ("Matt" . "Matthew") ("Mt" . "Matthew") ("Mk" . "Mark")
    ("Lk" . "Luke") ("Jn" . "John") ("Rom" . "Romans")
    ("1 Cor" . "1 Corinthians") ("2 Cor" . "2 Corinthians")
    ("Gal" . "Galatians") ("Eph" . "Ephesians")
    ("Phil" . "Philippians") ("Col" . "Colossians")
    ("1 Thess" . "1 Thessalonians") ("2 Thess" . "2 Thessalonians")
    ("1 Tim" . "1 Timothy") ("2 Tim" . "2 Timothy") ("Tit" . "Titus")
    ("Phlm" . "Philemon") ("Philem" . "Philemon") ("Heb" . "Hebrews")
    ("Jas" . "James") ("1 Pet" . "1 Peter") ("2 Pet" . "2 Peter")
    ("1 Jn" . "1 John") ("2 Jn" . "2 John") ("3 Jn" . "3 John")
    ("Rev" . "Revelation"))
  "Common book-name abbreviations and the books they stand for.")

(defconst bible-lookup--single-chapter-books
  '("Obadiah" "Philemon" "2 John" "3 John" "Jude")
  "Books with one chapter, where \"Jude 5\" means verse 5.")

(defconst bible-lookup--reference-re
  (concat "\\b\\(?:"
          (regexp-opt (append bible-lookup--book-names
                              (mapcar #'car bible-lookup--book-abbreviations)))
          "\\)\\.?\\s-+[0-9]+"
          "\\(?::[0-9]+\\)?"
          "\\(?:[-–][0-9]+\\(?::[0-9]+\\)?\\)?")
  "Regexp matching a Bible reference such as \"Isaiah 23:1\".
Matches a known book name or abbreviation, a chapter number, and
an optional \":verse\" and \"-range\".")

(defvar bible-lookup-history nil
  "Minibuffer history for `bible-lookup'.")

(defvar bible-lookup-version-history nil
  "Minibuffer history for translation prompts.")

(defvar bible-lookup-search-history nil
  "Minibuffer history for `bible-lookup-search'.")

(defvar bible-lookup-lexicon-history nil
  "Minibuffer history for `bible-lookup-lexicon'.")

(defun bible-lookup--read-version (&optional prompt default)
  "Prompt for a translation code with completion.
PROMPT defaults to a generic prompt; DEFAULT, which may be nil,
is offered as the default input."
  (completing-read
   (or prompt (format "Translation (default %s): " bible-lookup-version))
   bible-lookup-version-codes
   nil nil nil 'bible-lookup-version-history default))

(defun bible-lookup--use-local-p (version)
  "Return non-nil if a lookup should use the local text.
VERSION is the translation explicitly requested for this lookup,
or nil if none was."
  (and (eq bible-lookup-backend 'local)
       (or (null version)
           (string= (upcase version) bible-lookup-local-version))))

(defun bible-lookup--version-label (version)
  "Return the translation code to label a lookup in VERSION with."
  (if (bible-lookup--use-local-p version)
      bible-lookup-local-version
    (or version bible-lookup-version)))

(defun bible-lookup--build-url (reference &optional versions)
  "Return the BibleGateway URL for REFERENCE.
REFERENCE is a string such as \"Genesis 1:1\" or \"Psalm 23\".
Optional VERSIONS is a list of translation codes shown side by
side; it defaults to `bible-lookup-version' alone."
  (concat bible-lookup-base-url
          "?search=" (url-hexify-string reference)
          "&version="
          (mapconcat #'url-hexify-string
                     (or versions (list bible-lookup-version))
                     ";")))

(defun bible-lookup--reference-at-point ()
  "Return the Bible reference at point, or nil if there is none.
In the local reader and search results this is the verse at point."
  (or (get-text-property (point) 'bible-lookup-reference)
      (let ((case-fold-search t)
            (pt (point))
            (found nil))
        (save-excursion
          (beginning-of-line)
          (while (and (not found)
                      (re-search-forward bible-lookup--reference-re
                                         (line-end-position) t))
            (when (and (<= (match-beginning 0) pt)
                       (<= pt (match-end 0)))
              (setq found (match-string-no-properties 0)))))
        found)))

(defun bible-lookup--region-string ()
  "Return the active region as a trimmed string, or nil if there is none."
  (when (use-region-p)
    (let ((text (string-trim
                 (buffer-substring-no-properties
                  (region-beginning) (region-end)))))
      (unless (string-blank-p text)
        text))))

(defun bible-lookup--completion-table (string pred action)
  "Completion table for Bible references.
Completes STRING against book names until a chapter number
follows, then accepts STRING as-is.  PRED and ACTION are as for
programmed completion."
  (cond
   ((eq action 'metadata)
    '(metadata (category . bible-reference)
               (display-sort-function . identity)
               (cycle-sort-function . identity)))
   ((string-match-p "[A-Za-z]\\.?\\s-+[0-9]" string)
    (complete-with-action action (list string) string pred))
   (t
    (complete-with-action action bible-lookup--book-names string pred))))

;;;; Local backend: reference parsing

(defun bible-lookup--canonical-book (name)
  "Return the full book name for NAME, a name or abbreviation, or nil.
Matching ignores case, a trailing period, and the space after a
leading number (\"1Cor\")."
  (let* ((name (replace-regexp-in-string "\\s-+" " " (string-trim name)))
         (name (replace-regexp-in-string "\\.\\'" "" name))
         (name (replace-regexp-in-string "\\`\\([1-3]\\) ?" "\\1 " name)))
    (or (car (member-ignore-case name bible-lookup--book-names))
        (cdr (assoc-string name bible-lookup--book-abbreviations t)))))

(defun bible-lookup--parse-reference (reference)
  "Parse REFERENCE into a list (BOOK CH1 V1 CH2 V2), or return nil.
BOOK is the full book name.  The passage runs from chapter CH1,
verse V1 to chapter CH2, verse V2.  V1 and V2 are nil when whole
chapters were requested.  Accepts \"Psalm 23\", \"John 3:16\",
\"John 3:16-18\", \"Gen 1:31-2:3\" and \"Ruth 1-2\"; in single-chapter
books, \"Jude 5\" means verse 5."
  (let ((case-fold-search t)
        (reference (string-trim reference)))
    (when (string-match
           (concat "\\`\\(.*[[:alpha:].]\\)\\s-*\\([0-9]+\\)"
                   "\\(?::\\([0-9]+\\)\\)?"
                   "\\(?:\\s-*[-–]\\s-*\\([0-9]+\\)\\(?::\\([0-9]+\\)\\)?\\)?\\'")
           reference)
      (let* ((num (lambda (n) (and (match-beginning n)
                                   (string-to-number (match-string n reference)))))
             (ch1 (funcall num 2))
             (v1 (funcall num 3))
             (end (funcall num 4))
             (v2 (funcall num 5))
             ;; Last, since it clobbers the match data.
             (book (bible-lookup--canonical-book (match-string 1 reference))))
        (when book
          (cond
           ;; "Jude 5", "Jude 3-5": the numbers are verses.
           ((and (null v1) (null v2)
                 (member book bible-lookup--single-chapter-books))
            (list book 1 ch1 1 (or end ch1)))
           ;; "John 3:16-4:2"
           (v2 (list book ch1 (or v1 1) end v2))
           ;; "John 3:16-18"
           ((and v1 end) (list book ch1 v1 ch1 end))
           ;; "John 3:16"
           (v1 (list book ch1 v1 ch1 v1))
           ;; "Psalm 23", "Ruth 1-2"
           (t (list book ch1 nil (or end ch1) nil))))))))

(defun bible-lookup--format-reference (ref)
  "Return parsed reference REF as a string such as \"John 3:16-18\"."
  (pcase-let ((`(,book ,ch1 ,v1 ,ch2 ,v2) ref))
    (concat book " " (number-to-string ch1)
            (cond ((null v1) (if (= ch1 ch2) "" (format "-%d" ch2)))
                  ((/= ch1 ch2) (format ":%d-%d:%d" v1 ch2 v2))
                  ((= v1 v2) (format ":%d" v1))
                  (t (format ":%d-%d" v1 v2))))))

;;;; Local backend: text

(defvar bible-lookup--local-table nil
  "Hash table mapping book names to vectors of chapters.
Each chapter is a vector of verse strings.  Loaded on first use.")

(defvar bible-lookup--local-table-file nil
  "File `bible-lookup--local-table' was loaded from.")

(defun bible-lookup--read-local-file (file)
  "Read FILE in the format of `bible-lookup-local-file' into a table.
See `bible-lookup--local-table' for the table's layout."
  (unless (file-readable-p file)
    (user-error "Local Bible text not found: %s" file))
  (let ((books (make-hash-table :test #'equal)))
    ;; First collect (CHAPTER VERSE TEXT) rows per book, newest first.
    (with-temp-buffer
      (let ((coding-system-for-read 'utf-8))
        (insert-file-contents file))
      (goto-char (point-min))
      (while (not (eobp))
        (let ((fields (split-string (buffer-substring-no-properties
                                     (point) (line-end-position))
                                    "\t")))
          (when (= (length fields) 4)
            (push (list (string-to-number (nth 1 fields))
                        (string-to-number (nth 2 fields))
                        (nth 3 fields))
                  (gethash (nth 0 fields) books))))
        (forward-line 1)))
    ;; Then turn each book's rows into a vector of verse vectors.
    (maphash
     (lambda (book rows)
       (let ((chapters (make-vector (apply #'max (mapcar #'car rows)) nil)))
         (dolist (row rows)
           (push row (aref chapters (1- (car row)))))
         (dotimes (i (length chapters))
           (let* ((verses (aref chapters i))
                  (vec (make-vector (apply #'max 0 (mapcar #'cadr verses)) "")))
             (dolist (row verses)
               (aset vec (1- (nth 1 row)) (nth 2 row)))
             (aset chapters i vec)))
         (puthash book chapters books)))
     books)
    books))

(defun bible-lookup--local-text ()
  "Return the local Bible text, loading it if needed."
  (unless (and bible-lookup--local-table
               (equal bible-lookup--local-table-file bible-lookup-local-file))
    (setq bible-lookup--local-table
          (bible-lookup--read-local-file bible-lookup-local-file)
          bible-lookup--local-table-file bible-lookup-local-file))
  bible-lookup--local-table)

(defun bible-lookup--chapters (book)
  "Return the vector of chapters of BOOK in the local text."
  (or (gethash book (bible-lookup--local-text))
      (user-error "%s is not in %s" book bible-lookup-local-file)))

(defun bible-lookup--resolve (ref)
  "Check parsed reference REF against the local text.
Return REF with an over-long range end clamped to the end of the
chapter or book; signal an error if it starts past the end."
  (pcase-let* ((`(,book ,ch1 ,v1 ,ch2 ,v2) ref)
               (chapters (bible-lookup--chapters book))
               (count (length chapters)))
    (when (or (< ch1 1) (> ch1 count))
      (user-error "%s has %d chapter%s" book count (if (= count 1) "" "s")))
    (when (and v1 (or (< v1 1) (> v1 (length (aref chapters (1- ch1))))))
      (user-error "%s %d has %d verses"
                  book ch1 (length (aref chapters (1- ch1)))))
    (when (> ch2 count)
      (setq ch2 count
            v2 (and v2 (length (aref chapters (1- count))))))
    (when v2
      (setq v2 (min v2 (length (aref chapters (1- ch2))))))
    (when (or (< ch2 ch1) (and v1 (= ch1 ch2) (< v2 v1)))
      (user-error "Range ends before it starts"))
    (list book ch1 v1 ch2 v2)))

;;;; Local backend: reader buffer

(defconst bible-lookup--display-action
  '((display-buffer-reuse-window
     display-buffer-pop-up-window
     display-buffer-use-some-window))
  "How the reader and search buffers are shown: in a split window.")

(defvar-local bible-lookup--displayed nil
  "Parsed reference shown in this reader buffer.")

(defvar bible-lookup-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "n" #'bible-lookup-next-chapter)
    (define-key map "p" #'bible-lookup-previous-chapter)
    (define-key map "g" #'bible-lookup)
    (define-key map "s" #'bible-lookup-search)
    (define-key map "w" #'bible-lookup-copy-verse)
    map)
  "Keymap for `bible-lookup-mode'.")

(define-derived-mode bible-lookup-mode special-mode "Bible"
  "Major mode for reading the local Bible text.
\\{bible-lookup-mode-map}"
  (setq truncate-lines nil)
  (visual-line-mode 1))

(defun bible-lookup--insert-verse (book chapter verse text)
  "Insert TEXT of BOOK CHAPTER:VERSE as one line, and return its start.
The line's prefix is the verse number."
  (let ((beg (point)))
    (insert (propertize (format "%3d " verse) 'face 'bible-lookup-verse-number)
            text "\n")
    (add-text-properties
     beg (point)
     (list 'bible-lookup-reference (format "%s %d:%d" book chapter verse)
           'bible-lookup-text text
           'wrap-prefix "    "))
    beg))

(defun bible-lookup--insert-passage (ref)
  "Insert the whole chapters covered by parsed reference REF.
Highlight the verses REF names, and return the position of the
first of them, or nil if REF names whole chapters."
  (pcase-let ((`(,book ,ch1 ,v1 ,ch2 ,v2) ref)
              (first nil))
    (dolist (ch (number-sequence ch1 ch2))
      (let ((verses (aref (bible-lookup--chapters book) (1- ch))))
        (insert (propertize (format "%s %d" book ch)
                            'face 'bible-lookup-chapter-heading)
                "\n\n")
        (dotimes (i (length verses))
          (let* ((v (1+ i))
                 (beg (bible-lookup--insert-verse book ch v (aref verses i))))
            (when (and v1
                       (or (> ch ch1) (>= v v1))
                       (or (< ch ch2) (<= v v2)))
              (add-face-text-property beg (1- (point)) 'bible-lookup-highlight t)
              (unless first
                (setq first beg)))))
        (insert "\n")))
    first))

(defun bible-lookup--local-display (ref &optional action)
  "Show parsed reference REF in the reader buffer and select it.
ACTION is a `display-buffer' action, defaulting to
`bible-lookup--display-action'."
  (let* ((ref (bible-lookup--resolve ref))
         (buffer (get-buffer-create (format "*%s*" bible-lookup-local-version)))
         first)
    (with-current-buffer buffer
      (unless (derived-mode-p 'bible-lookup-mode)
        (bible-lookup-mode))
      (let ((inhibit-read-only t))
        (erase-buffer)
        (setq first (bible-lookup--insert-passage ref)))
      (setq bible-lookup--displayed ref
            header-line-format (format " %s (%s)"
                                       (bible-lookup--format-reference ref)
                                       bible-lookup-local-version)))
    (pop-to-buffer buffer (or action bible-lookup--display-action))
    (goto-char (or first (point-min)))
    ;; Show a couple of lines of context above the requested verse.
    (set-window-start nil (save-excursion (forward-line -2) (point)))))

(defun bible-lookup--local-show (reference &optional action)
  "Show REFERENCE, a string such as \"John 3:16\", in the reader buffer.
ACTION is as for `bible-lookup--local-display'."
  (bible-lookup--local-display
   (or (bible-lookup--parse-reference reference)
       (user-error "Cannot parse reference: %s" reference))
   action))

(defun bible-lookup--show (reference version)
  "Show REFERENCE in VERSION, a translation code or nil for the default.
Use the local reader or BibleGateway per `bible-lookup-backend'."
  (if (bible-lookup--use-local-p version)
      (bible-lookup--local-show reference)
    (let ((bible-lookup-version (or version bible-lookup-version)))
      (browse-url (bible-lookup--build-url reference)))))

(defun bible-lookup--step-chapter (delta)
  "Show the chapter DELTA chapters after the one displayed.
DELTA is 1 or -1.  Crosses into the next or previous book."
  (unless bible-lookup--displayed
    (user-error "No passage displayed"))
  (pcase-let* ((`(,book ,ch1 ,_ ,ch2 ,_) bible-lookup--displayed)
               (ch (+ (if (> delta 0) ch2 ch1) delta))
               (index (- (length bible-lookup--book-names)
                         (length (member book bible-lookup--book-names)))))
    (cond
     ((< ch 1)
      (when (= index 0)
        (user-error "Beginning of the Bible"))
      (setq book (nth (1- index) bible-lookup--book-names)
            ch (length (bible-lookup--chapters book))))
     ((> ch (length (bible-lookup--chapters book)))
      (setq book (nth (1+ index) bible-lookup--book-names)
            ch 1)
      (unless book
        (user-error "End of the Bible"))))
    (bible-lookup--local-display (list book ch nil ch nil)
                                 '(display-buffer-same-window))))

(defun bible-lookup-next-chapter ()
  "Show the next chapter in the local Bible reader."
  (interactive)
  (bible-lookup--step-chapter 1))

(defun bible-lookup-previous-chapter ()
  "Show the previous chapter in the local Bible reader."
  (interactive)
  (bible-lookup--step-chapter -1))

(defun bible-lookup-copy-verse ()
  "Copy the verse at point to the kill ring, followed by its reference."
  (interactive)
  (let ((reference (get-text-property (point) 'bible-lookup-reference))
        (text (get-text-property (point) 'bible-lookup-text)))
    (unless reference
      (user-error "No verse at point"))
    (kill-new (format "%s (%s %s)" text reference bible-lookup-local-version))
    (message "Copied %s" reference)))

;;;; Local backend: search

(defvar bible-lookup-search-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'bible-lookup-search-goto)
    (define-key map "n" #'next-line)
    (define-key map "p" #'previous-line)
    (define-key map "s" #'bible-lookup-search)
    (define-key map "w" #'bible-lookup-copy-verse)
    map)
  "Keymap for `bible-lookup-search-mode'.")

(define-derived-mode bible-lookup-search-mode special-mode "Bible-Search"
  "Major mode for local Bible search results.
\\{bible-lookup-search-mode-map}"
  (setq truncate-lines nil)
  (visual-line-mode 1))

(defun bible-lookup--search-regexp (query)
  "Return a regexp matching QUERY as whole words.
A straight or curly apostrophe in QUERY matches either."
  (concat (if (string-match-p "\\`\\w" query) "\\b" "")
          (replace-regexp-in-string "['’]" "['’]" (regexp-quote query) t t)
          (if (string-match-p "\\w\\'" query) "\\b" "")))

(defun bible-lookup--local-search (query)
  "Show verses of the local text containing QUERY, ignoring case."
  (let ((regexp (bible-lookup--search-regexp query))
        (case-fold-search t)
        (hits nil))
    (dolist (book bible-lookup--book-names)
      (let ((chapters (bible-lookup--chapters book)))
        (dotimes (c (length chapters))
          (let ((verses (aref chapters c)))
            (dotimes (v (length verses))
              (when (string-match regexp (aref verses v))
                (push (list book (1+ c) (1+ v) (aref verses v)) hits)))))))
    (setq hits (nreverse hits))
    (if (null hits)
        (message "No verses contain \"%s\"" query)
      (let ((buffer (get-buffer-create
                     (format "*%s search*" bible-lookup-local-version))))
        (with-current-buffer buffer
          (bible-lookup-search-mode)
          (let ((inhibit-read-only t))
            (erase-buffer)
            (dolist (hit hits)
              (pcase-let* ((`(,book ,ch ,v ,text) hit)
                           (reference (format "%s %d:%d" book ch v))
                           (shown (copy-sequence text))
                           (start 0)
                           (beg (point)))
                (while (string-match regexp shown start)
                  (add-face-text-property (match-beginning 0) (match-end 0)
                                          'bible-lookup-match t shown)
                  (setq start (match-end 0)))
                (insert (propertize reference 'face 'bible-lookup-reference)
                        "  " shown "\n")
                (add-text-properties beg (point)
                                     (list 'bible-lookup-reference reference
                                           'bible-lookup-text text
                                           'wrap-prefix "    ")))))
          (goto-char (point-min))
          (setq header-line-format
                (format " %d verse%s containing \"%s\" (%s)"
                        (length hits) (if (= (length hits) 1) "" "s")
                        query bible-lookup-local-version)))
        (pop-to-buffer buffer bible-lookup--display-action)))))

(defun bible-lookup-search-goto ()
  "Show the verse of the search result at point in the reader."
  (interactive)
  (let ((reference (get-text-property (point) 'bible-lookup-reference)))
    (unless reference
      (user-error "No search result at point"))
    (bible-lookup--local-show
     reference
     '((display-buffer-reuse-window display-buffer-use-some-window)
       (inhibit-same-window . t)))))

;;;; Commands

;;;###autoload
(defun bible-lookup (reference &optional version)
  "Look up REFERENCE on BibleGateway in the default browser.
REFERENCE may name a chapter and verse (\"Genesis 1:1\"), a verse
range (\"John 3:16-17\"), or just a chapter (\"Psalm 23\").
Interactively, prompt for the reference in the minibuffer with
completion on book names, defaulting to the reference at point.
Optional argument VERSION overrides `bible-lookup-version' for
this lookup; interactively, a prefix argument (\\[universal-argument]) prompts
for it.  With `bible-lookup-backend' set to `local', show the
passage in the local KJV reader instead."
  (interactive
   (let* ((version (and current-prefix-arg
                        (bible-lookup--read-version nil bible-lookup-version)))
          (default (bible-lookup--reference-at-point)))
     (list (completing-read
            (format "Bible reference (%s)%s: "
                    (bible-lookup--version-label version)
                    (if default (format " (default %s)" default) ""))
            #'bible-lookup--completion-table
            nil nil nil 'bible-lookup-history default)
           version)))
  (when (string-blank-p reference)
    (user-error "No reference given"))
  (bible-lookup--show (string-trim reference) version))

;;;###autoload
(defun bible-lookup-at-point (&optional version)
  "Look up the Bible reference at point on BibleGateway.
Signal an error if no reference is found under the cursor.
Optional argument VERSION overrides `bible-lookup-version' for
this lookup; interactively, a prefix argument (\\[universal-argument]) prompts
for it.  Honors `bible-lookup-backend' like `bible-lookup'."
  (interactive
   (list (and current-prefix-arg
              (bible-lookup--read-version nil bible-lookup-version))))
  (let ((reference (bible-lookup--reference-at-point)))
    (unless reference
      (user-error "No Bible reference at point"))
    (add-to-history 'bible-lookup-history reference)
    (bible-lookup--show reference version)))

;;;###autoload
(defun bible-lookup-again (&optional version)
  "Reopen the most recently looked-up Bible reference.
Optional argument VERSION overrides `bible-lookup-version' for
this lookup; interactively, a prefix argument (\\[universal-argument]) prompts
for it, making it easy to reread the same passage in another
translation.  Honors `bible-lookup-backend' like `bible-lookup'."
  (interactive
   (list (and current-prefix-arg
              (bible-lookup--read-version nil bible-lookup-version))))
  (unless bible-lookup-history
    (user-error "No previous lookup"))
  (bible-lookup--show (car bible-lookup-history) version))

;;;###autoload
(defun bible-lookup-parallel (reference version-a version-b)
  "Look up REFERENCE in two translations side by side on BibleGateway.
VERSION-A and VERSION-B are the translation codes to compare,
e.g. \"KJV\" and \"ESV\".  Interactively, prompt for the
reference (defaulting to the reference at point) and both
translations."
  (interactive
   (let ((default (bible-lookup--reference-at-point)))
     (list (completing-read
            (format "Bible reference%s: "
                    (if default (format " (default %s)" default) ""))
            #'bible-lookup--completion-table
            nil nil nil 'bible-lookup-history default)
           (bible-lookup--read-version
            (format "First translation (default %s): " bible-lookup-version)
            bible-lookup-version)
           (bible-lookup--read-version "Second translation: "))))
  (when (string-blank-p reference)
    (user-error "No reference given"))
  (when (or (string-blank-p version-a) (string-blank-p version-b))
    (user-error "Two translations are required"))
  (browse-url (bible-lookup--build-url (string-trim reference)
                                       (list version-a version-b))))

;;;###autoload
(defun bible-lookup-search (query &optional version)
  "Search BibleGateway for QUERY, a word or phrase (\"in Christ\").
Unlike `bible-lookup', this is a keyword search across the whole
text, not a reference lookup.  Optional argument VERSION overrides
`bible-lookup-version' for this search; interactively, a prefix
argument (\\[universal-argument]) prompts for it.  With
`bible-lookup-backend' set to `local', list the matching verses
of the local KJV instead; QUERY then matches as an exact phrase
of whole words, ignoring case."
  (interactive
   (let* ((version (and current-prefix-arg
                        (bible-lookup--read-version nil bible-lookup-version)))
          (default (bible-lookup--region-string)))
     (list (read-string
            (format "Bible search (%s)%s: "
                    (bible-lookup--version-label version)
                    (if default (format " (default %s)" default) ""))
            nil 'bible-lookup-search-history default)
           version)))
  (when (string-blank-p query)
    (user-error "No search query given"))
  (if (bible-lookup--use-local-p version)
      (bible-lookup--local-search (string-trim query))
    (browse-url
     (concat bible-lookup-search-url
             "?quicksearch=" (url-hexify-string (string-trim query))
             "&version=" (url-hexify-string (or version bible-lookup-version))))))

;;;###autoload
(defun bible-lookup-search-at-point (&optional version)
  "Search BibleGateway for the word at point.
Signal an error if there is no word under the cursor.  Optional
argument VERSION overrides `bible-lookup-version' for this
search; interactively, a prefix argument (\\[universal-argument]) prompts for
it."
  (interactive
   (list (and current-prefix-arg
              (bible-lookup--read-version nil bible-lookup-version))))
  (let ((word (thing-at-point 'word t)))
    (unless word
      (user-error "No word at point"))
    (add-to-history 'bible-lookup-search-history word)
    (bible-lookup-search word version)))

(defun bible-lookup--build-lexicon-url (term &optional version)
  "Return the Blue Letter Bible lexicon search URL for TERM.
Optional VERSION overrides `bible-lookup-version'."
  (concat bible-lookup-lexicon-url
          "?Criteria=" (url-hexify-string term)
          "&t=" (url-hexify-string (or version bible-lookup-version))
          "&lexcSt=2"
          "#s=s_lexiconc"))

;;;###autoload
(defun bible-lookup-lexicon (term &optional version)
  "Search the Blue Letter Bible lexical concordance for TERM.
TERM is an English word or phrase (\"buckler\"); the results link
each occurrence to its underlying Hebrew or Greek word.  Optional
argument VERSION overrides `bible-lookup-version' for this search;
interactively, a prefix argument (\\[universal-argument]) prompts for it."
  (interactive
   (let ((version (and current-prefix-arg
                       (bible-lookup--read-version nil bible-lookup-version))))
     (list (read-string
            (format "Lexicon search (%s): " (or version bible-lookup-version))
            nil 'bible-lookup-lexicon-history)
           version)))
  (when (string-blank-p term)
    (user-error "No search term given"))
  (browse-url (bible-lookup--build-lexicon-url (string-trim term) version)))

;;;###autoload
(defun bible-lookup-lexicon-at-point (&optional version)
  "Search the Blue Letter Bible lexical concordance for the word at point.
Signal an error if there is no word under the cursor.  Optional
argument VERSION overrides `bible-lookup-version' for this search;
interactively, a prefix argument (\\[universal-argument]) prompts for it."
  (interactive
   (list (and current-prefix-arg
              (bible-lookup--read-version nil bible-lookup-version))))
  (let ((word (thing-at-point 'word t)))
    (unless word
      (user-error "No word at point"))
    (add-to-history 'bible-lookup-lexicon-history word)
    (bible-lookup-lexicon word version)))

(provide 'bible-lookup)
;;; bible-lookup.el ends here
