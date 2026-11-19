# PerfUMate by example

Each step adds one thing to the previous one. All examples use the checkout that ships with
`PerfUMate-Tests` (`PerfUMateExampleCheckout`, `PerfUMateExampleOrder`, `PerfUMateExampleItem`,
and three example orders in `PerfUMateExamples orders`), so they can be run in a Playground as
they are. The outputs shown come from real runs; yours will differ, since the search is random.

1. [The smallest campaign](#1-the-smallest-campaign)
2. [Reading the report](#2-reading-the-report)
3. [Testing a method instead of a block](#3-testing-a-method-instead-of-a-block)
4. [Time: budget, slowdown, timeout](#4-time-budget-slowdown-timeout)
5. [Reviewing and editing the grammar](#5-reviewing-and-editing-the-grammar)
6. [Breaking rules on purpose: validity](#6-breaking-rules-on-purpose-validity)
7. [Hunting crashes](#7-hunting-crashes)
8. [Counting method calls instead of time](#8-counting-method-calls-instead-of-time)
9. [Choosing mutators, selector and corpus heuristic](#9-choosing-mutators-selector-and-corpus-heuristic)
10. [Keeping the findings as tests](#10-keeping-the-findings-as-tests)
11. [Your own measure](#11-your-own-measure)
12. [Campaigns as tests, for CI](#12-campaigns-as-tests-for-ci)

## 1. The smallest campaign

Examples and a benchmark are the only required options:

```smalltalk
report := PerfUMate new
    examples: PerfUMateExamples orders;
    benchmark: [ :order | PerfUMateExampleCheckout new process: order ];
    run.
```

This looks for slow inputs for one minute.

## 2. Reading the report

```smalltalk
report printString.
"PerfUMate: 2 slow input(s), 2 error(s) in 0:00:01:00"

report slowInputs first summary.
"17.5x slower than the median input (143 us vs 8 us) - breaks: Array size 56 not between 0 and 16"

report slowInputs first minimized.      "the reduced order"
report slowInputs first original.       "the order the search found"
report slowInputs first slowdown.       "17.5"
report slowInputs first brokenRule.     "nil when the input respects the grammar"

report errors first signature.          "SubscriptOutOfBounds in PerfUMateExampleCheckout>>#discountFor:"
report grammar mateDefinition.          "the grammar the campaign used"
report campaign.                        "the Ume result: plots, CSV export"
report open.                            "inspector with the findings, the tests and the grammar"
```

`summary` gives the whole report as markdown, and `saveTo: 'perfumate-out'` writes it to a
file, with the generated tests next to it.

## 3. Testing a method instead of a block

`receiver:selector:` replaces `benchmark:` when the code under test is one method:

```smalltalk
report := PerfUMate new
    examples: PerfUMateExamples orders;
    receiver: PerfUMateExampleCheckout new selector: #loyaltyPointsFor:;
    run.
```

The generated tests then rebuild the receiver from STON:

```smalltalk
perfumateBenchmark
    ^ [ :input | (STON fromString: 'PerfUMateExampleCheckout{}') perform: #loyaltyPointsFor: with: input ]
```

## 4. Time: budget, slowdown, timeout

```smalltalk
report := PerfUMate new
    examples: PerfUMateExamples orders;
    benchmark: [ :order | PerfUMateExampleCheckout new process: order ];
    budget: 5 minutes;     "total time; 80% search, 20% confirmation and minimization"
    slowdown: 10;          "report inputs at least 10 times slower than the median"
    timeout: 1 second;     "stop runs after 1 second; they count as slow"
    seed: 7;               "same search every time"
    name: 'checkout';      "used in summaries and saved files"
    run.
```

A higher `slowdown:` gives fewer, clearer findings. A shorter `timeout:` keeps a campaign from
spending its budget on a few huge inputs. A longer `budget:` mostly buys minimization: with one
minute, findings are often "not fully minimized".

## 5. Reviewing and editing the grammar

The grammar is inferred from the examples and widened. Look at it before running:

```smalltalk
perfumate := PerfUMate new
    examples: PerfUMateExamples orders;
    benchmark: [ :order | PerfUMateExampleCheckout new process: order ].

perfumate grammar mateDefinition.
```

```
PerfUMateExampleItem -> {
    name: ByteString,
    quantity: { type: SmallInteger, atLeast: 1 },
    price: { type: SmallInteger, atLeast: 1 }
}

PerfUMateExampleOrder -> {
    items: { type: [ PerfUMateExampleItem ], collection: OrderedCollection, sizeBetween: 0 and: 16 },
    coupon: ByteString
}
```

Say orders always have at least one item, names come from a catalog, quantities are below 100,
and you want orders of up to 200 items. Edit the text and pass it back:

```smalltalk
perfumate grammar: 'PerfUMateExampleItem -> {
    name: { oneOf: { ''tea'' . ''cake'' . ''coffee'' } },
    quantity: { type: SmallInteger, between: 1 and: 100 },
    price: { type: SmallInteger, between: 1 and: 1000 }
}

PerfUMateExampleOrder -> {
    items: { type: [ PerfUMateExampleItem ], collection: OrderedCollection, sizeBetween: 1 and: 200 },
    coupon: { oneOf: { ''VIP10'' . ''SPRING'' . ''WELCOME5'' } }
}'.

report := perfumate budget: 20 seconds; run.
```

```
PerfUMate: 2 slow input(s), 1 error(s) in 0:00:00:20
SubscriptOutOfBounds in PerfUMateExampleCheckout>>#discountFor:: 3 in 'VI' - breaks: Array size 0 not between 1 and 200
9.5x slower than the median input (1353 us vs 142 us)
9.5x slower than the median input (1355 us vs 142 us)
```

The slow inputs now respect the grammar (200 items is allowed). The crash breaks two rules of the
edited grammar, the coupon and the minimum of one item; the report names the first one it finds.
Whether that is a bug depends on whether such orders can reach `process:`.

`widen: false` keeps the inferred grammar as it is, without widening.

## 6. Breaking rules on purpose: validity

By default 10% of the generated inputs break exactly one rule of the grammar (a number out of
range, a `nil` where none is expected, a collection too long...). Raise the share to stress input
validation, or set it to 1 to stay inside the grammar:

```smalltalk
report := PerfUMate new
    examples: PerfUMateExamples orders;
    benchmark: [ :order | PerfUMateExampleCheckout new process: order ];
    lookFor: #errors;
    validity: 0.5;         "half of the generated inputs break one rule"
    budget: 20 seconds;
    run.
```

```
PerfUMate: 0 slow input(s), 2 error(s) in 0:00:00:16
ZeroDivide in PerfUMateExampleCheckout>>#process:
SubscriptOutOfBounds in PerfUMateExampleCheckout>>#discountFor:: 2 in 'R'
```

## 7. Hunting crashes

`lookFor: #errors` searches for crashes and other bugs: every newly covered AST node and every
new error message counts as progress. `instrument:` says whose coverage counts:

```smalltalk
report := PerfUMate new
    examples: PerfUMateExamples orders;
    benchmark: [ :order | PerfUMateExampleCheckout new process: order ];
    lookFor: #errors;
    instrument: { 'PerfUMate-Tests' };   "a package; classes and methods work too"
    budget: 1 minute;
    run.
```

```
PerfUMate: 0 slow input(s), 2 error(s) in 0:00:00:48
SubscriptOutOfBounds in PerfUMateExampleCheckout>>#discountFor:: 1 in ''
    PerfUMateExampleOrder{#items:OrderedCollection[],#coupon:''}
ZeroDivide in PerfUMateExampleCheckout>>#process:
    PerfUMateExampleOrder{#items:OrderedCollection[],#coupon:'P10'}
```

Without `instrument:`, PerfUMate instruments the packages of the classes the benchmark block
names (here `PerfUMateExampleCheckout`, so `PerfUMate-Tests` without its test classes). System
packages are never instrumented.

To find wrong results and not only exceptions, make the benchmark check them; a failed check is
an error like any other:

```smalltalk
benchmark: [ :order | | result |
    result := PerfUMateExampleCheckout new process: order.
    result first >= 0 ifFalse: [ self error: 'negative total' ].
    result ]
```

## 8. Counting method calls instead of time

Time is noisy and needs big differences to show. Counting calls is exact and sees a loop grow
long before the time does. Give the methods to count:

```smalltalk
report := PerfUMate new
    examples: PerfUMateExamples orders;
    benchmark: [ :order | PerfUMateExampleCheckout new process: order ];
    measure: #methodCalls;
    instrument: {
        PerfUMateExampleCheckout >> #loyaltyPointsFor:.
        PerfUMateExampleItem >> #name };
    budget: 1 minute;
    run.
```

```
PerfUMate: 3 slow input(s), 1 error(s) in 0:00:01:00
9.1x slower than the median input (50 us vs 6 us) - breaks: Array size 41 not between 0 and 16
8.4x slower than the median input (46 us vs 6 us) - breaks: Array size 39 not between 0 and 16
7.6x slower than the median input (42 us vs 6 us) - breaks: Array size 37 not between 0 and 16
```

Each instrumented method is its own objective: an input that makes `name` run more often is kept
even if the total time did not change. Instrument the methods you suspect, or a class
(`instrument: { PerfUMateExampleCheckout }`); instrumenting a whole package costs more per run.
`measure: #bytecodes` counts executed bytecodes in the same methods. Findings are still
confirmed by time.

## 9. Choosing mutators, selector and corpus heuristic

The defaults are six mutators chosen by MOpt, and a random pick from the corpus. Each part can be
replaced:

```smalltalk
report := PerfUMate new
    examples: PerfUMateExamples orders;
    benchmark: [ :order | PerfUMateExampleCheckout new process: order ];
    mutators: [ :space | { PerfUMateRepeatMutator on: space } ];   "only repeat runs of elements"
    mutatorSelector: UmeWeightedMutatorSelector new;                "instead of MOpt"
    corpusHeuristic: UmeTournamentSelectorHeuristic new;            "instead of random"
    mutationsPerIteration: 1;                                       "default 2"
    maxElements: 256;                                               "collections grow up to 256"
    budget: 20 seconds;
    run.
```

To add a mutator to the default ones:

```smalltalk
PerfUMateMutator << #ShuffleItemsMutator
    package: 'MyShop-Fuzzing'.

ShuffleItemsMutator >> mutateInput: anInput [
    | order |
    order := anInput graph veryDeepCopy.
    order items: order items shuffled asOrderedCollection.
    ^ space inputForGraph: order
]

perfumate mutators: [ :space | space defaultMutators , { ShuffleItemsMutator on: space } ].
```

See [TECHNICAL.md](TECHNICAL.md) for what each mutator, selector and heuristic does.

## 10. Keeping the findings as tests

```smalltalk
report generateTestsIn: #CheckoutFuzzTest package: 'MyShop-Tests'.
```

This creates a `PerfUMateGeneratedTest` subclass with one test per finding. They fail while the
problems are there and pass once they are fixed:

```smalltalk
testPerfUMate02Error
    "PerfUMate: ZeroDivide in PerfUMateExampleCheckout>>#process:"
    self assertNoErrorOn: (STON fromString: 'PerfUMateExampleOrder{#items:OrderedCollection[],#coupon:''gy,''}')
```

The benchmark is copied into the test class when it does not use variables from its context;
otherwise `perfumateBenchmark` has to be written by hand. `report testSource` shows the methods
without creating the class.

## 11. Your own measure

A guide turns a run into objectives. This one looks for orders with many loyalty points (the
last element of what `process:` answers):

```smalltalk
UmeFeedbackGuide << #LoyaltyPointsGuide
    slots: { #table };
    package: 'MyShop-Fuzzing'.

LoyaltyPointsGuide >> tableOfValue [
    ^ table ifNil: [ table := Dictionary new ]
]

LoyaltyPointsGuide >> values: aCase [
    aCase isError ifTrue: [ ^ Dictionary new ].
    ^ { 'points' -> (self lnCategory: aCase result callResult last) } asDictionary
]

report := PerfUMate new
    examples: PerfUMateExamples orders;
    benchmark: [ :order | PerfUMateExampleCheckout new process: order ];
    lookFor: LoyaltyPointsGuide new;
    budget: 20 seconds;
    run.
```

`lnCategory:` puts values in logarithmic buckets, so only real growth counts. The guide steers
the search; what is reported is still what is confirmed: slow inputs and errors.

## 12. Campaigns as tests, for CI

```smalltalk
PerfUMateCampaignTest << #CheckoutFuzzingTest
    package: 'MyShop-Fuzzing'.

CheckoutFuzzingTest >> testCheckoutHasNoSlowInputs [
    self assertNoFindings: (PerfUMate new
        name: 'checkout';
        examples: PerfUMateExamples orders;
        benchmark: [ :order | PerfUMateExampleCheckout new process: order ];
        budget: 1 minute)
]
```

The test fails when the campaign finds something, with the summary as message, and saves the
report in `perfumate-out/checkout.md` (or `PERFUMATE_OUT`). `PERFUMATE_BUDGET` (seconds)
overrides the budget. [GITHUB-ACTIONS.md](GITHUB-ACTIONS.md) shows how to run such tests on
pull requests and every night.
