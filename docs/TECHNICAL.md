# How PerfUMate works

This document goes through each part of a campaign, what it does, where it comes from (Ume, Mate,
Shin or PerfUMate itself) and how to configure it. The order follows a run:

1. grammar: inferred from the examples by Mate, widened, optionally edited;
2. baseline: median time of typical inputs;
3. search: a Ume campaign over a corpus of object graphs, mutated by grammar based and object
   level mutators chosen by MOpt, guided by a feedback measure;
4. confirmation: candidates run again alone;
5. minimization: Shin reduces each finding while the behavior holds;
6. report and tests.

All the options below are messages to `PerfUMate` before `run`, unless said otherwise.

## 1. Grammar based inputs

### Inference

`examples:` gives Mate a few objects. `MateGrammarInferrer` walks them by identity and writes
one rule per class:

| Observed | Inferred |
| --- | --- |
| classes held by a field | a union of them (`Mage \| Rogue \| Warrior`) |
| a field that is sometimes `nil` | nullable (`T?`) |
| numbers | a range with enough observations, otherwise only the sign (`atLeast: 1`) |
| few distinct symbols or strings seen often | `oneOf:` |
| collections | element types, collection class, size range |
| objects pointing back (`children` / `parent`) | `selfReferences` paths |
| fields always ordered (`low <= high`) | invariants |

The root type is the class of the first example. `perfumate grammar mateDefinition` prints the
result.

### Widening

A few examples overfit: ranges and sizes are exactly what the examples had. With `widen: true`
(default), `PerfUMateGrammarWidener` rewrites them:

- numeric ranges grow by 10 times their span on each side, without crossing zero if the examples
  did not;
- collections accept up to `max(4 * maxSize, 16)` elements.

### Editing

`grammar:` takes a `MateOGGrammar` or Mate source text. The usual flow is to print the inferred
grammar, change what the examples got wrong, and pass it back:

```smalltalk
source := perfumate grammar mateDefinition.
"edit: quantity between 1 and 100, names from a fixed set, up to 200 items"
perfumate grammar: editedSource.
```

