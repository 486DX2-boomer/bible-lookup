;;; bible-lookup.el --- Look up Bible passages on BibleGateway  -*- lexical-binding: t; -*-

;; Author: Danny Feller <danny@dfeller.xyz>
;; Version: 0.3.0
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

;;; Code:

(require 'browse-url)
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

(defconst bible-lookup-base-url "https://www.biblegateway.com/passage/"
  "Base URL for BibleGateway passage lookups.")

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
  '("Gen" "Exod" "Ex" "Lev" "Num" "Deut" "Dt"
    "Josh" "Judg" "Jdg" "Ru" "1 Sam" "2 Sam"
    "1 Kgs" "2 Kgs" "1 Chron" "2 Chron" "1 Chr" "2 Chr"
    "Neh" "Esth" "Ps" "Psa" "Psalm" "Prov" "Eccl" "Song"
    "Isa" "Jer" "Lam" "Ezek" "Dan" "Hos" "Obad" "Jon"
    "Mic" "Nah" "Hab" "Zeph" "Hag" "Zech" "Mal"
    "Matt" "Mt" "Mk" "Lk" "Jn" "Rom" "1 Cor" "2 Cor"
    "Gal" "Eph" "Phil" "Col" "1 Thess" "2 Thess"
    "1 Tim" "2 Tim" "Tit" "Phlm" "Philem" "Heb" "Jas"
    "1 Pet" "2 Pet" "1 Jn" "2 Jn" "3 Jn" "Rev")
  "Common book-name abbreviations recognized when matching at point.")

(defconst bible-lookup--reference-re
  (concat "\\b\\(?:"
          (regexp-opt (append bible-lookup--book-names
                              bible-lookup--book-abbreviations))
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

(defun bible-lookup--read-version ()
  "Prompt for a translation code, defaulting to `bible-lookup-version'."
  (completing-read
   (format "Translation (default %s): " bible-lookup-version)
   bible-lookup-version-codes
   nil nil nil 'bible-lookup-version-history bible-lookup-version))

(defun bible-lookup--build-url (reference)
  "Return the BibleGateway URL for REFERENCE.
REFERENCE is a string such as \"Genesis 1:1\" or \"Psalm 23\".
The translation is taken from `bible-lookup-version'."
  (concat bible-lookup-base-url
          "?search=" (url-hexify-string reference)
          "&version=" (url-hexify-string bible-lookup-version)))

(defun bible-lookup--reference-at-point ()
  "Return the Bible reference at point, or nil if there is none."
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
    found))

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

;;;###autoload
(defun bible-lookup (reference &optional version)
  "Look up REFERENCE on BibleGateway in the default browser.
REFERENCE may name a chapter and verse (\"Genesis 1:1\"), a verse
range (\"John 3:16-17\"), or just a chapter (\"Psalm 23\").
Interactively, prompt for the reference in the minibuffer with
completion on book names, defaulting to the reference at point.
Optional argument VERSION overrides `bible-lookup-version' for
this lookup; interactively, a prefix argument (\\[universal-argument]) prompts
for it."
  (interactive
   (let* ((version (and current-prefix-arg (bible-lookup--read-version)))
          (default (bible-lookup--reference-at-point)))
     (list (completing-read
            (format "Bible reference (%s)%s: "
                    (or version bible-lookup-version)
                    (if default (format " (default %s)" default) ""))
            #'bible-lookup--completion-table
            nil nil nil 'bible-lookup-history default)
           version)))
  (when (string-blank-p reference)
    (user-error "No reference given"))
  (let ((bible-lookup-version (or version bible-lookup-version)))
    (browse-url (bible-lookup--build-url (string-trim reference)))))

;;;###autoload
(defun bible-lookup-at-point (&optional version)
  "Look up the Bible reference at point on BibleGateway.
Signal an error if no reference is found under the cursor.
Optional argument VERSION overrides `bible-lookup-version' for
this lookup; interactively, a prefix argument (\\[universal-argument]) prompts
for it."
  (interactive
   (list (and current-prefix-arg (bible-lookup--read-version))))
  (let ((reference (bible-lookup--reference-at-point)))
    (unless reference
      (user-error "No Bible reference at point"))
    (let ((bible-lookup-version (or version bible-lookup-version)))
      (browse-url (bible-lookup--build-url reference)))))

(provide 'bible-lookup)
;;; bible-lookup.el ends here
