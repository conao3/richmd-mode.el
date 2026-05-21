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

(defgroup richmd nil
  "Rich rendering markdown buffer."
  :group 'convenience
  :prefix "richmd-mode-"
  :link '(url-link :tag "Github" "https://github.com/conao3/richmd-mode.el"))

(defface richmd-mode-body-face
  '((t :inherit variable-pitch))
  "Face applied to the buffer for proportional body rendering."
  :group 'richmd)

(defface richmd-mode-heading-1-face
  '((t :inherit (variable-pitch outline-1) :height 2.0 :weight bold))
  "Face for level-1 headings."
  :group 'richmd)

(defface richmd-mode-heading-2-face
  '((t :inherit (variable-pitch outline-2) :height 1.5 :weight bold))
  "Face for level-2 headings."
  :group 'richmd)

(defface richmd-mode-heading-rule-face
  '((((background light)) :overline "#d1d9e0" :height 1.6)
    (((background dark))  :overline "#3d444d" :height 1.6))
  "Face drawing the bottom rule under level-1 and level-2 headings.
GitHub separates the heading from its rule with padding; the rule
is rendered on the blank line that follows the heading (one
buffer line, so it stays aligned under
`display-line-numbers-mode') rather than as a glyph underline,
which would collide with the descenders of the large heading
font.  The `:height' multiplier inflates that blank line so the
rule sits with the same vertical breathing room GitHub gives it."
  :group 'richmd)

(defface richmd-mode-heading-3-face
  '((t :inherit (variable-pitch outline-3) :height 1.25 :weight bold))
  "Face for level-3 headings."
  :group 'richmd)

(defface richmd-mode-heading-4-face
  '((t :inherit (variable-pitch outline-4) :weight bold))
  "Face for level-4 headings."
  :group 'richmd)

(defface richmd-mode-heading-5-face
  '((t :inherit (variable-pitch outline-5) :weight bold :height 0.875))
  "Face for level-5 headings."
  :group 'richmd)

(defface richmd-mode-heading-6-face
  '((((background light)) :inherit (variable-pitch outline-6)
     :weight bold :height 0.85 :foreground "#656d76")
    (((background dark))  :inherit (variable-pitch outline-6)
     :weight bold :height 0.85 :foreground "#8b949e"))
  "Face for level-6 headings."
  :group 'richmd)

(defface richmd-mode-bold-face
  '((t :inherit bold))
  "Face for bold text."
  :group 'richmd)

(defface richmd-mode-italic-face
  '((t :inherit variable-pitch :slant italic))
  "Face for italic text.
Inherits `variable-pitch' so it matches the proportional body
font; `richmd-mode--sync-italic-family' substitutes an
italic-capable family when that font has no italic variant."
  :group 'richmd)

(defface richmd-mode-strikethrough-face
  '((t :strike-through t))
  "Face for strikethrough text."
  :group 'richmd)

(defface richmd-mode-code-face
  '((((background light)) :inherit fixed-pitch
     :background "#eaeef2" :foreground "#1f2328" :height 0.85)
    (((background dark))  :inherit fixed-pitch
     :background "#343942" :foreground "#e6edf3" :height 0.85))
  "Face for inline code.

GitHub renders inline code at roughly 85% of the surrounding font
size on a tinted background with no border; the size drop also
shrinks the glyph cell vertically and prevents the grey
background from visually merging with the `line-spacing' area of
adjacent lines."
  :group 'richmd)

(defface richmd-mode-code-block-face
  '((((background light)) :inherit fixed-pitch :background "#f6f8fa" :extend t)
    (((background dark))  :inherit fixed-pitch :background "#161b22" :extend t))
  "Face for fenced code blocks."
  :group 'richmd)

(defface richmd-mode-code-block-lang-face
  '((((background light)) :inherit fixed-pitch :foreground "#59636e"
     :background "#eaeef2" :extend t :height 0.9)
    (((background dark))  :inherit fixed-pitch :foreground "#8b949e"
     :background "#21262d" :extend t :height 0.9))
  "Face for the language tag line of a fenced code block."
  :group 'richmd)

(defface richmd-mode-link-face
  '((((background light)) :inherit variable-pitch :foreground "#0969da")
    (((background dark))  :inherit variable-pitch :foreground "#2f81f7"))
  "Face for links."
  :group 'richmd)

(defface richmd-mode-quote-face
  '((((background light)) :inherit variable-pitch :foreground "#59636e" :slant italic)
    (((background dark))  :inherit variable-pitch :foreground "#8b949e" :slant italic))
  "Face for blockquote text."
  :group 'richmd)

(defface richmd-mode-footnote-face
  '((((background light)) :inherit variable-pitch :foreground "#0969da" :height 0.85)
    (((background dark))  :inherit variable-pitch :foreground "#2f81f7" :height 0.85))
  "Face for footnote references and definition markers."
  :group 'richmd)

(defface richmd-mode-alert-note-face
  '((((background light)) :foreground "#0969da" :weight bold)
    (((background dark))  :foreground "#2f81f7" :weight bold))
  "Face for the title of a GitHub `[!NOTE]' alert."
  :group 'richmd)

(defface richmd-mode-alert-tip-face
  '((((background light)) :foreground "#1a7f37" :weight bold)
    (((background dark))  :foreground "#3fb950" :weight bold))
  "Face for the title of a GitHub `[!TIP]' alert."
  :group 'richmd)

(defface richmd-mode-alert-important-face
  '((((background light)) :foreground "#8250df" :weight bold)
    (((background dark))  :foreground "#a371f7" :weight bold))
  "Face for the title of a GitHub `[!IMPORTANT]' alert."
  :group 'richmd)

(defface richmd-mode-alert-warning-face
  '((((background light)) :foreground "#9a6700" :weight bold)
    (((background dark))  :foreground "#d29922" :weight bold))
  "Face for the title of a GitHub `[!WARNING]' alert."
  :group 'richmd)

(defface richmd-mode-alert-caution-face
  '((((background light)) :foreground "#cf222e" :weight bold)
    (((background dark))  :foreground "#f85149" :weight bold))
  "Face for the title of a GitHub `[!CAUTION]' alert."
  :group 'richmd)

(defface richmd-mode-alert-note-bar-face
  '((((background light)) :background "#0969da" :foreground "#0969da")
    (((background dark))  :background "#2f81f7" :foreground "#2f81f7"))
  "Bar face for a GitHub `[!NOTE]' alert block."
  :group 'richmd)

(defface richmd-mode-alert-tip-bar-face
  '((((background light)) :background "#1a7f37" :foreground "#1a7f37")
    (((background dark))  :background "#3fb950" :foreground "#3fb950"))
  "Bar face for a GitHub `[!TIP]' alert block."
  :group 'richmd)

(defface richmd-mode-alert-important-bar-face
  '((((background light)) :background "#8250df" :foreground "#8250df")
    (((background dark))  :background "#a371f7" :foreground "#a371f7"))
  "Bar face for a GitHub `[!IMPORTANT]' alert block."
  :group 'richmd)

(defface richmd-mode-alert-warning-bar-face
  '((((background light)) :background "#9a6700" :foreground "#9a6700")
    (((background dark))  :background "#d29922" :foreground "#d29922"))
  "Bar face for a GitHub `[!WARNING]' alert block."
  :group 'richmd)

(defface richmd-mode-alert-caution-bar-face
  '((((background light)) :background "#cf222e" :foreground "#cf222e")
    (((background dark))  :background "#f85149" :foreground "#f85149"))
  "Bar face for a GitHub `[!CAUTION]' alert block."
  :group 'richmd)

(defface richmd-mode-quote-bar-face
  '((((background light)) :background "#d0d7de" :foreground "#d0d7de")
    (((background dark))  :background "#3d444d" :foreground "#3d444d"))
  "Face used to draw the left bar of blockquotes."
  :group 'richmd)

(defface richmd-mode-hr-face
  '((((background light)) :inherit fixed-pitch :foreground "#d1d9e0"
     :strike-through "#d1d9e0")
    (((background dark))  :inherit fixed-pitch :foreground "#3d444d"
     :strike-through "#3d444d"))
  "Face for horizontal rules."
  :group 'richmd)

(defface richmd-mode-table-face
  '((t :inherit fixed-pitch))
  "Face for rendered Markdown tables."
  :group 'richmd)

(defface richmd-mode-table-rule-face
  '((((background light)) :inherit fixed-pitch :foreground "#d0d7de")
    (((background dark))  :inherit fixed-pitch :foreground "#3d444d"))
  "Face for the box-drawing borders of rendered tables."
  :group 'richmd)

(defface richmd-mode-table-header-face
  '((t :inherit fixed-pitch :weight bold))
  "Face for the header row of rendered tables."
  :group 'richmd)

(defface richmd-mode-table-row-face
  '((((background light)) :inherit fixed-pitch :background "#f6f8fa")
    (((background dark))  :inherit fixed-pitch :background "#161b22"))
  "Face for the zebra-striped alternate body rows of rendered tables."
  :group 'richmd)

(defface richmd-mode-list-bullet-face
  '((((background light)) :inherit variable-pitch :foreground "#59636e")
    (((background dark))  :inherit variable-pitch :foreground "#8b949e"))
  "Face for unordered list bullets."
  :group 'richmd)

(defface richmd-mode-ordered-marker-face
  '((((background light)) :inherit variable-pitch :foreground "#59636e")
    (((background dark))  :inherit variable-pitch :foreground "#8b949e"))
  "Face for ordered list markers."
  :group 'richmd)

(defcustom richmd-mode-list-bullets '("•" "◦" "▪" "▫")
  "Strings to substitute for unordered list markers by indent depth."
  :type '(repeat string)
  :group 'richmd)

(defcustom richmd-mode-task-open "☐"
  "Display string used in place of an open task list checkbox."
  :type 'string
  :group 'richmd)

(defcustom richmd-mode-alert-titles
  '(("NOTE"      . "ⓘ Note")
    ("TIP"       . "💡 Tip")
    ("IMPORTANT" . "❗ Important")
    ("WARNING"   . "⚠ Warning")
    ("CAUTION"   . "🛑 Caution"))
  "Display titles substituted for `[!TYPE]' tags in GitHub Alerts."
  :type '(alist :key-type string :value-type string)
  :group 'richmd)

(defcustom richmd-mode-image-prefix "🖼 "
  "Glyph inserted before the alt text of an inline image.
GitHub renders the image itself, which a buffer-only renderer
cannot.  Showing a small icon before the alt text signals at a
glance that the span is an image rather than a plain link."
  :type 'string
  :group 'richmd)

(defcustom richmd-mode-task-done "☑"
  "Display string used in place of a closed task list checkbox."
  :type 'string
  :group 'richmd)

(defcustom richmd-mode-line-spacing 4
  "Extra blank space inserted below each line while `richmd-mode' is active.

Bound to the buffer-local variable `line-spacing' on activation.
A positive integer N adds N pixels of empty space beneath every
line.  A floating point number N adds N times the default frame
line height of extra space.  Note that `line-spacing' only takes
effect on graphic displays (see `display-graphic-p').

Defaults to 4 pixels, which gives the body the same breathing
room GitHub renders Markdown with.  Tables are unaffected because
each table is laid out as a single multi-line display string
spanning one buffer line; the internal grid stays connected
regardless of `line-spacing'."
  :type '(choice (const :tag "None" nil)
                 (integer :tag "Pixels")
                 (float :tag "Fraction"))
  :group 'richmd)

(defcustom richmd-mode-text-scale 1.0
  "Relative height multiplier for the whole rendered buffer.

Applied as a `:height' face remap on top of
`richmd-mode-body-face' when `richmd-mode' is enabled, so every
construct (headings, code, tables) scales proportionally.  The
default enlarges the body to roughly match the font size GitHub
renders Markdown at relative to a typical Emacs default of 13px."
  :type 'number
  :group 'richmd)

(defcustom richmd-mode-list-bullet-indent 4
  "Number of spaces injected before unordered list bullets for indentation.
GitHub indents lists by roughly 2em; four columns approximates
that.  The hanging indent of wrapped item lines tracks this
value, so deeper bullets keep their continuation aligned."
  :type 'integer
  :group 'richmd)

(defcustom richmd-mode-code-block-margin 2
  "Number of leading spaces shown before each fenced code block line."
  :type 'integer
  :group 'richmd)

(defcustom richmd-mode-table-cell-padding 2
  "Number of blank columns inserted on each side of a table cell.
GitHub renders table cells with roomy horizontal padding; two
fixed-pitch columns approximate that better than a single one."
  :type 'integer
  :group 'richmd)

(defcustom richmd-mode-table t
  "When non-nil, render GFM pipe tables with aligned box-drawing borders.

Imported from the `org-modern' Org rich-display library, whose
table beautification replaces the ASCII pipes and dashes with
box-drawing glyphs; here columns are additionally padded so they
line up under a fixed-pitch face."
  :type 'boolean
  :group 'richmd)

(defcustom richmd-mode-reveal-markup t
  "When non-nil, reveal the hidden markup of the inline element at point.

Mirrors the behaviour of the `org-appear' Org rich-display
library: while point sits on a styled inline element its raw
Markdown markers are shown again so the element can be edited,
and they are hidden once point leaves."
  :type 'boolean
  :group 'richmd)

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
  :group 'richmd)

(defvar-local richmd-mode--overlays nil)
(defvar-local richmd-mode--enabled-visual-line nil)
(defvar-local richmd-mode--revealed-span nil)
(defvar-local richmd-mode--revealed-markers nil)
(defvar-local richmd-mode--code-block-regions nil)
(defvar-local richmd-mode--table-regions nil)
(defvar-local richmd-mode--setext-regions nil)
(defvar-local richmd-mode--link-defs nil)
(defvar-local richmd-mode--alert-regions nil)
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

(defun richmd-mode--scan-indented-code-blocks (beg end)
  "Detect 4-space indented code blocks in BEG..END.
A line starting with at least four spaces (or a tab) is treated as
a code block when it follows a blank line (or the start of the
buffer) and the most recent non-blank line is not a list item, so
list continuation lines are not misclassified."
  (save-excursion
    (goto-char beg)
    (while (< (point) end)
      (cond
       ((richmd-mode--in-code-block-p (point))
        (forward-line 1))
       ((and (bolp)
             (looking-at "^\\(?:    \\|\t\\)[^\n]")
             (or (= (point) (point-min))
                 (save-excursion
                   (forward-line -1)
                   (looking-at "^[ \t]*$")))
             (save-excursion
               (forward-line -1)
               (while (and (> (point) (point-min))
                           (looking-at "^[ \t]*$"))
                 (forward-line -1))
               (or (looking-at "^[ \t]*$")
                   (not (string-match-p
                         "\\`[ \t]*\\(?:[-*+][ \t]\\|[0-9]+\\.[ \t]\\)"
                         (buffer-substring-no-properties
                          (line-beginning-position)
                          (line-end-position)))))))
        (let ((bbeg (line-beginning-position))
              (block-end (line-beginning-position)))
          (while (and (< (point) end)
                      (or (looking-at "^\\(?:    \\|\t\\)")
                          (and (looking-at "^[ \t]*$")
                               (save-excursion
                                 (forward-line 1)
                                 (looking-at "^\\(?:    \\|\t\\)")))))
            (forward-line 1)
            (setq block-end (point)))
          (push (cons bbeg block-end) richmd-mode--code-block-regions)
          (richmd-mode--make-overlay
           bbeg block-end
           'face 'richmd-mode-code-block-face
           'line-prefix
           (propertize (make-string richmd-mode-code-block-margin ?\s)
                       'face 'richmd-mode-code-block-face)
           'wrap-prefix
           (propertize (make-string richmd-mode-code-block-margin ?\s)
                       'face 'richmd-mode-code-block-face))))
       (t (forward-line 1))))))

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
                (richmd-mode--make-overlay
                 eol (1+ eol)
                 'after-string
                 (propertize " "
                             'face 'richmd-mode-heading-rule-face
                             'display '(space :align-to right)))))))))))

(defun richmd-mode--in-setext-p (pos)
  "Return non-nil if POS is inside a setext heading underline span."
  (cl-some (lambda (region)
             (and (>= pos (car region)) (< pos (cdr region))))
           richmd-mode--setext-regions))

(defun richmd-mode--fontify-setext-headings (beg end)
  "Fontify setext-style headings between BEG and END.
A non-blank paragraph line followed by a line of `=' (level 1) or
`-' (level 2) characters is rendered with the heading face; the
underline characters are replaced by a thin rule.  Per CommonMark
this takes precedence over horizontal-rule recognition when the
underline is `---'."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "^\\(=+\\|-+\\)[ \t]*$" end t)
      (let* ((ubeg (match-beginning 1))
             (uend (match-end 1))
             (under (char-after ubeg))
             (level (if (eq under ?=) 1 2)))
        (when (> ubeg (point-min))
          (save-excursion
            (goto-char (1- ubeg))
            (let ((tbeg (line-beginning-position))
                  (tend (line-end-position)))
              (when (and (richmd-mode--paragraph-line-p tbeg tend)
                         (not (richmd-mode--in-code-block-p ubeg)))
                (let ((face (richmd-mode--heading-face level)))
                  (richmd-mode--make-overlay tbeg tend
                                             'face face
                                             'line-prefix nil
                                             'wrap-prefix nil)
                  (richmd-mode--make-overlay
                   ubeg uend
                   'face 'richmd-mode-heading-rule-face
                   'display '(space :align-to right))
                  (push (cons ubeg uend)
                        richmd-mode--setext-regions))))))))))

(defun richmd-mode--fontify-horizontal-rule (beg end)
  "Fontify markdown horizontal rules between BEG and END."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "^\\(\\(?:[-*_] *\\)\\{3,\\}\\)[ \t]*$" end t)
      (unless (or (richmd-mode--in-code-block-p (match-beginning 0))
                  (richmd-mode--in-setext-p (match-beginning 1)))
        (richmd-mode--make-overlay (match-beginning 1) (match-end 1)
                                   'face 'richmd-mode-hr-face
                                   'display
                                   (propertize (make-string 40 ?\s)
                                               'face 'richmd-mode-hr-face))))))

(defun richmd-mode--in-alert-p (pos)
  "Return non-nil if POS lies on a line already styled as a GitHub alert."
  (cl-some (lambda (region)
             (and (>= pos (car region)) (<= pos (cdr region))))
           richmd-mode--alert-regions))

(defun richmd-mode--fontify-alerts (beg end)
  "Fontify GitHub Alerts (`> [!NOTE]' …) between BEG and END."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward
            (concat "^[ \t]*\\(>\\)[ \t]+"
                    "\\[!\\(NOTE\\|TIP\\|IMPORTANT\\|WARNING\\|CAUTION\\)\\]"
                    "[ \t]*$")
            end t)
      (unless (richmd-mode--in-code-block-p (match-beginning 0))
        (let* ((type (match-string-no-properties 2))
               (title-face (intern (format "richmd-mode-alert-%s-face"
                                           (downcase type))))
               (bar-face (intern (format "richmd-mode-alert-%s-bar-face"
                                         (downcase type))))
               (title (or (cdr (assoc type richmd-mode-alert-titles)) type))
               (bar-piece "  "))
          (richmd-mode--make-overlay
           (match-beginning 1) (match-end 1)
           'face bar-face
           'display (propertize bar-piece 'face bar-face))
          (richmd-mode--make-overlay
           (match-end 1) (match-end 0)
           'face title-face
           'display (propertize (concat " " title) 'face title-face))
          (push (cons (line-beginning-position) (line-end-position))
                richmd-mode--alert-regions)
          (forward-line 1)
          (while (and (< (point) end)
                      (looking-at "^[ \t]*\\(>+\\)[ \t]?\\([^\n]*\\)$"))
            (let ((depth (- (match-end 1) (match-beginning 1))))
              (richmd-mode--make-overlay
               (match-beginning 1) (match-end 1)
               'face bar-face
               'display
               (propertize
                (apply #'concat (cl-loop repeat depth collect bar-piece))
                'face bar-face))
              (richmd-mode--make-overlay (match-beginning 2) (match-end 2)
                                         'face 'richmd-mode-quote-face)
              (push (cons (line-beginning-position) (line-end-position))
                    richmd-mode--alert-regions)
              (forward-line 1))))))))

(defun richmd-mode--fontify-quotes (beg end)
  "Fontify markdown blockquote lines between BEG and END."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "^\\(>+\\) ?\\([^\n]*\\)$" end t)
      (unless (or (richmd-mode--in-code-block-p (match-beginning 0))
                  (richmd-mode--in-alert-p (match-beginning 0)))
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

(defun richmd-mode--hang-indent (cols)
  "Hang-indent the wrapped rows of the current line to column COLS.
Imported from `org-modern', which aligns continuation lines via a
`wrap-prefix' text property so every soft-wrapped row of a list
item is indented under its text.  It must be a text property:
overlay `wrap-prefix' is not honored by the display engine, and a
plain space string is used because a `(space :align-to)' display
spec is ignored inside `wrap-prefix'."
  (put-text-property
   (line-beginning-position) (line-end-position)
   'wrap-prefix (make-string (max 0 cols) ?\s)))

(defun richmd-mode--fontify-task-lists (beg end)
  "Replace markdown task list checkboxes between BEG and END."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward
            "^\\([ \t]*\\)\\([-*+]\\)[ \t]+\\(\\[\\([ xX]\\)\\]\\)[ \t]"
            end t)
      (unless (richmd-mode--in-code-block-p (match-beginning 0))
        (let ((mark (match-string 4))
              (text-col (save-excursion
                          (goto-char (match-end 0))
                          (current-column))))
          (richmd-mode--make-overlay
           (match-beginning 3) (match-end 3)
           'display (if (string-blank-p mark)
                        richmd-mode-task-open
                      richmd-mode-task-done))
          (richmd-mode--hang-indent (max 0 (- text-col 2))))))))

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
               (pad (make-string (max 0 richmd-mode-list-bullet-indent) ?\s))
               (text-col (save-excursion
                           (goto-char (match-end 0))
                           (current-column))))
          (richmd-mode--make-overlay (match-beginning 2) (match-end 2)
                                     'display (concat pad bullet)
                                     'face 'richmd-mode-list-bullet-face)
          (richmd-mode--hang-indent
           (+ text-col (max 0 richmd-mode-list-bullet-indent))))))))

(defun richmd-mode--fontify-ordered-list (beg end)
  "Subtly accent ordered list markers between BEG and END."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "^\\([ \t]*\\)\\([0-9]+\\.\\)[ \t]+" end t)
      (unless (richmd-mode--in-code-block-p (match-beginning 0))
        (richmd-mode--make-overlay (match-beginning 2) (match-end 2)
                                   'face 'richmd-mode-ordered-marker-face)
        (richmd-mode--hang-indent
         (save-excursion (goto-char (match-end 0)) (current-column)))))))

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
  "Neutralize newline faces between BEG and END outside code blocks.

The `line-spacing' area below each visual line is painted using
the face attributes of the newline glyph terminating that line.
By overlaying each newline with the `default' face we keep the
buffer-wide `line-spacing' strip neutral, so an inline-code
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

(defun richmd-mode--scan-link-defs (beg end)
  "Collect reference link definitions in BEG..END and hide their lines."
  (setq richmd-mode--link-defs (make-hash-table :test 'equal))
  (save-excursion
    (goto-char beg)
    (while (re-search-forward
            (concat "^[ \t]*\\[\\([^]\n]+\\)\\]:[ \t]+"
                    "\\([^ \t\n\"<>]+\\|<[^>\n]+>\\)"
                    "\\(?:[ \t]+\"[^\"\n]*\"\\)?[ \t]*$")
            end t)
      (unless (richmd-mode--in-code-block-p (match-beginning 0))
        (let ((id (downcase (string-trim (match-string-no-properties 1))))
              (url (let ((u (match-string-no-properties 2)))
                     (if (and (string-prefix-p "<" u)
                              (string-suffix-p ">" u))
                         (substring u 1 -1)
                       u))))
          (puthash id url richmd-mode--link-defs)
          (richmd-mode--make-overlay
           (line-beginning-position)
           (min (1+ (line-end-position)) (point-max))
           'invisible 'richmd-mode))))))

(defun richmd-mode--fontify-reference-links (beg end)
  "Fontify reference-style links between BEG and END.
Handles full (`[text][id]') and collapsed (`[id][]') forms; the
shortcut form (`[id]') is intentionally not supported because it
would collide with task-list checkboxes and GitHub alerts."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward
            "\\[\\([^]\n]+?\\)\\]\\[\\([^]\n]*\\)\\]"
            end t)
      (unless (or (richmd-mode--in-code-block-p (match-beginning 0))
                  (and (> (match-beginning 0) (point-min))
                       (eq (char-before (match-beginning 0)) ?!)))
        (let* ((text (match-string-no-properties 1))
               (id-raw (match-string-no-properties 2))
               (id (downcase (if (string-empty-p id-raw) text id-raw)))
               (url (and richmd-mode--link-defs
                         (gethash id richmd-mode--link-defs))))
          (when url
            (richmd-mode--make-inline
             (match-beginning 0) (match-beginning 1)
             (match-beginning 1) (match-end 1)
             (match-end 1) (match-end 0)
             'richmd-mode-link-face
             'help-echo url)))))))

(defun richmd-mode--fontify-footnotes (beg end)
  "Fontify GFM footnotes between BEG and END.
Definitions (`[^id]: …') replace the bracketed marker with `id:'
in the footnote face; references (`[^id]') are shown as `^id'."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "^\\[\\^\\([^]\n]+\\)\\]:[ \t]+" end t)
      (unless (richmd-mode--in-code-block-p (match-beginning 0))
        (richmd-mode--make-overlay
         (match-beginning 0) (match-end 0)
         'display (propertize (concat (match-string-no-properties 1) ": ")
                              'face 'richmd-mode-footnote-face)))))
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "\\[\\^\\([^]\n]+\\)\\]" end t)
      (unless (or (richmd-mode--in-code-block-p (match-beginning 0))
                  (save-excursion
                    (goto-char (match-beginning 0))
                    (looking-back "^" (line-beginning-position))))
        (richmd-mode--make-overlay
         (match-beginning 0) (match-end 0)
         'face 'richmd-mode-footnote-face
         'display (propertize (concat "^" (match-string-no-properties 1))
                              'face 'richmd-mode-footnote-face))))))

(defun richmd-mode--fontify-autolinks (beg end)
  "Fontify GFM autolinks between BEG and END.
Handles angle-bracketed URLs and emails (`<url>', `<addr@host>')
and bare http/https URLs in running text; trailing sentence
punctuation is stripped from bare URLs to mirror GFM's extended
autolink rules."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward
            (concat "<\\(\\(?:https?\\|ftp\\|mailto\\):[^>\n[:space:]]+"
                    "\\|[^>\n@[:space:]]+@[^>\n@[:space:]]+\\)>")
            end t)
      (unless (richmd-mode--in-code-block-p (match-beginning 0))
        (richmd-mode--make-inline
         (match-beginning 0) (match-beginning 1)
         (match-beginning 1) (match-end 1)
         (match-end 1) (match-end 0)
         'richmd-mode-link-face
         'help-echo (match-string-no-properties 1)))))
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "\\bhttps?://[^]<>[:space:])]+" end t)
      (let* ((mbeg (match-beginning 0))
             (mend (match-end 0))
             (before (and (> mbeg (point-min)) (char-before mbeg)))
             (face-at (get-char-property mbeg 'face)))
        (unless (or (richmd-mode--in-code-block-p mbeg)
                    (memq before '(?\( ?\[ ?> ?< ?\" ?'))
                    (eq face-at 'richmd-mode-link-face)
                    (and (listp face-at)
                         (memq 'richmd-mode-link-face face-at)))
          (while (and (> mend mbeg)
                      (memq (char-before mend) '(?. ?, ?\; ?: ?! ?\?)))
            (setq mend (1- mend)))
          (richmd-mode--make-overlay
           mbeg mend
           'face 'richmd-mode-link-face
           'help-echo (buffer-substring-no-properties mbeg mend)))))))

(defun richmd-mode--fontify-images (beg end)
  "Fontify markdown inline images between BEG and END.
GitHub renders `![alt](url)' as an inline image; in a terminal
buffer the alt text is shown with the link face plus an image
prefix glyph, and the URL is exposed via `help-echo'."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "!\\[\\([^]\n]*\\)\\](\\([^)\n]+?\\))" end t)
      (unless (richmd-mode--in-code-block-p (match-beginning 0))
        (let ((omb (match-beginning 0))
              (alt-beg (match-beginning 1))
              (alt-end (match-end 1))
              (xme (match-end 0))
              (url (match-string-no-properties 2)))
          (richmd-mode--make-inline
           omb alt-beg alt-beg alt-end alt-end xme
           'richmd-mode-link-face
           'before-string (propertize richmd-mode-image-prefix
                                      'face 'richmd-mode-link-face)
           'help-echo url))))))

(defun richmd-mode--fontify-links (beg end)
  "Fontify markdown inline links between BEG and END."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "\\[\\([^]\n]+?\\)\\](\\([^)\n]+?\\))" end t)
      (unless (or (richmd-mode--in-code-block-p (match-beginning 0))
                  (and (> (match-beginning 0) (point-min))
                       (eq (char-before (match-beginning 0)) ?!)))
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
                            '(line-spacing nil line-height nil wrap-prefix nil))
    (setq richmd-mode--setext-regions nil
          richmd-mode--link-defs nil
          richmd-mode--alert-regions nil)
    (richmd-mode--scan-code-blocks (point-min) (point-max))
    (richmd-mode--scan-tables (point-min) (point-max))
    (richmd-mode--scan-indented-code-blocks (point-min) (point-max))
    (richmd-mode--scan-link-defs (point-min) (point-max))
    (richmd-mode--fontify-setext-headings (point-min) (point-max))
    (richmd-mode--fontify-headings (point-min) (point-max))
    (richmd-mode--fontify-horizontal-rule (point-min) (point-max))
    (richmd-mode--fontify-alerts (point-min) (point-max))
    (richmd-mode--fontify-quotes (point-min) (point-max))
    (richmd-mode--fontify-task-lists (point-min) (point-max))
    (richmd-mode--fontify-list-bullets (point-min) (point-max))
    (richmd-mode--fontify-ordered-list (point-min) (point-max))
    (richmd-mode--fontify-bold (point-min) (point-max))
    (richmd-mode--fontify-italic (point-min) (point-max))
    (richmd-mode--fontify-strikethrough (point-min) (point-max))
    (richmd-mode--fontify-inline-code (point-min) (point-max))
    (richmd-mode--fontify-images (point-min) (point-max))
    (richmd-mode--fontify-links (point-min) (point-max))
    (richmd-mode--fontify-reference-links (point-min) (point-max))
    (richmd-mode--fontify-footnotes (point-min) (point-max))
    (richmd-mode--fontify-autolinks (point-min) (point-max))
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
  (when (and richmd-mode-reflow-paragraphs
             (not (bound-and-true-p visual-line-mode)))
    (visual-line-mode 1)
    (setq richmd-mode--enabled-visual-line t))
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
  (when richmd-mode--enabled-visual-line
    (visual-line-mode -1)
    (setq richmd-mode--enabled-visual-line nil))
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
                              '(line-spacing nil line-height nil wrap-prefix nil)))
    (setq richmd-mode--code-block-regions nil
          richmd-mode--table-regions nil
          richmd-mode--setext-regions nil
          richmd-mode--link-defs nil
          richmd-mode--alert-regions nil)
    (richmd-mode--exit-display)))

(provide 'richmd-mode)

;;; richmd-mode.el ends here
