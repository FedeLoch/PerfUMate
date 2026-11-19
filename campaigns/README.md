# Campaigns

The Pharo campaigns first run from the Termo hunt with Ume, Mate and Shin wired by hand, written
again with PerfUMate. Each page shows the original setup, the PerfUMate version, and what a run
found.

One file per library:

| Library | Campaigns | Termo campaigns | Bugs reproduced | Page |
| --- | --- | --- | --- | --- |
| STON | round trip | `graphston` | Bag holding an Association | [ston.md](ston.md) |
| Fuel | round trip | `graphfuel` | Set holding a Set | [fuel.md](fuel.md) |
| Collections | copying, equality and hash, hashed collections (performance) | `graphcopy`, `graphequal`, `hash-ints` | `deepCopy` of IdentitySet; Interval/Array, Set/IdentitySet, ByteArray/String | [collections.md](collections.md) |
| Kernel | printing and storeString | `graphprint` | Association with a binary-selector key; non-ASCII symbols | [kernel.md](kernel.md) |

Each campaign ran 3 minutes on Pharo 13.1 (seed 1). Together they reproduced 8 of the 11 bugs
of hunt 2. Not reproduced: the self-referencing LinkedList in STON (needs a cycle, which Mate does
not generate), the Point with y = -0.0 (generated, but hidden by an artifact in the same inputs, see
[kernel.md](kernel.md)), and NaN dictionary keys (the examples hold no dictionaries). The hashed
collections campaign is, as in the Termo hunt, a negative control: linear.

## Running them

The campaigns are in the `PerfUMate-Campaigns` package (`campaigns` group of the baseline):

```smalltalk
Metacello new
    baseline: 'PerfUMate';
    repository: 'github://FedeLoch/PerfUMate:main';
    onConflictUseIncoming;
    load: 'campaigns'.

report := PerfUMateCampaigns ston budget: 3 minutes; run.
report open.
```

`PerfUMateCampaigns` has one class-side method per campaign (`ston`, `fuel`, `copying`,
`equality`, `printing`, `hashing`), each answering a configured `PerfUMate`.

## What changes from the Termo version

| | Termo hunt (Ume + Mate + Shin) | PerfUMate |
| --- | --- | --- |
| Inputs | Mate generates recipes (`TermoRecipe`); `TermoGraphBuilder` builds them into objects | Mate infers a grammar from real example graphs (`PerfUMateGraphExamples boxes`) and generates objects directly |
| Code per campaign | a campaign class, the recipe and builder classes, a runner script | one method answering a `PerfUMate`, plus the check |
| Mutators | `TermoSafeOGMutator` (derivation mutation) | six mutators chosen by MOpt, including repeat and primitive values |
| Guidance | one run per guide (coverage, time, method calls) | `#errors` (coverage and new errors at once), or `#slowInputs` |
| Oracle | `TermoBrokenInvariant` raised by the check | `PerfUMateBrokenInvariant`, whose label is part of the finding's signature |
| Confirmation and minimization | replayed and narrowed down by hand, ddmin where useful | every finding re-run alone and minimized with Shin automatically |
| Output | a JSON of findings, triaged by hand into reports | a report with minimized inputs, charts and generated SUnit tests |

What PerfUMate cannot do that the recipes did: Mate generates trees, so graphs have no shared
references or cycles, and objects are built by setting instance variables, not through their
public API. Bugs that need a cycle (STON reading a self-referencing LinkedList) are out of reach,
and an object can be built in a state its API forbids (a Fraction with denominator 0).
