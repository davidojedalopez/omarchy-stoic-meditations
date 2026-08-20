# Corpus sources and policy

`data/meditations.json` is generated from three Standard Ebooks editions. Each
upstream revision is pinned so the checked-in corpus is reproducible and does
not change because an upstream branch moves.

| Source | Translator | Pinned Standard Ebooks repository revision | Edition |
|---|---|---|---|
| Marcus Aurelius, *Meditations* | George Long | [`419c4faaa7a83b2a37988f1a516c84afefde579c`](https://github.com/standardebooks/marcus-aurelius_meditations_george-long/tree/419c4faaa7a83b2a37988f1a516c84afefde579c) | [Standard Ebooks](https://standardebooks.org/ebooks/marcus-aurelius/meditations/george-long) |
| Epictetus, *The Enchiridion* | George Long | [`8c154d40a6f85e32a5711001a28c1b55ab56d3c8`](https://github.com/standardebooks/epictetus_short-works_george-long/tree/8c154d40a6f85e32a5711001a28c1b55ab56d3c8) | [Standard Ebooks](https://standardebooks.org/ebooks/epictetus/short-works/george-long) |
| Epictetus, *Discourses* | George Long | [`218406b563346743af3ece4a22723a245b0ccb22`](https://github.com/standardebooks/epictetus_discourses_george-long/tree/218406b563346743af3ece4a22723a245b0ccb22) | [Standard Ebooks](https://standardebooks.org/ebooks/epictetus/discourses/george-long) |

## Selection policy

The generator makes these mechanical transformations only:

1. Read the authored paragraphs or Enchiridion sections in edition order.
2. Remove endnote-reference markers while keeping the surrounding text.
3. Normalize markup whitespace to plain text.
4. Exclude units over 1,200 Unicode characters; never shorten them.
5. Exclude location colophons and markup fragments that begin mid-sentence or
   end by introducing omitted material.
6. Interleave eligible units proportionally, preserving order within each
   source and placing every entry exactly once in a complete schedule cycle.

This favors short readings while preserving the translator's words. It is not
an editorial ranking, modernization, summary, or claim that the extracted
paragraphs were titled “daily meditations” by their authors.

Seneca is intentionally not in the first corpus: the public-domain edition
reviewed during planning is organized mainly as passages much longer than the
plugin's reading limit. It can be added later only with a transparent unit rule
that does not truncate or silently rewrite the text.

## Rights

Each pinned repository's `LICENSE.md` states that its source text and artwork
are believed to be in the public domain in the United States, and that Standard
Ebooks contributors dedicate their contributions to the public domain under
CC0. The same notice is available in the repositories linked above.

Public-domain status can differ by country. Distributors and users should
check the rules that apply in their jurisdiction. Standard Ebooks is the
edition source; this plugin is independent and is not affiliated with or
endorsed by Standard Ebooks.
