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

## What a document has since

A [reference link][ref] and a reference image ![a diagram][ref-image], an
escaped \*asterisk\*, a ==highlighted phrase==, an emoji :rocket:, and a
formula $E = mc^2$ that stays readable without a network.

[ref]: https://example.com/reference "The reference"
[ref-image]: images/reference.png "A diagram"

> [!WARNING]
> A callout is a quote that says what kind of quote it is.

A note at the end of a sentence[^render] is a footnote, and it is answered
where the definitions are.

[^render]: A footnote is rendered where it is referred to, and answered at
    the end of the document.
