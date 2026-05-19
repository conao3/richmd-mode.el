;;; richmd-mode.el --- Rich rendering markdown buffer  -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Naoya Yamashita

;; Author: Naoya Yamashita <conao3@gmail.com>
;; Version: 0.0.1
;; Keywords: convenience
;; Package-Requires: ((emacs "30.2"))
;; URL: https://github.com/conao3/richmd-mode.el

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Rich rendering markdown buffer using overlays, styled after GitHub.

;;; Code:

(require 'cl-lib)
(require 'face-remap)

(defgroup richmd-mode nil
  "Rich rendering markdown buffer."
  :group 'convenience
  :link '(url-link :tag "Github" "https://github.com/conao3/richmd-mode.el"))

(defface richmd-mode-body-face
  '((t :inherit variable-pitch))
  "Face applied to the buffer for proportional body rendering."
  :group 'richmd-mode)

(defface richmd-mode-heading-1-face
  '((t :inherit (variable-pitch outline-1) :height 2.0 :weight bold))
  "Face for level-1 headings."
  :group 'richmd-mode)

(defface richmd-mode-heading-2-face
  '((t :inherit (variable-pitch outline-2) :height 1.5 :weight bold))
  "Face for level-2 headings."
  :group 'richmd-mode)

(defface richmd-mode-heading-rule-face
  '((((background light)) :overline "#afb8c1")
    (((background dark))  :overline "#6e7781"))
  "Face drawing the bottom rule under level-1 and level-2 headings.
GitHub separates the heading from its rule with padding; the rule
is rendered on the blank line that follows the heading (one
buffer line, so it stays aligned under
`display-line-numbers-mode') rather than as a glyph underline,
which would collide with the descenders of the large heading
font."
  :group 'richmd-mode)

(defface richmd-mode-heading-3-face
  '((t :inherit (variable-pitch outline-3) :height 1.25 :weight bold))
  "Face for level-3 headings."
  :group 'richmd-mode)

(defface richmd-mode-heading-4-face
  '((t :inherit (variable-pitch outline-4) :weight bold))
  "Face for level-4 headings."
  :group 'richmd-mode)

(defface richmd-mode-heading-5-face
  '((t :inherit (variable-pitch outline-5) :weight bold :height 0.875))
  "Face for level-5 headings."
  :group 'richmd-mode)

(defface richmd-mode-heading-6-face
  '((((background light)) :inherit (variable-pitch outline-6)
     :weight bold :height 0.85 :foreground "#656d76")
    (((background dark))  :inherit (variable-pitch outline-6)
     :weight bold :height 0.85 :foreground "#8b949e"))
  "Face for level-6 headings."
  :group 'richmd-mode)

(defface richmd-mode-bold-face
  '((t :inherit bold))
  "Face for bold text."
  :group 'richmd-mode)

(defface richmd-mode-italic-face
  '((t :inherit variable-pitch :slant italic))
  "Face for italic text.
Inherits `variable-pitch' so it matches the proportional body
font; `richmd-mode--sync-italic-family' substitutes an
italic-capable family when that font has no italic variant."
  :group 'richmd-mode)

(defface richmd-mode-strikethrough-face
  '((t :strike-through t))
  "Face for strikethrough text."
  :group 'richmd-mode)

(defface richmd-mode-code-face
  '((((background light)) :inherit fixed-pitch
     :background "#eaeef2" :foreground "#1f2328" :height 0.85
     :box (:line-width (-1 . -2) :color "#eaeef2" :style nil))
    (((background dark))  :inherit fixed-pitch
     :background "#343942" :foreground "#e6edf3" :height 0.85
     :box (:line-width (-1 . -2) :color "#343942" :style nil)))
  "Face for inline code.

GitHub renders inline code at roughly 85% of the surrounding font
size, which also shrinks the glyph cell vertically and therefore
prevents the grey background from visually merging with the
line-spacing area of adjacent lines."
  :group 'richmd-mode)

(defface richmd-mode-code-block-face
  '((((background light)) :inherit fixed-pitch :background "#f6f8fa" :extend t)
    (((background dark))  :inherit fixed-pitch :background "#161b22" :extend t))
  "Face for fenced code blocks."
  :group 'richmd-mode)

(defface richmd-mode-code-block-lang-face
  '((((background light)) :inherit fixed-pitch :foreground "#59636e"
     :background "#eaeef2" :extend t :height 0.9)
    (((background dark))  :inherit fixed-pitch :foreground "#8b949e"
     :background "#21262d" :extend t :height 0.9))
  "Face for the language tag line of a fenced code block."
  :group 'richmd-mode)

(defface richmd-mode-link-face
  '((((background light)) :inherit variable-pitch :foreground "#0969da")
    (((background dark))  :inherit variable-pitch :foreground "#2f81f7"))
  "Face for links."
  :group 'richmd-mode)

(defface richmd-mode-quote-face
  '((((background light)) :inherit variable-pitch :foreground "#59636e" :slant italic)
    (((background dark))  :inherit variable-pitch :foreground "#8b949e" :slant italic))
  "Face for blockquote text."
  :group 'richmd-mode)

(defface richmd-mode-quote-bar-face
  '((((background light)) :background "#d0d7de" :foreground "#d0d7de")
    (((background dark))  :background "#3d444d" :foreground "#3d444d"))
  "Face used to draw the left bar of blockquotes."
  :group 'richmd-mode)

(defface richmd-mode-hr-face
  '((((background light)) :inherit fixed-pitch :foreground "#d1d9e0"
     :strike-through "#d1d9e0")
    (((background dark))  :inherit fixed-pitch :foreground "#3d444d"
     :strike-through "#3d444d"))
  "Face for horizontal rules."
  :group 'richmd-mode)

(defface richmd-mode-table-face
  '((t :inherit fixed-pitch))
  "Face for rendered Markdown tables."
  :group 'richmd-mode)

(defface richmd-mode-table-rule-face
  '((((background light)) :inherit fixed-pitch :foreground "#d0d7de")
    (((background dark))  :inherit fixed-pitch :foreground "#3d444d"))
  "Face for the box-drawing borders of rendered tables."
  :group 'richmd-mode)

(defface richmd-mode-table-header-face
  '((t :inherit fixed-pitch :weight bold))
  "Face for the header row of rendered tables."
  :group 'richmd-mode)

(defface richmd-mode-table-row-face
  '((((background light)) :inherit fixed-pitch :background "#f6f8fa")
    (((background dark))  :inherit fixed-pitch :background "#161b22"))
  "Face for the zebra-striped alternate body rows of rendered tables."
  :group 'richmd-mode)

(defface richmd-mode-list-bullet-face
  '((((background light)) :inherit variable-pitch :foreground "#59636e")
    (((background dark))  :inherit variable-pitch :foreground "#8b949e"))
  "Face for unordered list bullets."
  :group 'richmd-mode)

(defface richmd-mode-ordered-marker-face
  '((((background light)) :inherit variable-pitch :foreground "#59636e")
    (((background dark))  :inherit variable-pitch :foreground "#8b949e"))
  "Face for ordered list markers."
  :group 'richmd-mode)

(defcustom richmd-mode-list-bullets '("•" "◦" "▪" "▫")
  "Strings to substitute for unordered list markers by indent depth."
  :type '(repeat string)
  :group 'richmd-mode)

(defcustom richmd-mode-task-open "☐"
  "Display string used in place of an open task list checkbox."
  :type 'string
  :group 'richmd-mode)

(defcustom richmd-mode-task-done "☑"
  "Display string used in place of a closed task list checkbox."
  :type 'string
  :group 'richmd-mode)

(defcustom richmd-mode-line-spacing nil
  "Extra blank space inserted below each line while `richmd-mode' is active.

Bound to the buffer-local variable `line-spacing' on activation.
A positive integer N adds N pixels of empty space beneath every
line.  A floating point number N adds N times the default frame
line height of extra space.  Note that `line-spacing' only takes
effect on graphic displays (see `display-graphic-p').

Defaults to nil: Emacs applies `line-spacing' uniformly to every
line in the buffer with no reliable per-line override, so any
positive value would also pull the table rows apart and break the
box-drawing grid.  GitHub renders tables as a tight connected
grid, so a tight buffer matches the reference more faithfully."
  :type '(choice (const :tag "None" nil)
                 (integer :tag "Pixels")
                 (float :tag "Fraction"))
  :group 'richmd-mode)

(defcustom richmd-mode-text-scale 1.0
  "Relative height multiplier for the whole rendered buffer.

Applied as a `:height' face remap on top of
`richmd-mode-body-face' when `richmd-mode' is enabled, so every
construct (headings, code, tables) scales proportionally.  The
default enlarges the body to roughly match the font size GitHub
renders Markdown at relative to a typical Emacs default of 13px."
  :type 'number
  :group 'richmd-mode)

(defcustom richmd-mode-list-bullet-indent 2
  "Number of spaces injected before unordered list bullets for indentation."
  :type 'integer
  :group 'richmd-mode)

(defcustom richmd-mode-code-block-margin 2
  "Number of leading spaces shown before each fenced code block line."
  :type 'integer
  :group 'richmd-mode)

(defcustom richmd-mode-table-cell-padding 2
  "Number of blank columns inserted on each side of a table cell.
GitHub renders table cells with roomy horizontal padding; two
fixed-pitch columns approximate that better than a single one."
  :type 'integer
  :group 'richmd-mode)

(defcustom richmd-mode-table t
  "When non-nil, render GFM pipe tables with aligned box-drawing borders.

Imported from the `org-modern' Org rich-display library, whose
table beautification replaces the ASCII pipes and dashes with
box-drawing glyphs; here columns are additionally padded so they
line up under a fixed-pitch face."
  :type 'boolean
  :group 'richmd-mode)

(defcustom richmd-mode-reveal-markup t
  "When non-nil, reveal the hidden markup of the inline element at point.

Mirrors the behaviour of the `org-appear' Org rich-display
library: while point sits on a styled inline element its raw
Markdown markers are shown again so the element can be edited,
and they are hidden once point leaves."
  :type 'boolean
  :group 'richmd-mode)

(defcustom richmd-mode-reflow-paragraphs t
  "When non-nil, render soft line breaks inside a paragraph as spaces.

CommonMark and GitHub collapse a single newline within a
paragraph into a space and reflow the text to the container
width.  With this enabled `richmd-mode' overlays such intra-
paragraph newlines with a space and turns on word wrapping, so a
hard-wrapped Markdown source still displays as flowing paragraphs
instead of breaking mid-sentence.  Block boundaries (blank lines,
headings, lists, blockquotes, tables, fenced code) are never
joined."
  :type 'boolean
  :group 'richmd-mode)

(defvar-local richmd-mode--overlays nil)
(defvar-local richmd-mode--saved-word-wrap nil)
(defvar-local richmd-mode--had-local-word-wrap nil)
(defvar-local richmd-mode--saved-truncate-lines nil)
(defvar-local richmd-mode--had-local-truncate-lines nil)
(defvar-local richmd-mode--saved-fringe-alist nil)
(defvar-local richmd-mode--had-local-fringe-alist nil)
(defvar-local richmd-mode--revealed-span nil)
(defvar-local richmd-mode--revealed-markers nil)
(defvar-local richmd-mode--code-block-regions nil)
(defvar-local richmd-mode--table-regions nil)
(defvar-local richmd-mode--saved-line-spacing nil)
(defvar-local richmd-mode--had-local-line-spacing nil)
(defvar-local richmd-mode--body-cookie nil)
(defvar-local richmd-mode--refresh-timer nil)

(defvar richmd-mode)

(defun richmd-mode--heading-face (level)
  "Return the face symbol for heading LEVEL."
  (pcase level
    (1 'richmd-mode-heading-1-face)
    (2 'richmd-mode-heading-2-face)
    (3 'richmd-mode-heading-3-face)
    (4 'richmd-mode-heading-4-face)
    (5 'richmd-mode-heading-5-face)
    (_ 'richmd-mode-heading-6-face)))

(defun richmd-mode--bullet-for-depth (indent-cols)
  "Return the bullet glyph for INDENT-COLS columns of leading whitespace."
  (let* ((depth (/ indent-cols 2))
         (idx (min depth (1- (length richmd-mode-list-bullets)))))
    (nth idx richmd-mode-list-bullets)))

(defun richmd-mode--make-overlay (beg end &rest props)
  "Create a tracked overlay between BEG and END with PROPS."
  (let ((ov (make-overlay beg end nil t nil)))
    (overlay-put ov 'richmd-mode t)
    (overlay-put ov 'evaporate t)
    (while props
      (overlay-put ov (pop props) (pop props)))
    (push ov richmd-mode--overlays)
    ov))

(defun richmd-mode--make-inline (omb ome cb ce xmb xme face &rest content-props)
  "Overlay an inline element with hidden markers and a styled body.
OMB..OME and XMB..XME delimit the leading and trailing markers,
CB..CE the visible content shown with FACE plus CONTENT-PROPS."
  (let ((span (cons omb xme)))
    (richmd-mode--make-overlay omb ome
                               'invisible 'richmd-mode
                               'richmd-mode-marker t
                               'richmd-mode-span span)
    (apply #'richmd-mode--make-overlay cb ce
           'face face
           'richmd-mode-span span
           content-props)
    (richmd-mode--make-overlay xmb xme
                               'invisible 'richmd-mode
                               'richmd-mode-marker t
                               'richmd-mode-span span)))

(defun richmd-mode--clear-overlays (beg end)
  "Remove all `richmd-mode' overlays between BEG and END."
  (dolist (ov (overlays-in beg end))
    (when (overlay-get ov 'richmd-mode)
      (setq richmd-mode--overlays (delq ov richmd-mode--overlays))
      (delete-overlay ov))))

(defun richmd-mode--in-code-block-p (pos)
  "Return non-nil if POS lies inside a fenced code block or a table.
Inline fontifiers skip such regions, leaving their verbatim or
already-rendered content untouched."
  (cl-some (lambda (region)
             (and (>= pos (car region)) (< pos (cdr region))))
           (append richmd-mode--code-block-regions
                   richmd-mode--table-regions)))

(defun richmd-mode--scan-code-blocks (beg end)
  "Detect fenced code blocks in BEG..END and overlay them."
  (setq richmd-mode--code-block-regions nil)
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "^\\(```\\)\\([^\n]*\\)\n" end t)
      (let* ((fence-beg (match-beginning 0))
             (body-beg (match-end 0))
             (lang-beg (match-beginning 2))
             (lang-end (match-end 2))
             (lang (string-trim (buffer-substring-no-properties lang-beg lang-end))))
        (when (re-search-forward "^\\(```\\)[ \t]*$" end t)
          (let ((body-end (match-beginning 0))
                (fence-end (match-end 0))
                (margin (make-string richmd-mode-code-block-margin ?\s)))
            (push (cons fence-beg fence-end) richmd-mode--code-block-regions)
            (if (string-empty-p lang)
                (richmd-mode--make-overlay fence-beg body-beg 'invisible 'richmd-mode)
              (richmd-mode--make-overlay fence-beg lang-beg 'invisible 'richmd-mode)
              (richmd-mode--make-overlay lang-beg body-beg
                                         'face 'richmd-mode-code-block-lang-face
                                         'before-string
                                         (propertize margin 'face 'richmd-mode-code-block-lang-face)))
            (richmd-mode--make-overlay body-beg body-end
                                       'face 'richmd-mode-code-block-face
                                       'line-prefix
                                       (propertize margin 'face 'richmd-mode-code-block-face)
                                       'wrap-prefix
                                       (propertize margin 'face 'richmd-mode-code-block-face))
            (richmd-mode--make-overlay body-end fence-end 'invisible 'richmd-mode)))))))

(defun richmd-mode--table-cells (line)
  "Split a Markdown table LINE into a list of trimmed cell strings."
  (let ((s (string-trim line)))
    (when (string-prefix-p "|" s) (setq s (substring s 1)))
    (when (string-suffix-p "|" s) (setq s (substring s 0 -1)))
    (mapcar #'string-trim (split-string s "|"))))

(defun richmd-mode--table-delimiter-p (line)
  "Return non-nil if LINE is a GFM table delimiter row."
  (let ((cells (richmd-mode--table-cells line)))
    (and cells
         (string-match-p "|" line)
         (cl-every (lambda (c) (string-match-p "\\`:?-+:?\\'" c)) cells))))

(defun richmd-mode--table-align (cell)
  "Return the alignment symbol encoded by delimiter CELL."
  (let ((l (string-prefix-p ":" cell))
        (r (string-suffix-p ":" cell)))
    (cond ((and l r) 'center)
          (r 'right)
          (t 'left))))

(defun richmd-mode--table-pad (str width align)
  "Pad STR to WIDTH display columns according to ALIGN."
  (let ((gap (max 0 (- width (string-width str)))))
    (pcase align
      ('right (concat (make-string gap ?\s) str))
      ('center (let ((l (/ gap 2)))
                 (concat (make-string l ?\s) str
                         (make-string (- gap l) ?\s))))
      (_ (concat str (make-string gap ?\s))))))

(defun richmd-mode--table-render-row (cells aligns widths cellface)
  "Render data CELLS with ALIGNS and WIDTHS, styled by CELLFACE."
  (let* ((pad (make-string richmd-mode-table-cell-padding ?\s))
         (s (concat "│"
                    (mapconcat
                     (lambda (i)
                       (concat pad
                               (richmd-mode--table-pad (or (nth i cells) "")
                                                       (nth i widths)
                                                       (nth i aligns))
                               pad))
                     (number-sequence 0 (1- (length widths)))
                     "│")
                    "│")))
    (put-text-property 0 (length s) 'face cellface s)
    (let ((i 0))
      (while (setq i (string-search "│" s i))
        (put-text-property i (1+ i) 'face
                           (list 'richmd-mode-table-rule-face cellface) s)
        (setq i (1+ i))))
    s))

(defun richmd-mode--table-border (widths l m r)
  "Build a horizontal table border for WIDTHS using L, M, R junctions."
  (propertize
   (concat l
           (mapconcat
            (lambda (w)
              (make-string (+ w (* 2 richmd-mode-table-cell-padding)) ?─))
            widths m)
           r)
   'face 'richmd-mode-table-rule-face))

(defun richmd-mode--scan-tables (beg end)
  "Detect GFM pipe tables in BEG..END and render them with box borders."
  (setq richmd-mode--table-regions nil)
  (when richmd-mode-table
    (save-excursion
      (goto-char beg)
      (while (re-search-forward "^[ \t]*\\(|[^\n]*\\)$" end t)
        (let ((hbeg (line-beginning-position))
              (hend (line-end-position))
              (header (match-string-no-properties 1)))
          (forward-line 1)
          (if (and (< (point) end)
                   (not (richmd-mode--in-code-block-p hbeg))
                   (richmd-mode--table-delimiter-p
                    (buffer-substring-no-properties
                     (line-beginning-position) (line-end-position))))
              (let* ((sep-cells (richmd-mode--table-cells
                                 (buffer-substring-no-properties
                                  (line-beginning-position)
                                  (line-end-position))))
                     (ncols (length sep-cells))
                     (aligns (mapcar #'richmd-mode--table-align sep-cells))
                     (lines (list (cons hbeg hend)))
                     (rows (list (richmd-mode--table-cells header)))
                     (widths (make-list ncols 0)))
                (push (cons (line-beginning-position) (line-end-position))
                      lines)
                (push nil rows)
                (forward-line 1)
                (while (and (< (point) end)
                            (looking-at "^[ \t]*|[^\n]*$"))
                  (push (cons (line-beginning-position) (line-end-position))
                        lines)
                  (push (richmd-mode--table-cells
                         (buffer-substring-no-properties
                          (line-beginning-position) (line-end-position)))
                        rows)
                  (forward-line 1))
                (setq lines (nreverse lines)
                      rows (nreverse rows))
                (dolist (cells rows)
                  (when cells
                    (dotimes (i ncols)
                      (setf (nth i widths)
                            (max (nth i widths)
                                 (string-width (or (nth i cells) "")))))))
                (let* ((rbeg (caar lines))
                       (rend (cdar (last lines)))
                       (body 0)
                       (parts
                        (cl-loop
                         for cells in rows
                         for i from 0
                         collect
                         (cond
                          ((null cells)
                           (richmd-mode--table-border widths "├" "┼" "┤"))
                          ((= i 0)
                           (richmd-mode--table-render-row
                            cells aligns widths
                            'richmd-mode-table-header-face))
                          (t
                           (prog1
                               (richmd-mode--table-render-row
                                cells aligns widths
                                (if (cl-oddp body)
                                    'richmd-mode-table-row-face
                                  'richmd-mode-table-face))
                             (setq body (1+ body))))))))
                  (push (cons rbeg rend) richmd-mode--table-regions)
                  (richmd-mode--make-overlay
                   rbeg rend
                   'face 'richmd-mode-table-face
                   'display
                   (mapconcat
                    #'identity
                    (append
                     (list (richmd-mode--table-border widths "┌" "┬" "┐"))
                     parts
                     (list (richmd-mode--table-border widths "└" "┴" "┘")))
                    "\n"))))
            (goto-char hend)))))))

(defun richmd-mode--fontify-headings (beg end)
  "Fontify markdown ATX headings between BEG and END."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "^\\(#\\{1,6\\}\\) +\\([^\n]*\\)$" end t)
      (unless (richmd-mode--in-code-block-p (match-beginning 0))
        (let* ((level (- (match-end 1) (match-beginning 1)))
               (face (richmd-mode--heading-face level))
               (eol (line-end-position)))
          (richmd-mode--make-overlay (match-beginning 0) (match-beginning 2)
                                     'invisible 'richmd-mode)
          (richmd-mode--make-overlay (match-beginning 2) eol
                                     'face face
                                     'line-prefix nil
                                     'wrap-prefix nil)
          (richmd-mode--make-overlay
           eol eol
           'after-string
           (propertize " "
                       'face face
                       'display '(space :align-to right)))
          (when (<= level 2)
            (save-excursion
              (goto-char eol)
              (when (and (< (point) (point-max))
                         (eq (char-after) ?\n))
                (forward-line 1)
                (let ((bl (line-beginning-position))
                      (el (line-end-position)))
                  (when (and (= bl el) (< el (point-max))
                             (not (richmd-mode--in-code-block-p bl)))
                    (richmd-mode--make-overlay
                     el (1+ el)
                     'display
                     (concat (propertize
                              " "
                              'face 'richmd-mode-heading-rule-face
                              'display '(space :align-to right))
                             "\n"))))))))))))

(defun richmd-mode--fontify-horizontal-rule (beg end)
  "Fontify markdown horizontal rules between BEG and END."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "^\\(\\(?:[-*_] *\\)\\{3,\\}\\)[ \t]*$" end t)
      (unless (richmd-mode--in-code-block-p (match-beginning 0))
        (richmd-mode--make-overlay (match-beginning 1) (match-end 1)
                                   'face 'richmd-mode-hr-face
                                   'display
                                   (propertize (make-string 40 ?\s)
                                               'face 'richmd-mode-hr-face))))))

(defun richmd-mode--fontify-quotes (beg end)
  "Fontify markdown blockquote lines between BEG and END."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "^\\(>+\\) ?\\([^\n]*\\)$" end t)
      (unless (richmd-mode--in-code-block-p (match-beginning 0))
        (let ((depth (- (match-end 1) (match-beginning 1)))
              (bar-piece "  "))
          (richmd-mode--make-overlay
           (match-beginning 1) (match-end 1)
           'display (propertize
                     (apply #'concat (cl-loop repeat depth collect bar-piece))
                     'face 'richmd-mode-quote-bar-face)
           'face 'richmd-mode-quote-bar-face)
          (richmd-mode--make-overlay (match-beginning 2) (match-end 2)
                                     'face 'richmd-mode-quote-face))))))

(defun richmd-mode--fontify-task-lists (beg end)
  "Replace markdown task list checkboxes between BEG and END."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward
            "^\\([ \t]*\\)\\([-*+]\\)[ \t]+\\(\\[\\([ xX]\\)\\]\\)[ \t]"
            end t)
      (unless (richmd-mode--in-code-block-p (match-beginning 0))
        (let ((mark (match-string 4)))
          (richmd-mode--make-overlay
           (match-beginning 3) (match-end 3)
           'display (if (string-blank-p mark)
                        richmd-mode-task-open
                      richmd-mode-task-done)))))))

(defun richmd-mode--fontify-list-bullets (beg end)
  "Replace unordered list markers between BEG and END with a bullet."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "^\\([ \t]*\\)\\([-*+]\\)\\([ \t]+\\)" end t)
      (unless (or (richmd-mode--in-code-block-p (match-beginning 0))
                  (save-excursion
                    (goto-char (match-end 0))
                    (looking-at "\\[[ xX]\\][ \t]")))
        (let* ((indent (- (match-end 1) (match-beginning 1)))
               (bullet (richmd-mode--bullet-for-depth indent))
               (pad (make-string (max 0 richmd-mode-list-bullet-indent) ?\s)))
          (richmd-mode--make-overlay (match-beginning 2) (match-end 2)
                                     'display (concat pad bullet)
                                     'face 'richmd-mode-list-bullet-face))))))

(defun richmd-mode--fontify-ordered-list (beg end)
  "Subtly accent ordered list markers between BEG and END."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "^\\([ \t]*\\)\\([0-9]+\\.\\)[ \t]+" end t)
      (unless (richmd-mode--in-code-block-p (match-beginning 0))
        (richmd-mode--make-overlay (match-beginning 2) (match-end 2)
                                   'face 'richmd-mode-ordered-marker-face)))))

(defun richmd-mode--fontify-bold (beg end)
  "Fontify markdown bold text between BEG and END."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "\\*\\*\\([^*\n]+?\\)\\*\\*" end t)
      (unless (richmd-mode--in-code-block-p (match-beginning 0))
        (richmd-mode--make-inline (match-beginning 0) (match-beginning 1)
                                  (match-beginning 1) (match-end 1)
                                  (match-end 1) (match-end 0)
                                  'richmd-mode-bold-face)))))

(defun richmd-mode--fontify-italic (beg end)
  "Fontify markdown italic text between BEG and END."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward
            "\\(?:^\\|[^*_]\\)\\([*_]\\)\\([^*_\n]+?\\)\\1\\(?:[^*_]\\|$\\)"
            end t)
      (goto-char (1+ (match-end 2)))
      (unless (or (richmd-mode--in-code-block-p (match-beginning 1))
                  (and (eq (char-after (match-beginning 1)) ?_)
                       (let ((before (char-before (match-beginning 1)))
                             (after (char-after (1+ (match-end 2)))))
                         (or (and before (eq (char-syntax before) ?w))
                             (and after (eq (char-syntax after) ?w))))))
        (richmd-mode--make-inline (match-beginning 1) (match-end 1)
                                  (match-beginning 2) (match-end 2)
                                  (match-end 2) (1+ (match-end 2))
                                  'richmd-mode-italic-face)))))

(defun richmd-mode--fontify-strikethrough (beg end)
  "Fontify markdown strikethrough text between BEG and END."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "~~\\([^~\n]+?\\)~~" end t)
      (unless (richmd-mode--in-code-block-p (match-beginning 0))
        (richmd-mode--make-inline (match-beginning 0) (match-beginning 1)
                                  (match-beginning 1) (match-end 1)
                                  (match-end 1) (match-end 0)
                                  'richmd-mode-strikethrough-face)))))

(defun richmd-mode--fontify-inline-code (beg end)
  "Fontify markdown inline code between BEG and END."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "`\\([^`\n]+?\\)`" end t)
      (unless (richmd-mode--in-code-block-p (match-beginning 0))
        (richmd-mode--make-inline (match-beginning 0) (match-beginning 1)
                                  (match-beginning 1) (match-end 1)
                                  (match-end 1) (match-end 0)
                                  'richmd-mode-code-face)))))

(defun richmd-mode--paragraph-line-p (lb le)
  "Return non-nil if the line LB..LE is plain paragraph prose.
A paragraph line is non-blank, outside code blocks and tables,
and does not start a block construct."
  (let ((s (buffer-substring-no-properties lb le)))
    (and (not (richmd-mode--in-code-block-p lb))
         (string-match-p "[^ \t]" s)
         (not (string-match-p
               (concat "\\`[ \t]*\\(?:#\\{1,6\\}[ \t]\\|>\\|[-*+][ \t]"
                       "\\|[0-9]+\\.[ \t]\\||\\|```"
                       "\\|\\(?:[-*_][ \t]*\\)\\{3,\\}[ \t]*\\'\\)")
               s)))))

(defun richmd-mode--reflow-paragraphs (beg end)
  "Render single intra-paragraph newlines between BEG and END as spaces."
  (when richmd-mode-reflow-paragraphs
    (save-excursion
      (goto-char beg)
      (while (and (< (point) end) (not (eobp)))
        (let ((lb (line-beginning-position))
              (le (line-end-position)))
          (when (and (< le end)
                     (eq (char-after le) ?\n)
                     (richmd-mode--paragraph-line-p lb le)
                     (not (string-match-p
                           "  \\'" (buffer-substring-no-properties lb le)))
                     (save-excursion
                       (goto-char (1+ le))
                       (richmd-mode--paragraph-line-p
                        (line-beginning-position) (line-end-position))))
            (richmd-mode--make-overlay le (1+ le) 'display " ")))
        (forward-line 1)))))

(defun richmd-mode--neutralize-line-spacing (beg end)
  "Force every newline outside code blocks to render with the default face.

The line-spacing area below each visual line is painted using the
face attributes of the newline glyph terminating that line.  By
overlaying each newline with the `default' face we keep the
buffer-wide line-spacing strip neutral, so an inline-code
overlay's grey background can no longer bleed into the gap above
the following line."
  (save-excursion
    (goto-char beg)
    (while (search-forward "\n" end t)
      (let ((nl (1- (point))))
        (unless (richmd-mode--in-code-block-p nl)
          (richmd-mode--make-overlay nl (1+ nl)
                                     'face 'default
                                     'line-height t))))))

(defun richmd-mode--fontify-links (beg end)
  "Fontify markdown inline links between BEG and END."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "\\[\\([^]\n]+?\\)\\](\\([^)\n]+?\\))" end t)
      (unless (richmd-mode--in-code-block-p (match-beginning 0))
        (richmd-mode--make-inline (match-beginning 0) (match-beginning 1)
                                  (match-beginning 1) (match-end 1)
                                  (match-end 1) (match-end 0)
                                  'richmd-mode-link-face
                                  'help-echo (match-string-no-properties 2))))))

(defun richmd-mode--span-at-point ()
  "Return the inline element span (BEG . END) covering point, or nil."
  (let (span)
    (dolist (ov (overlays-in (max (point-min) (1- (point)))
                             (min (point-max) (1+ (point)))))
      (let ((s (overlay-get ov 'richmd-mode-span)))
        (when (and s (>= (point) (car s)) (<= (point) (cdr s)))
          (setq span s))))
    span))

(defun richmd-mode--unreveal ()
  "Re-hide the markers of the currently revealed inline element."
  (dolist (ov richmd-mode--revealed-markers)
    (when (overlay-buffer ov)
      (overlay-put ov 'invisible 'richmd-mode)))
  (setq richmd-mode--revealed-markers nil
        richmd-mode--revealed-span nil))

(defun richmd-mode--reveal-at-point ()
  "Reveal markup of the inline element at point, hiding any previous one."
  (let ((span (and richmd-mode-reveal-markup (richmd-mode--span-at-point))))
    (unless (equal span richmd-mode--revealed-span)
      (richmd-mode--unreveal)
      (when span
        (dolist (ov (overlays-in (car span) (cdr span)))
          (when (and (overlay-get ov 'richmd-mode-marker)
                     (equal (overlay-get ov 'richmd-mode-span) span))
            (overlay-put ov 'invisible nil)
            (push ov richmd-mode--revealed-markers)))
        (setq richmd-mode--revealed-span span)))))

(defun richmd-mode-fontify-buffer ()
  "Rebuild all `richmd-mode' overlays in the current buffer."
  (interactive)
  (with-silent-modifications
    (richmd-mode--clear-overlays (point-min) (point-max))
    (remove-text-properties (point-min) (point-max)
                            '(line-spacing nil line-height nil))
    (richmd-mode--scan-code-blocks (point-min) (point-max))
    (richmd-mode--scan-tables (point-min) (point-max))
    (richmd-mode--fontify-headings (point-min) (point-max))
    (richmd-mode--fontify-horizontal-rule (point-min) (point-max))
    (richmd-mode--fontify-quotes (point-min) (point-max))
    (richmd-mode--fontify-task-lists (point-min) (point-max))
    (richmd-mode--fontify-list-bullets (point-min) (point-max))
    (richmd-mode--fontify-ordered-list (point-min) (point-max))
    (richmd-mode--fontify-bold (point-min) (point-max))
    (richmd-mode--fontify-italic (point-min) (point-max))
    (richmd-mode--fontify-strikethrough (point-min) (point-max))
    (richmd-mode--fontify-inline-code (point-min) (point-max))
    (richmd-mode--fontify-links (point-min) (point-max))
    (richmd-mode--reflow-paragraphs (point-min) (point-max))
    (richmd-mode--neutralize-line-spacing (point-min) (point-max)))
  (setq richmd-mode--revealed-span nil
        richmd-mode--revealed-markers nil)
  (richmd-mode--reveal-at-point))

(defun richmd-mode--schedule-refresh (_beg _end _len)
  "Schedule a deferred re-fontification of the buffer."
  (when (timerp richmd-mode--refresh-timer)
    (cancel-timer richmd-mode--refresh-timer))
  (setq richmd-mode--refresh-timer
        (run-with-idle-timer 0.1 nil
                             (let ((buf (current-buffer)))
                               (lambda ()
                                 (when (buffer-live-p buf)
                                   (with-current-buffer buf
                                     (when richmd-mode
                                       (richmd-mode-fontify-buffer)))))))))

(defun richmd-mode--sync-code-family ()
  "Force code-related faces to use the `fixed-pitch' family explicitly.
This protects them from a buffer-wide `default' face remap to a
proportional family."
  (let ((mono (face-attribute 'fixed-pitch :family nil 'default)))
    (when (and mono (stringp mono))
      (set-face-attribute 'richmd-mode-code-face nil :family mono)
      (set-face-attribute 'richmd-mode-code-block-face nil :family mono)
      (set-face-attribute 'richmd-mode-code-block-lang-face nil :family mono)
      (set-face-attribute 'richmd-mode-hr-face nil :family mono))))

(defun richmd-mode--sync-italic-family ()
  "Give `richmd-mode-italic-face' a family that actually has an italic.
A proportional body font often ships without an italic variant,
so `:slant italic' would render upright.  When the inherited
family lacks an italic, substitute the first candidate family
that provides one."
  (let ((base (face-attribute 'variable-pitch :family nil 'default)))
    (unless (and base (stringp base)
                 (find-font (font-spec :family base :slant 'italic)))
      (let ((alt (cl-find-if
                  (lambda (f) (find-font (font-spec :family f :slant 'italic)))
                  '("Noto Sans" "DejaVu Sans" "Liberation Sans"
                    "Bitstream Vera Sans" "FreeSans"))))
        (when alt
          (set-face-attribute 'richmd-mode-italic-face nil :family alt))))))

(defun richmd-mode--enter-display ()
  "Apply buffer-local display settings for `richmd-mode'."
  (add-to-invisibility-spec 'richmd-mode)
  (setq richmd-mode--had-local-line-spacing
        (local-variable-p 'line-spacing))
  (setq richmd-mode--saved-line-spacing line-spacing)
  (setq-local line-spacing richmd-mode-line-spacing)
  (when richmd-mode-reflow-paragraphs
    (setq richmd-mode--had-local-word-wrap (local-variable-p 'word-wrap)
          richmd-mode--saved-word-wrap word-wrap
          richmd-mode--had-local-truncate-lines (local-variable-p 'truncate-lines)
          richmd-mode--saved-truncate-lines truncate-lines
          richmd-mode--had-local-fringe-alist
          (local-variable-p 'fringe-indicator-alist)
          richmd-mode--saved-fringe-alist fringe-indicator-alist)
    (setq-local word-wrap t)
    (setq-local truncate-lines nil)
    (setq-local fringe-indicator-alist
                (cons '(continuation nil nil)
                      (if (listp fringe-indicator-alist)
                          fringe-indicator-alist
                        (list fringe-indicator-alist)))))
  (richmd-mode--sync-code-family)
  (richmd-mode--sync-italic-family)
  (setq richmd-mode--body-cookie
        (face-remap-add-relative 'default 'richmd-mode-body-face
                                 :height richmd-mode-text-scale)))

(defun richmd-mode--exit-display ()
  "Revert buffer-local display settings applied by `richmd-mode'."
  (when richmd-mode--body-cookie
    (face-remap-remove-relative richmd-mode--body-cookie)
    (setq richmd-mode--body-cookie nil))
  (if richmd-mode--had-local-line-spacing
      (setq-local line-spacing richmd-mode--saved-line-spacing)
    (kill-local-variable 'line-spacing))
  (if richmd-mode--had-local-word-wrap
      (setq-local word-wrap richmd-mode--saved-word-wrap)
    (kill-local-variable 'word-wrap))
  (if richmd-mode--had-local-truncate-lines
      (setq-local truncate-lines richmd-mode--saved-truncate-lines)
    (kill-local-variable 'truncate-lines))
  (if richmd-mode--had-local-fringe-alist
      (setq-local fringe-indicator-alist richmd-mode--saved-fringe-alist)
    (kill-local-variable 'fringe-indicator-alist))
  (setq richmd-mode--saved-fringe-alist nil
        richmd-mode--had-local-fringe-alist nil)
  (setq richmd-mode--saved-line-spacing nil
        richmd-mode--had-local-line-spacing nil)
  (remove-from-invisibility-spec 'richmd-mode))

;;;###autoload
(define-minor-mode richmd-mode
  "Toggle rich rendering of Markdown buffers via overlays."
  :lighter " RichMd"
  (if richmd-mode
      (progn
        (richmd-mode--enter-display)
        (richmd-mode-fontify-buffer)
        (add-hook 'after-change-functions #'richmd-mode--schedule-refresh nil t)
        (add-hook 'post-command-hook #'richmd-mode--reveal-at-point nil t))
    (remove-hook 'post-command-hook #'richmd-mode--reveal-at-point t)
    (richmd-mode--unreveal)
    (remove-hook 'after-change-functions #'richmd-mode--schedule-refresh t)
    (when (timerp richmd-mode--refresh-timer)
      (cancel-timer richmd-mode--refresh-timer)
      (setq richmd-mode--refresh-timer nil))
    (with-silent-modifications
      (richmd-mode--clear-overlays (point-min) (point-max))
      (remove-text-properties (point-min) (point-max)
                              '(line-spacing nil line-height nil)))
    (setq richmd-mode--code-block-regions nil
          richmd-mode--table-regions nil)
    (richmd-mode--exit-display)))

(provide 'richmd-mode)

;;; richmd-mode.el ends here
