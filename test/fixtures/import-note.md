---
title: A note about importing notes
tags:
  - emacs
  - org mode
aliases: [Importing, The one-way door]
author: Josep
permalink: /notes/importing
---

# A note about importing notes

A document other tools read is Markdown; a note one *works* in is Org.
This one is written to be read either way: it has a **title** in its front
matter, *emphasis* and some `code` in its prose, and a [link](guide.md)
next to a picture ![diagram](images/import.png).

## What it keeps

- the headings, as the outline they are
- the lists, at the depth they are written at
  - nesting included
- [ ] the task lists, as checkboxes
- [x] and the ones that are done

1. ordered lists keep their numbers
2. and their order

> A quote is quoted, and *styled* as one.

A fenced block is a source block, and what is in it is not markup:

```scheme
(define (greet name)
  ;; * this is not a headline
  (string-append "hello, " name))
```

A fence with no language is an example block:

```
$ make check
```

| What | Where |
|:-----|------:|
| the title | `#+title:` |
| the tags | `#+filetags:` |

The lines of a paragraph stay the lines they were, and a hard break  
ends one line while the paragraph goes on.[^why]

[^why]: Because Org reads them back as one paragraph, so nothing is lost.

---

A raw block is passed through, since a badge is HTML an import does not
improve on:

<details><summary>A badge</summary>and its detail</details>
