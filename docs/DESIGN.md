# PerfUMate design

PerfUMate is a small API to look for bugs and performance problems in Pharo code starting
from a few example objects. It has no search algorithm of its own. It connects:

- Mate: object graph grammars (inference from examples, MCTS generation, derivation
  mutation, `validity` to break one rule),
- Ume: the guided campaign (runner, corpus, guides, MOpt scheduling of mutators, time budget),
- Shin: input minimization (delta debugging with an oracle that preserves the behavior).

PerfUMate only adds what is missing between them: a few mutators, a graph walker so Shin can
reduce object graphs, and the report. Things that should move upstream are listed in section 6.

## 1. API

```smalltalk
report := PerfUMate new
    examples: { order1. order2. order3 };                 "Mate infers the grammar"
    target: [ :order | Checkout new process: order ];     "or receiver: aCheckout selector: #process:"
    lookFor: #slowInputs;                                  "or #errors, or a UmeFeedbackGuide"
    budget: 5 minutes;
    run.

report open.
```

These five calls are enough. The rest is optional:

| Call | Default | Purpose |
| --- | --- | --- |
| `grammar` | inferred and widened | see the grammar before running (`grammar mateDefinition`) |
| `grammar:` | | replace it, with a `MateOGGrammar` or Mate source text (to tighten it) |
| `widen:` | `true` | turn off widening |
| `validity:` | `0.9` | share of generated graphs that respect every rule |
| `slowdown:` | `5` | a slow input must be at least this many times slower than the median |
| `instrument:` | from the target | packages whose coverage guides `#errors` |
| `seed:` | random | reproducible generation |
| `timeout:` | `2 seconds` | runs are stopped after this; a timeout counts as a slow input |

Results:

```smalltalk
report findings.        "PerfUMateFinding: kind, original, minimized, brokenRule, slowdown, signature"
report slowInputs.
report errors.
report grammar.         "the grammar used by the campaign"
report campaign.        "the UmeResult (plots, CSV export)"
report testSource.      "methods of an SUnit class reproducing every finding"
report generateTestsIn: #CheckoutFuzzTest package: 'MyShop-Tests'.
```

`generateTestsIn:package:` is what connects PerfUMate with CI: the minimized findings become
plain SUnit tests, committed with the project and run by its usual test job (section 7).

## 2. Mapping to Ume, Mate and Shin

| PerfUMate | Ume / Mate / Shin |
| --- | --- |
| `examples:` | `MateOGGrammar inferFrom: examples` (`MateGrammarInferrer`), then `PerfUMateGrammarWidener`. The root type is the class of the first example. |
| `grammar:` with text | `MateOGGrammar new addTypeDeclarations: (MateLanguageParser parse: text)` |
| `target:` | a `PerfUMateTarget` wraps the block; the Ume schema calls `PerfUMateTarget >> #runOn:`. `receiver:selector:` builds the block. |
| `run` | `UmeSchema` (receiver: the target, one argument: a `UmeCorpusGenerator`) and `UmeRunner test:for:` |
| corpus | `UmeCorpusGenerator` seeded with the examples, `UmeMOPTMutatorSelector`, 2 mutations per iteration |
| `#slowInputs` | `runner guidedByExecutionTime`, only the target instrumented |
| `#errors` | `PerfUMateCoverageAndErrorsGuide` (covered nodes and error messages in one table), coverage over the `instrument:` packages |
| a guide | any `UmeFeedbackGuide`, installed in the runner's `UmeFeedbackEvaluator` |
| confirmation | `PerfUMateTarget >> medianMicrosecondsOn:runs:` and `errorSignatureOn:` |
| minimization | `PerfUMateGraphShrinker`: walks the graph and runs Shin's `ShinDDminPaperShrinker` with a `ShinBooleanInputOracle` on each collection and string |
| broken rule | message of `grammar parse:` on the minimized graph |
| tests | STON of the minimized input, as in `UmeTest >> installUnitTestIn:` |

## 3. Defaults

They come from the Termo experiments (the Node/TypeScript port, `Termo/bench/mate`), where
Mate based fuzzing was compared with byte level fuzzing on about 40 parsers and libraries.

### 3.1 Inferred grammar, widened

Three examples overfit: ranges are the observed min and max, collections have the observed
sizes. `PerfUMateGrammarWidener` changes the inferred grammar in place:

