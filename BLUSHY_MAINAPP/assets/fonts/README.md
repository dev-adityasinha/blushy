# Bundled fonts

The app asked for `Georgia`, `Courier` and `Ada Hybrid` and shipped none of
them. On Android none of the three exist, so every one fell back to Roboto and
the editorial serif the layouts were built around was silently lost.

`Georgia` and `Courier` are also not redistributable — they are Microsoft and
Adobe faces — so they could not simply be added. These two are open-licensed
replacements chosen for metric compatibility, which means the same text occupies
the same space and no layout had to be re-tuned:

| asked for | shipped | why |
|---|---|---|
| Georgia | **Gelasio** | designed as a metric-compatible Georgia substitute |
| Courier | **Courier Prime** | a free Courier with the same fixed advance width |

Both are under the SIL Open Font License 1.1 (`OFL.txt`), which permits
bundling in an application and requires the licence to travel with them.

Weights are limited to the ones actually used: regular, bold and italic for
Gelasio; regular and bold for Courier Prime. Each file was checked against its
own `name` table after download — the first attempt had regular and italic
swapped, which nothing but that check would have caught until someone noticed
slanted body text.

`Ada Hybrid`, the wordmark face, is **not** here. It could not be identified
from anything in this repository, and guessing at a brand mark is worse than
leaving it to fall back.