See the [Mate language reference](https://github.com/FedeLoch/Mate#mate-language-reference)
for the syntax (`between:and:`, `oneOf:`, `sizeBetween:and:`, `?`, invariants, aliases).

### Validity

`validity:` (default `0.9`) is the share of generated graphs that respect every rule. The rest
break exactly one rule, chosen among `range`, `oneOf`, `type`, `nil`, `size`, `element`,
`reference` and `invariant` (Mate's `MateViolationInjector`). Code usually fails right next to
its assumptions, so one broken rule finds more than random objects do. This needs a Mate with
`validity` (the `confidence-generation` branch); without it every generated graph is valid.

## 2. Weighted grammars

Mate's generator is a Monte Carlo tree search over the grammar. Each declaration keeps, per
context (the path from the root and the depth), a number of visits and a reward:

- every time an input is evaluated, Ume's improvement for it is backpropagated through the
  derivation tree that built it (`grammar backpropagate: derivation improvement: n`), adding
  `n` to the reward of every node of the tree;
- when a field has a union type, the option is chosen with UCB1:
  `reward / visits + c * sqrt(ln(totalVisits) / visits)`, with `c = 2`.

The grammar becomes weighted toward the choices that produced slow inputs or new coverage,
while still trying the others. PerfUMate keeps the derivation of each generated input
(`PerfUMateSearchSpace`) so that rewards reach the right tree without parsing the graph again.

The generator can be tuned through the grammar:

```smalltalk
perfumate grammar generator
    maxDerivationHeight: 8;   "default 12: how deep objects nest"
    nilProbability: 0.2.      "default 0.1: how often nullable fields are nil"
perfumate seed: 42.           "reproducible generation"
```

## 3. The corpus

The search is a `UmeCorpusGenerator`:

1. the examples are the seeds, run first;
2. then, at each step, one input is picked from the corpus, a mutator is chosen, and the mutator
   is applied `mutationsPerIteration` times (default 2);
3. the result is run; if its feedback is positive (it improved some measure), it joins the corpus.

How the input is picked is the corpus heuristic:

| Heuristic | Picks |
| --- | --- |
| `UmeRandomSelectorHeuristic` (default) | any input of the corpus |
| `UmeTournamentSelectorHeuristic` | the best of a few random inputs |
| `UmePickBestElementDifferenceHeuristic` | the input holding the record of a random measure key |

```smalltalk
perfumate
    corpusHeuristic: UmeTournamentSelectorHeuristic new;
    mutationsPerIteration: 1.
```

## 4. Mutators

The default set (`PerfUMateSearchSpace >> defaultMutators`):

| Mutator | Level | What it does |
| --- | --- | --- |
| `PerfUMateGenerateMutator` | grammar | a new graph from the grammar, with the campaign's validity |
| `PerfUMateDerivationMutator leastRewarded` | grammar | regenerates the node of the derivation with the lowest reward |
| `PerfUMateDerivationMutator random` | grammar | regenerates a random node |
| `PerfUMateDerivationMutator breakingRule` | grammar | makes the graph break one rule |
| `PerfUMateRepeatMutator` | object | inserts 2 to 64 copies of a run of 1 to 4 elements of a collection |
| `PerfUMatePrimitiveMutator` | object | changes one string (cut, insert, replace characters) or one number (boundaries, neighbours) |

Grammar mutators work on the derivation tree, so their results respect the grammar (or break one
rule on purpose). Object mutators work on the graph directly: they find what grammar mutators
cannot, such as long runs of the same element (super-linear loops) or almost valid strings. Their
results are parsed again when a grammar mutator picks them later; graphs that no longer parse are
only changed by object mutators.

`maxElements:` (default 1024) caps how far the repeat mutator grows a collection.

To change the set, give a block that receives the search space:

```smalltalk
perfumate mutators: [ :space |
    space defaultMutators , { MyMutator on: space } ].
```

A mutator subclasses `PerfUMateMutator` and implements `mutateInput:`, which receives a
`PerfUMateInput` and answers a new one (`space inputForGraph: aGraph`). Errors inside a mutation
are caught: the input is answered unchanged.

## 5. Mutator selection (MOpt)

Which mutator runs at each step is decided by `mutatorSelector:`. The default is
`UmeMOPTMutatorSelector`, Ume's implementation of
[MOpt](https://www.usenix.org/conference/usenixsecurity19/presentation/lyu):

- each mutator has a selection probability; 10 swarms of particles explore probability vectors;
- pilot phase: each swarm makes 100 selections, and a swarm's fitness is how many of its
  selections produced positive feedback;
- core phase: the best swarm makes 1000 selections;
- every 100 selections, particles move toward their own best and the global best vectors
  (particle swarm optimization, inertia 0.72), with probabilities kept between 0.001 and 0.998.

The effect is that the campaign learns which mutators pay off for this benchmark: repeat for
super-linear loops, primitive mutations for parsers of strings, derivation mutations for
structural bugs. Other selectors:

| Selector | Chooses |
| --- | --- |
| `UmeMOPTMutatorSelector` (default) | MOpt, as above |
| `UmeWeightedMutatorSelector` | proportionally to a weight, +1 for each positive feedback, -1 otherwise |
| `UmeRandomMutatorSelector` | uniformly |

```smalltalk
perfumate mutatorSelector: UmeWeightedMutatorSelector new.
```

## 6. Feedback

After each run, a guide turns the case into a table of values, and Ume's feedback evaluator
compares it with the best values seen so far:

- each key of the table is an objective (a method, a covered node, an error message, the
  execution time);
- values are grouped into logarithmic buckets (`ln` rounded), so 101 microseconds is not
  news after 100, but 10 times more is;
- the improvement of a case is the sum of the values of the keys where it set a new record;
  improvement above 0 is positive feedback.

The feedback goes to three places: the corpus (positive inputs are kept), the grammar (rewards,
section 2) and the mutator selector (MOpt's success counts).

| Option | Guide | Objectives |
| --- | --- | --- |
| `lookFor: #slowInputs` (`measure: #executionTime`) | `UmeExecutionTimeGuide` | one: the execution time |
| `measure: #methodCalls` | `UmeMethodsCallsGuide` | one per instrumented method: how many times it ran |
| `measure: #bytecodes` | `UmeBytecodesGuide` | executed bytecodes |
| `lookFor: #errors` | `PerfUMateCoverageAndErrorsGuide` | one per covered AST node, one per error message |
| `lookFor: aGuide` | your `UmeFeedbackGuide` | whatever `values:` answers |

Counting method calls works like PerfFuzz: an input that only makes one inner loop run more
often is progress, even if the total time has not moved yet. It is also deterministic, unlike
time.

A custom guide subclasses `UmeFeedbackGuide` and implements `values:` (a dictionary of
objectives for a case) and `tableOfValue` (where the best values are kept). See
[EXAMPLES.md](EXAMPLES.md#11-your-own-measure).

## 7. Instrumentation

Measures other than time need instrumentation, from two tools Ume uses:

- [PBA](https://github.com/FedeLoch/PBA) (`PBAnalyzer`) runs the benchmark under profilers:
  `PBACallBacksProfiler` for time, `PBAMethodProfiler` for method calls (counting through
  metalinks), `PBABytecodeProfiler` for bytecodes;
- Coverage2 (`C2CoverageCollector`) installs metalinks on the AST nodes of the instrumented
  methods and reports which nodes ran.

Instrumentation has a cost proportional to what is instrumented, so the scope matters:

| Campaign | Instrumented |
| --- | --- |
| `#slowInputs` with `#executionTime` | only the entry point (`PerfUMateBenchmark >> #runOn:`) |
| `#methodCalls`, `#bytecodes` | exactly what `instrument:` gives (methods, classes, package names) |
| `#errors` | what `instrument:` gives; else the method behind `receiver:selector:` and what it sends in its package; else the package where the benchmark block was written (test classes excluded) |

Methods with the `<noInstrumentation>` pragma are skipped.

## 8. Metrics and confirmation

Measures taken during the search guide it; they are not trusted for the report. PerfUMate
measures again, outside any instrumentation:

- every run works on a `veryDeepCopy` of the input, so a benchmark that changes its argument
  does not affect the next run;
- every run is stopped after `timeout:` (default 2 seconds) with `valueWithin:onTimeout:`; a
  timeout counts as the whole timeout, so it is the slowest input possible;
- runs shorter than 100 microseconds are repeated on 20 copies and averaged, to get above the
  clock's resolution;
- the baseline is the median time of the examples and of up to 20 new valid graphs;
- a slow candidate is reported if the median of 5 runs is at least `slowdown:` (default 5) times
  the baseline;
- an error candidate is run again and identified by its signature: exception class and first
  method of your code on the stack (Kernel, Collections and PerfUMate frames are skipped).

## 9. Minimization

Each confirmed finding is reduced by `PerfUMateGraphShrinker`, which drives Shin's
`ShinDDminPaperShrinker` over the object graph:

1. walk the graph breadth first, by identity;
2. every collection: try empty, then ddmin over its elements;
3. every string: try empty, then ddmin over its characters;
4. every number: 0, then 1 or -1, then halves toward 0;
5. repeat until nothing shrinks or the finding's deadline passes.

The oracle keeps the behavior: same error signature, or still 2 times `slowdown` slower than the
baseline (median of 3 runs, with a margin so the result does not sit on the threshold where
timing noise decides). If the original input respected the grammar, every candidate must too.
A slow input that is not slow when measured again after minimization is reported unminimized.

## 10. Budget

`budget:` is the total wall clock time:

| Phase | Share |
| --- | --- |
| baseline | up to 10% |
| search | until 80% |
| confirmation and minimization | the remaining 20%, split between the candidates |

A finding whose minimization ran out of time is marked "not fully minimized". Longer budgets
mostly buy more minimization and more search; the confirmation is cheap.
