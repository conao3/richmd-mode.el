;;; richmd-mode-tests.el --- Test definitions for richmd-mode  -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Naoya Yamashita

;; Author: Naoya Yamashita <conao3@gmail.com>
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

;; Test definitions for `richmd-mode'.


;;; Code:

(require 'cl-lib)
(require 'cort)
(require 'richmd-mode)

(defun richmd-mode-tests--faces-in (buf-content)
  "Return the set of richmd faces produced by `richmd-mode' over BUF-CONTENT."
  (with-temp-buffer
    (insert buf-content)
    (richmd-mode 1)
    (let (faces)
      (dolist (ov (overlays-in (point-min) (point-max)))
        (let ((face (overlay-get ov 'face)))
          (when (and face (symbolp face)
                     (string-prefix-p "richmd-mode-" (symbol-name face)))
            (cl-pushnew face faces))))
      (sort faces (lambda (a b) (string< (symbol-name a) (symbol-name b)))))))

(cort-deftest richmd-mode-heading-faces
  '((:equal '(richmd-mode-heading-1-face)
            (richmd-mode-tests--faces-in "# Hello\n"))
    (:equal '(richmd-mode-heading-2-face)
            (richmd-mode-tests--faces-in "## Hello\n"))
    (:equal '(richmd-mode-heading-6-face)
            (richmd-mode-tests--faces-in "###### Hello\n"))))

(cort-deftest richmd-mode-setext-headings
  '((:equal '(richmd-mode-heading-1-face richmd-mode-heading-rule-face)
            (richmd-mode-tests--faces-in "Hello\n=====\n"))
    (:equal '(richmd-mode-heading-2-face richmd-mode-heading-rule-face)
            (richmd-mode-tests--faces-in "Hello\n-----\n"))
    (:equal '(richmd-mode-hr-face)
            (richmd-mode-tests--faces-in "para\n\n---\n"))))

(cort-deftest richmd-mode-inline-faces
  '((:equal '(richmd-mode-bold-face)
            (richmd-mode-tests--faces-in "before **bold** after\n"))
    (:equal '(richmd-mode-italic-face)
            (richmd-mode-tests--faces-in "before *italic* after\n"))
    (:equal '(richmd-mode-strikethrough-face)
            (richmd-mode-tests--faces-in "before ~~gone~~ after\n"))
    (:equal '(richmd-mode-code-face)
            (richmd-mode-tests--faces-in "before `code` after\n"))
    (:equal '(richmd-mode-link-face)
            (richmd-mode-tests--faces-in "see [docs](https://example.com)\n"))))

(cort-deftest richmd-mode-adjacent-italic
  '((:= 2
        (with-temp-buffer
          (insert "*a* *b*\n")
          (richmd-mode 1)
          (length (cl-remove-if-not
                   (lambda (ov)
                     (eq (overlay-get ov 'face) 'richmd-mode-italic-face))
                   (overlays-in (point-min) (point-max))))))))

(cort-deftest richmd-mode-intraword-underscore
  '((:equal nil
            (richmd-mode-tests--faces-in "snake_case_name\n"))
    (:equal nil
            (richmd-mode-tests--faces-in "foo_bar_baz path/to_some_file\n"))
    (:equal '(richmd-mode-italic-face)
            (richmd-mode-tests--faces-in "a _real italic_ word\n"))
    (:equal '(richmd-mode-italic-face)
            (richmd-mode-tests--faces-in "(_paren_) and *star* too\n"))))

(cort-deftest richmd-mode-code-block-faces
  '((:equal '(richmd-mode-code-block-face)
            (richmd-mode-tests--faces-in "```\nfoo\n```\n"))))

(cort-deftest richmd-mode-list-bullet-display
  '((:equal (concat (make-string richmd-mode-list-bullet-indent ?\s)
                    (car richmd-mode-list-bullets))
            (with-temp-buffer
              (insert "- item\n")
              (richmd-mode 1)
              (let (display)
                (dolist (ov (overlays-in (point-min) (point-max)))
                  (let ((d (overlay-get ov 'display)))
                    (when (stringp d) (setq display d))))
                display)))))

