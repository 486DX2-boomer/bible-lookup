;;; bible-lookup.el --- Look up Bible passages on BibleGateway  -*- lexical-binding: t; -*-

;; Author: Danny Feller <dfeller@thesoundofit.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "25.1"))
;; Keywords: convenience, hypermedia
;; URL: https://github.com/dfeller/bible-lookup

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Provides the command `bible-lookup', which prompts in the minibuffer
;; for a Bible reference (e.g. "Genesis 1:1" or "Psalm 23") and opens
;; the matching passage on biblegateway.com in your default browser.
;;
;; The translation defaults to KJV and can be changed via
;; `bible-lookup-version':
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

(defconst bible-lookup-base-url "https://www.biblegateway.com/passage/"
  "Base URL for BibleGateway passage lookups.")

(defvar bible-lookup-history nil
  "Minibuffer history for `bible-lookup'.")

(defun bible-lookup--build-url (reference)
  "Return the BibleGateway URL for REFERENCE.
REFERENCE is a string such as \"Genesis 1:1\" or \"Psalm 23\".
The translation is taken from `bible-lookup-version'."
  (concat bible-lookup-base-url
          "?search=" (url-hexify-string reference)
          "&version=" (url-hexify-string bible-lookup-version)))

;;;###autoload
(defun bible-lookup (reference)
  "Look up REFERENCE on BibleGateway in the default browser.
REFERENCE may name a chapter and verse (\"Genesis 1:1\"), a verse
range (\"John 3:16-17\"), or just a chapter (\"Psalm 23\").
Interactively, prompt for the reference in the minibuffer."
  (interactive
   (list (read-string
          (format "Bible reference (%s): " bible-lookup-version)
          nil 'bible-lookup-history)))
  (when (string-blank-p reference)
    (user-error "No reference given"))
  (browse-url (bible-lookup--build-url (string-trim reference))))

(provide 'bible-lookup)
;;; bible-lookup.el ends here
