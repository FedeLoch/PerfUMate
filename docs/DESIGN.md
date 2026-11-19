# PerfUMate — Design

PerfUMate is one small API for finding bugs and performance problems in Pharo code from a
handful of example objects. It owns no search algorithm: it wires together

- **Mate**: object-graph grammars (inference from examples, MCTS generation, derivation
  mutation, `validity` to break exactly one rule),
- **Ume**: the guided campaign (runner, corpus, guides, MOpt mutator scheduling, time budget),
- **Shin**: input minimization (delta debugging with behavior-preserving oracles),

and adds only what is missing between them (a few mutators, a graph walker for Shin, the
report). Anything that belongs upstream is listed in [Proposed upstream changes](#proposed-upstream-changes).

## 1. The API

```smalltalk
report := PerfUMate new
    examples: { order1. order2. order3 };                 "Mate infers the grammar"
    target: [ :order | Checkout new process: order ];     "or receiver: aCheckout selector: #process:"
    lookFor: #slowInputs;                                  "or #errors, or a UmeFeedbackGuide"
    budget: 5 minutes;
    run.

report open.          "findings, each minimized, with a reproducing SUnit test"
```

Five calls is the whole contract. Everything else has a default and is optional:

| Optional call | Default | Purpose |
| --- | --- | --- |
| `grammar` | inferred + widened | See the grammar before running (`perfumate grammar mateDefinition`). |
| `grammar:` | — | Replace it: a `MateOGGrammar` or Mate source text. This is how the user tightens an overfitted grammar. |
| `widen:` | `true` | Turn off widening of the inferred grammar. |
| `validity:` | `0.9` | Share of generated graphs that satisfy every rule. |
| `slowdown:` | `5` | A slow input must be at least N× slower than the median input. |
| `instrument:` | derived from the target | Packages (names) whose coverage guides `#errors`. |
| `seed:` | random | Reproducible generation (Mate's single random source). |

Results:

```smalltalk
report findings.             "PerfUMateFinding: kind, input, minimized, brokenRule, slowdown, error"
report slowInputs.  report errors.
report grammar.              "the grammar the campaign used"
report campaign.             "the underlying UmeResult, for plots and CSV export"
report testSource.           "source of an SUnit class reproducing every finding"
report generateTestsIn: #CheckoutFuzzTest package: 'MyShop-Tests'.   "compile it"
report open.
```

The report is the user's object. `generateTestsIn:package:` is the bridge to CI: the
minimized findings become ordinary SUnit tests that are committed and run by the project's
regular test job (see [§7](#7-nightly-ci-next-step)).

## 2. What each call maps to

| PerfUMate | Ume / Mate / Shin |
| --- | --- |
| `examples:` | `MateOGGrammar inferFrom: examples` (`MateGrammarInferrer`), then `PerfUMateGrammarWidener`. Root type = class of the first example. |
| `grammar:` text | `MateOGGrammar new addTypeDeclarations: (MateLanguageParser parse: text)` |
| `target:` | A `PerfUMateTarget` wraps the block; the Ume schema calls `PerfUMateTarget >> #runOn:`. `receiver:selector:` builds the block. |
| `run` | `UmeSchema` (receiver = the target, one argument = a `UmeCorpusGenerator`) + `UmeRunner test:for:` with `UmeTimeCriteria`. |
| corpus | `UmeCorpusGenerator` seeded with the examples, `mutatorSelector: UmeMOPTMutatorSelector new`, `mutationsPerIteration: 1..3`. |
| `lookFor: #slowInputs` | `runner guidedByExecutionTime`, only the target instrumented (low cost). |
| `lookFor: #errors` | `PerfUMateCoverageAndErrorsGuide` (coverage table + error table in one guide), execution-time profiling, coverage over `instrument:` packages. |
| `lookFor: aGuide` | Any `UmeFeedbackGuide` instance, installed in the runner's `UmeFeedbackEvaluator`. |
| confirmation | PerfUMate re-runs candidates on their own (`PerfUMateTarget >> timeOn:`). |
| minimization | `PerfUMateGraphShrinker` walks the graph and calls Shin's `ShinDDminPaperShrinker` with a `ShinBooleanInputOracle` on each collection and string. |
| broken rule | `MateDerivationNode violations` when the graph was generated with `validity`, else the message of `grammar parse:` on the minimized graph. |
| test | STON of the minimized input, like `UmeTest >> installUnitTestIn:`. |

## 3. Defaults and why

They come from the measurements made with Termo (the Node/TypeScript port of the same
architecture, `Termo/bench/mate`), where Mate-based fuzzing was compared with byte-level
fuzzing on ~40 real parsers and libraries.

### 3.1 Grammar: infer, then widen, then let the user tighten

Three examples overfit: inferred ranges are the observed min..max, collections are the
observed sizes, enumerations are the observed values. PerfUMate widens the inferred grammar
(`PerfUMateGrammarWidener`):

- numeric `between:and:` ranges grow by 10× their span on each side, **without crossing
  zero** when the examples never did (going below zero is the job of rule breaking, so it
  stays a deliberate 10%, and the report can say "broke `quantity > 0`");
- collection sizes become `minSize .. max(4 × maxSize, 16)`;
- invariants and `selfReferences` are kept (they are structure, not range).

`perfumate grammar mateDefinition` prints the result; `grammar:` with edited text replaces it.

### 3.2 Generation with validity 0.9

New graphs come from Mate's generator (MCTS over the grammar, rewarded by Ume's feedback).
90% of them satisfy every rule; 10% break exactly one (`MateViolationInjector`: range, oneOf,
type, nil, size, element, reference, invariant). Code is usually robust to random garbage and
fragile right next to its assumptions.

### 3.3 Mutators, scheduled by MOpt

`UmeMOPTMutatorSelector` chooses among:

| Mutator | What it does | Why |
| --- | --- | --- |
| `PerfUMateGenerateMutator` | a fresh graph, validity 0.9 | keeps exploring away from the corpus |
| `PerfUMateDerivationMutator leastRewarded` | regenerate the least rewarded node | Ume's derivation mutation (`UmeOGGrammarDerivationMutator`) |
| `PerfUMateDerivationMutator random` | regenerate a random node | diversity |
| `PerfUMateDerivationMutator breakingRule` | regenerate a node with validity 0 | "almost valid" objects |
| `PerfUMateRepeatMutator` | copy a run of 1–4 collection elements 2–64 times | structural slowness |
| `PerfUMatePrimitiveMutator` | edit one string (truncate, cut, insert, flip a character) or one number (boundary values) inside the graph | byte-level bugs |

**Repeat was decisive for performance bugs.** In Termo, cmark, cmark-gfm and sqlparse
slowdowns were found 4–10× faster with it: super-linear behavior needs *many* copies of one
construct, and derivation mutation changes one node at a time within the declared sizes.
Neither Ume nor Mate had it, so it lives here (and is proposed upstream).

### 3.4 Guide by intent

- `#slowInputs` → execution time (Ume's `UmeExecutionTimeGuide`, log buckets, so noise is not
  rewarded). Only the target is instrumented, keeping the per-input cost low.
- `#errors` → coverage and errors at once: a new error message *or* new coverage is progress.
  Ume has one guide per runner, so PerfUMate adds `PerfUMateCoverageAndErrorsGuide`.

Errors found while looking for slow inputs (and vice versa) are reported too: they are free.

### 3.5 Confirm before reporting

Timing during the campaign is noisy (instrumentation, GC, other cases). A slow candidate is
re-timed alone: GC, then the median of 5 runs, against the median of the examples plus 20
fresh valid graphs (the baseline). It is reported only if the ratio is at least `slowdown`.
An error is re-run too and must raise the same error class at the same method.

### 3.6 Minimize with Shin, preserving the behavior

Each confirmed finding is minimized by `PerfUMateGraphShrinker`:

1. walk the graph breadth-first (identity set, so cycles terminate);
2. for every collection: Shin's ddmin over its elements;
3. for every string: Shin's ddmin over its characters;
4. for every number: try 0, 1, -1, then halve toward 0;
5. repeat until nothing shrinks or the deadline passes.

The oracle is the behavior, not the size:

- error: same exception class, same signaling method;
- slow: still at least `slowdown`× slower than the baseline median (median of 3 runs);
- and if the original graph satisfied the grammar, the candidate must too, so minimization
  does not introduce a second broken rule.

Each candidate runs on a `veryDeepCopy`, so a target that mutates its argument cannot corrupt
the shrinker's state.

The report shows the minimized input (STON), the broken rule if any, the slowdown ratio,
the error and its location, and a generated SUnit test method.

### 3.7 Budget

`budget:` is the whole wall-clock time. The campaign gets 80% of it; confirmation and
minimization share the rest, each finding with its own deadline. A finding whose
minimization ran out of time is still reported, with `isMinimized` false.

## 4. Known pitfalls (from Termo)

- **Re-validating the whole graph on every mutation.** Ume's `UmeOGGrammarDerivationMutator`
  calls `grammar parse:` on a `veryDeepCopy` for every mutation; in Termo, Mate mutation ran
  10–100× fewer inputs per second than byte mutation for that reason. PerfUMate keeps the
  derivation tree next to the object: every input is a `PerfUMateInput` (graph + key) and a
  `PerfUMateDerivationCache` maps the key to the derivation that built it. Stacked mutations
  reuse the same tree without parsing; `grammar parse:` runs only on a cache miss (examples,
  and inputs the repeat/primitive mutators changed). The graph handed to the target is a
  snapshot, never the derivation's own instance, so a target that mutates its argument
  cannot desynchronize the tree.
- **Mate alone misses "almost valid" bugs** (a truncated string inside a field, a number one
  past a boundary). Derivation mutation regenerates whole values; it rarely produces
  `'VI'` from `'VIP10'`. Hence `PerfUMatePrimitiveMutator`, scheduled by MOpt like the others.
- **Mate is slow per input.** Generation and derivation mutation cost far more than flipping a
  byte. Bound graph sizes (widened, not unbounded), cap the repeat mutator at 4096 elements per
  collection, and keep `mutationsPerIteration` small (1–3).
- **Invalid graphs cannot be parsed.** Inputs from the repeat mutator break size rules on
  purpose; Mate's parser rejects them, so derivation mutators fall back to the primitive and
  repeat mutators for those inputs (see the proposed `checkSizes:` below).
- **Timing is noisy.** Guide with log buckets, confirm alone, compare medians.

## 5. Package layout

```
BaselineOfPerfUMate/        loads Ume, Mate, Shin from GitHub
PerfUMate/
  PerfUMate                 the facade (builder + run)
  PerfUMateTarget           block wrapper the Ume schema calls
  PerfUMateInput            graph + derivation key (what the corpus holds)
  PerfUMateDerivationCache  key -> Mate derivation
  PerfUMateGrammarWidener
  PerfUMateGenerateMutator, PerfUMateDerivationMutator,
  PerfUMateRepeatMutator, PerfUMatePrimitiveMutator   (UmeMutator subclasses)
  PerfUMateGraphWalker      slots of a graph (collections, strings, numbers)
  PerfUMateCoverageAndErrorsGuide   (UmeFeedbackGuide subclass)
  PerfUMateGraphShrinker    drives Shin per slot
  PerfUMateFinding, PerfUMateReport
PerfUMate-Tests/
  PerfUMateExampleOrder/Item/Checkout   a tiny domain with one slow path and one crash
  PerfUMateTest              the whole flow: one slow-input case, one error case
  PerfUMateMutatorsTest, PerfUMateGrammarWidenerTest, PerfUMateGraphShrinkerTest
```

## 6. Proposed upstream changes

PerfUMate works around these today; each would let it delete code.

**Mate**
1. Merge `confidence-generation` into `main`. `validity` (`gen:from:validity:violating:`,
   `MateViolationInjector`, `violations` on derivations) exists only on that branch.
   PerfUMate detects it with `respondsTo:` and falls back to validity 1 without it; the
   baseline loads Mate `main` because Ume's baseline does too.
2. `parse: object checkSizes: false` (as in Termo): validate a graph ignoring collection
   sizes, so inputs grown by the repeat mutator can still be derivation-mutated.
3. A public way to copy a derivation subtree without copying the grammar, so a corpus entry's
   tree can be mutated without being consumed (today the cache hands a tree to one child).
4. A repeat operation on `MateInstArrayVarDecl` nodes (duplicate a run of children), the
   derivation-level version of `PerfUMateRepeatMutator`.

**Ume**
1. `UmeFeedbackEvaluator >> guide:` and `UmeRunner >> guidedBy: aGuide`, so custom guides do
   not need `instVarNamed:`.
2. A composite guide (`UmeCompositeGuide with: { coverage. errors }`).
3. Keep the error class and the signaling method in `UmeEvalError` (today: message and a
   10-frame stack), so grouping does not need a re-run.
4. `UmeOGGrammarDerivationMutator`: keep the derivation with the case instead of
   `grammar parse: objectGraph veryDeepCopy` on every mutation.
5. A repeat mutator and a primitive (in-graph string/number) mutator for object graphs.
6. A `PerfUMate`-style entry point for running all campaigns of a package headless (see §7).

**Shin**
1. An object-graph shrinker (`ShinObjectGraphShrinker`): today Shin's flat shrinkers work
   on sequences and its tree shrinkers on parsed strings; PerfUMate's walker is the glue.
2. `ShinExecutionTimeOracle` runs once (`1 timesCollect:`); a median of N runs would make it
   usable directly for slow-input minimization.

## 7. Nightly CI (next step)

The goal: small fuzzing campaigns running every night on several Pharo projects, turning
findings into tests. The pieces already designed for it:

- `report generateTestsIn:package:` and `report testSource` give a self-contained SUnit
  class (inputs as STON, the target as code when it is a clean block or a receiver/selector).
- The report has no UI dependency except `open`.

What remains (not implemented yet):

1. **Declared campaigns.** Class-side methods tagged `<perfumate>` that answer a configured
   `PerfUMate` (no `budget:`), so a project lists its campaigns in code.
2. **Headless runner.** `PerfUMate runCampaignsIn: 'MyShop' budget: 10 minutes into: 'perfumate-out'`
   splits the budget, runs each campaign, writes `report.md` (findings, slowdowns, broken
   rules) and the generated test classes in Tonel, and exits non-zero on new findings.
3. **GitHub Action.** A scheduled workflow (`on: schedule: - cron: '0 3 * * *'`) using
   `hpi-swa/setup-smalltalkCI`, loading the project and PerfUMate, running the headless
   runner, uploading `perfumate-out` as an artifact and, on new findings, opening a pull
   request with the generated tests (or an issue with `report.md`).
4. **Deduplication across nights.** Findings keyed by (kind, error class, method) so a known
   bug does not reopen every night; the committed generated tests are the record.