- a numeric range grows by 10 times its span on each side, without crossing zero if the
  examples did not (negative values come from rule breaking, so they stay at 10% and the report
  can name the broken rule);
- collection sizes go up to `max(4 * maxSize, 16)`;
- invariants and references are kept.

The user can print `grammar mateDefinition`, edit it and pass it back with `grammar:`.

### 3.2 Validity 0.9

New graphs come from Mate's generator (MCTS, rewarded with Ume's feedback). 90% of them
respect every rule and 10% break exactly one (`MateViolationInjector`: range, oneOf, type, nil,
size, element, reference, invariant). Code tends to resist random garbage and to fail right
next to its assumptions.

### 3.3 Mutators chosen by MOpt

| Mutator | Change | Reason |
| --- | --- | --- |
| `PerfUMateGenerateMutator` | new graph, validity 0.9 | exploration away from the corpus |
| `PerfUMateDerivationMutator leastRewarded` | regenerate the least rewarded node | as `UmeOGGrammarDerivationMutator` |
| `PerfUMateDerivationMutator random` | regenerate a random node | diversity |
| `PerfUMateDerivationMutator breakingRule` | make the graph break one rule | almost valid objects |
| `PerfUMateRepeatMutator` | insert 2 to 64 copies of a run of 1 to 4 collection elements | structural slowness |
| `PerfUMatePrimitiveMutator` | change one string (cut, insert, replace a character) or one number (boundaries) | byte level bugs |

The repeat mutator made the biggest difference for performance bugs in Termo: the slowdowns of
cmark, cmark-gfm and sqlparse were found 4 to 10 times faster with it. Super-linear behavior
needs many copies of the same construct, and derivation mutation changes one node at a time
within the declared sizes. Neither Ume nor Mate had such a mutator, so it is here for now.

### 3.4 Guides

- `#slowInputs`: execution time (`UmeExecutionTimeGuide`, log buckets so noise is not
  rewarded). Only the target is instrumented to keep each run cheap.
- `#errors`: coverage and errors together. A new covered node or a new error message is
  progress. A Ume runner has a single guide, hence `PerfUMateCoverageAndErrorsGuide`.

Errors found while looking for slow inputs are reported as well.

### 3.5 Confirmation

Times measured during the campaign are noisy. The baseline is the median time of the examples
and of up to 20 new valid graphs. Slow candidates (the last records of the campaign) are re-timed
alone, median of 3 runs, and the two slowest are kept: the records of a campaign are usually the
same problem growing, and minimizing all of them splits the time between copies. A finding
needs a median of 5 runs at least `slowdown` times the baseline. Errors are run again and must
give the same signature: exception class and first method of the code under test on the stack
(not `Object>>errorSubscriptBounds:`).

### 3.6 Minimization

`PerfUMateGraphShrinker` repeats, until nothing changes or the deadline passes:

1. walk the graph breadth first (by identity, cycles are fine);
2. reduce each collection with Shin's ddmin over its elements (empty first);
3. reduce each string with ddmin over its characters;
4. replace each number by 0, then 1 or -1, then halves toward 0.

The oracle checks the behavior:

- errors: same signature;
- slow inputs: still at least 2 x `slowdown` times the baseline (median of 3 runs), so the
  result does not sit on the threshold where noise decides. If the minimized input is not slow
  when measured again (median of 5), the original input is reported;
- if the original graph respected the grammar, the candidate must too, so minimization does
  not add a broken rule.

Candidates run on a `veryDeepCopy`, so a target that modifies its argument does not affect
the shrinker.

### 3.7 Budget

`budget:` is the total time. The campaign gets 80% of it (minus the baseline, at most 10%),
confirmation and minimization share the rest, with one deadline per finding. A finding whose
minimization did not finish is still reported, marked as not fully minimized.

## 4. Pitfalls seen in Termo

- Re-validating the whole graph at each mutation. `UmeOGGrammarDerivationMutator` calls
  `grammar parse:` on a `veryDeepCopy` for every mutation. In Termo this made Mate mutation run
  10 to 100 times fewer inputs per second than byte mutation. Here every input is a
  `PerfUMateInput` (graph and key) and `PerfUMateSearchSpace` maps the key to the derivation
  that built it. Chained mutations reuse the tree; `grammar parse:` only runs when the key is
  unknown (examples, inputs changed by the repeat or primitive mutators). The target gets a copy
  of the graph, never the derivation's own instance.
