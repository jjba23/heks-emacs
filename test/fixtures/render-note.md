# Render note

A note written to pin down what the Markdown renderer produces.  It has
**strong** and *emphasised* text, a `code span`, a
[link](https://example.com/docs), an autolink <https://example.com/>, and
~~text that was struck through~~.

## Lists

- first
- second
  - nested
- [ ] a task that is not done
- [x] a task that is done

1. one
2. two

## A table

| Name | Count | Note |
|:-----|------:|:----:|
| alpha | 1 | left |
| beta | 22 | right |

## Quoting and breaking

> Quoted *text* with a [link](https://example.com/q).

A line ending in two spaces  
carries on after the break.

A setext heading
================

And then a rule:

---

```elisp
(setq x "<not markup>")
```

<div>a raw block</div>