(defun richmd-mode-tests--marker-invisibility ()
  "Return the sorted list of `invisible' values of marker overlays."
  (let (vals)
    (dolist (ov (overlays-in (point-min) (point-max)))
      (when (overlay-get ov 'richmd-mode-marker)
        (push (overlay-get ov 'invisible) vals)))
    (sort vals (lambda (a b) (string< (format "%s" a) (format "%s" b))))))

(cort-deftest richmd-mode-reveal-at-point
  '((:equal '(nil nil)
            (with-temp-buffer
              (insert "x **bold** y\n")
              (richmd-mode 1)
              (goto-char 6)
              (richmd-mode--reveal-at-point)
              (richmd-mode-tests--marker-invisibility)))
    (:equal '(richmd-mode richmd-mode)
            (with-temp-buffer
              (insert "x **bold** y\n")
              (richmd-mode 1)
              (goto-char 6)
              (richmd-mode--reveal-at-point)
              (goto-char (point-max))
              (richmd-mode--reveal-at-point)
              (richmd-mode-tests--marker-invisibility)))
    (:equal '(richmd-mode richmd-mode)
            (with-temp-buffer
              (insert "x **bold** y\n")
              (let ((richmd-mode-reveal-markup nil))
                (richmd-mode 1)
                (goto-char 6)
                (richmd-mode--reveal-at-point)
                (richmd-mode-tests--marker-invisibility))))))

(defun richmd-mode-tests--table-displays (content)
  "Return the lines of the single table display string for CONTENT."
  (with-temp-buffer
    (insert content)
    (richmd-mode 1)
    (let (found)
      (dolist (ov (overlays-in (point-min) (point-max)))
        (let ((d (overlay-get ov 'display)))
          (when (and (stringp d) (string-match-p "[┌│├└]" d))
            (setq found d))))
      (and found (split-string found "\n")))))

(cort-deftest richmd-mode-table-render
  '((:equal '("┌─────────┬───────┐"
              "│  Name   │  Age  │"
              "├─────────┼───────┤"
              "│  Alice  │  30   │"
              "└─────────┴───────┘")
            (richmd-mode-tests--table-displays
             "| Name | Age |\n| --- | --- |\n| Alice | 30 |\n"))
    (:equal '("┌───────┐"
              "│    n  │"
              "├───────┤"
              "│  100  │"
              "└───────┘")
            (richmd-mode-tests--table-displays
             "| n |\n| --: |\n| 100 |\n"))
    (:equal nil
            (richmd-mode-tests--table-displays
             "this | is not | a table\n"))))

(cort-deftest richmd-mode-reflow-paragraphs
  '((:= 1
        (with-temp-buffer
          (insert "and a\n[link](https://example.com).\n")
          (richmd-mode 1)
          (length (cl-remove-if-not
                   (lambda (ov) (equal (overlay-get ov 'display) " "))
                   (overlays-in (point-min) (point-max))))))
    (:= 0
        (with-temp-buffer
          (insert "para one\n\npara two\n")
          (richmd-mode 1)
          (length (cl-remove-if-not
                   (lambda (ov) (equal (overlay-get ov 'display) " "))
                   (overlays-in (point-min) (point-max))))))
    (:= 0
        (with-temp-buffer
          (insert "- item one\n- item two\n")
          (richmd-mode 1)
          (length (cl-remove-if-not
                   (lambda (ov) (equal (overlay-get ov 'display) " "))
                   (overlays-in (point-min) (point-max))))))))

(cort-deftest richmd-mode-toggle-clears-overlays
  '((:= 0
        (with-temp-buffer
          (insert "# Heading\n\n**bold** text and `code`.\n")
          (richmd-mode 1)
          (richmd-mode -1)
          (length (cl-remove-if-not
                   (lambda (ov) (overlay-get ov 'richmd-mode))
                   (overlays-in (point-min) (point-max))))))))

(provide 'richmd-mode-tests)

;;; richmd-mode-tests.el ends here