- Mate alone misses almost valid inputs (a truncated string in a field, a number one past a
  bound). Derivation mutation regenerates whole values and rarely turns `'VIP10'` into `'VI'`.
  `PerfUMatePrimitiveMutator` covers that.
- Mate is slow per input. Sizes stay bounded (widened, not open), the repeat mutator stops at
  1024 elements per collection, and there are 2 mutations per iteration.
- Invalid graphs cannot be parsed. Inputs grown by the repeat mutator break size rules, so only
  the repeat and primitive mutators apply to them (see `checkSizes:` below).
- Timing is noisy: log buckets during the search, medians and runs in isolation afterwards.
- Pharo 13 has no `Time microsecondsToRun:`; `PerfUMateTarget class >> microsecondsToRun:`
  uses `Time microsecondClockValue`.

## 5. Packages

```
BaselineOfPerfUMate/   Ume, Mate and Shin from GitHub
PerfUMate/
  PerfUMate                     configuration and run
  PerfUMateCampaign             baseline, Ume campaign, confirmation, minimization
  PerfUMateTarget               code under test: runs, timing, timeouts, errors
  PerfUMateInput                graph and derivation key (what the corpus holds)
  PerfUMateSearchSpace          grammar, validity, derivation cache
  PerfUMateErrorSignature, PerfUMateTimeout
  PerfUMateGrammarWidener
  PerfUMateMutator and subclasses (generate, derivation, repeat, primitive)
  PerfUMateGraphWalker, PerfUMateSlot
  PerfUMateCoverageAndErrorsGuide
  PerfUMateGraphShrinker
  PerfUMateFinding, PerfUMateReport, PerfUMateGeneratedTest
PerfUMate-Tests/
  PerfUMateExampleOrder, Item, Checkout, PerfUMateExamples   small domain, one slow path, one crash
  PerfUMateTest        whole flow: slow inputs, errors
  PerfUMatePartsTest   mutators, walker, shrinker, widener, timeouts, derivation cache
```

## 6. Proposed upstream changes

PerfUMate works around these for now.

Mate
1. Merge `confidence-generation` into `main`. `validity` (`gen:from:validity:violating:`,
   `MateViolationInjector`, `violations`) is only on that branch. PerfUMate checks with
   `respondsTo:` and uses validity 1 without it. The baseline loads Mate `main`, as Ume does.
2. `parse: object checkSizes: false` (as in Termo), so graphs grown by the repeat mutator can
   still be mutated by derivation.
3. Copying a derivation subtree without copying the grammar, so a corpus entry can be mutated
   several times without re-parsing (today a cached tree is used by one child only).
4. A repeat operation on `MateInstArrayVarDecl` nodes.

Ume
1. `UmeFeedbackEvaluator >> guide:` and `UmeRunner >> guidedBy:` (today: `instVarNamed:`).
2. A composite guide.
3. Error class and signaling method in `UmeEvalError` (today: message and 10 frames), so
   grouping errors does not need a re-run.
4. `UmeOGGrammarDerivationMutator` keeping the derivation with the case.
5. Repeat and primitive mutators for object graphs.
6. Running all campaigns of a package headless (section 7).

Shin
1. An object graph shrinker, so PerfUMate's walker is not needed.
2. `ShinExecutionTimeOracle` measures one run (`1 timesCollect:`); a median would make it
   usable for slow inputs.

## 7. Nightly CI (next)

Goal: short campaigns every night on several Pharo projects, with findings turned into tests.
Already there: `generateTestsIn:package:` and `testSource` (inputs as STON, the target as code
when the block does not use its context), and a report without UI dependencies except `open`.

To do:

1. Campaigns declared in code: class side methods with a `<perfumate>` pragma answering a
   configured `PerfUMate`.
2. A headless entry point, e.g. `PerfUMate runCampaignsIn: 'MyShop' budget: 10 minutes into: 'perfumate-out'`,
   writing a markdown summary and the generated test classes in Tonel, and exiting with an
   error on new findings.
3. A scheduled GitHub workflow (`cron: '0 3 * * *'`) with `hpi-swa/setup-smalltalkCI`: load the
   project and PerfUMate, run the entry point, upload `perfumate-out`, and open a pull request
   with the generated tests (or an issue with the summary).
4. Findings keyed by kind, error class and method, so a known bug is not reported every night.
