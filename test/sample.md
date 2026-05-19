# richmd-mode sample

This buffer exercises every construct that `richmd-mode` renders.
Toggle it with `M-x richmd-mode` and move point over the styled
spans to see the `org-appear`-style markup reveal.

## Heading level 2

### Heading level 3

#### Heading level 4

##### Heading level 5

###### Heading level 6

## Inline styles

Plain body text rendered with a proportional face, then **bold**,
*italic*, _italic too_, ~~strikethrough~~ and `inline code`.

Adjacent emphasis used to drop the second span: *one* *two* *three*.

A link to the [project page](https://github.com/conao3/richmd-mode.el)
and a bare reference: see [docs](https://example.com) for details.

## Blockquotes

> A single-level blockquote.
>
> > A nested blockquote that draws two bars.

## Lists

- Unordered item
  - Nested item (deeper bullet glyph)
    - Even deeper
- Back to top level

1. Ordered item
2. Second item
3. Third item

### Task list

- [ ] Open task
- [x] Completed task
- [ ] Another open task

## Horizontal rule

Above the rule.

---

Below the rule.

## Code block

Fenced block without a language:

```
plain preformatted text
no language tag
```

Fenced block with a language tag:

```emacs-lisp
(defun richmd-mode-sample ()
  "Inline `code` markers inside a block stay verbatim."
  (message "| pipes | are | not | a | table | here |"))
```

## Tables

A left/right aligned table:

| Language | Stars |
|:---------|------:|
| Emacs    |    30 |
| Org      |     9 |
| Markdown |  1234 |

A centered column:

| Key | Value     |
|:---:|:---------:|
| a   | first     |
| bb  | second    |
| ccc | third row |

A borderless table is intentionally left as-is (v1 limitation):

Name | Role
---- | ----
Alice | Author
Bob | Reviewer
</content>
</invoke>
