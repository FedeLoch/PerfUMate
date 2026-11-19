# PerfUMate

[![CI](https://github.com/FedeLoch/PerfUMate/actions/workflows/ci.yml/badge.svg)](https://github.com/FedeLoch/PerfUMate/actions/workflows/ci.yml)
[![Last commit](https://img.shields.io/github/last-commit/FedeLoch/PerfUMate)](https://github.com/FedeLoch/PerfUMate/commits/main)
[![License](https://img.shields.io/github/license/FedeLoch/PerfUMate)](LICENSE)
[![Pharo 13](https://img.shields.io/badge/Pharo-13-blue)](https://pharo.org)

Performance fuzzing for Pharo, from a few example objects.

PerfUMate looks for the inputs that make your code slow. You give it some example objects and
a benchmark (the code to run on each input). It infers what valid inputs look like, searches
for the ones that take the longest, reduces each one to a small input that is still slow, and
generates an SUnit test for it. Crashes found on the way are reported too, and
`lookFor: #errors` hunts for crashes and other bugs instead.

Built on [Mate](https://github.com/FedeLoch/Mate) (object graph grammars),
[Ume](https://github.com/FedeLoch/Ume) (guided fuzzing) and
[Shin](https://github.com/FedeLoch/Shin) (input minimization).

<p align="center">
  <img src="images/flow.svg" alt="examples, Mate, Ume, Shin, tests" width="680"/>
</p>

## Install

```smalltalk
Metacello new
    baseline: 'PerfUMate';
    repository: 'github://FedeLoch/PerfUMate:main';
    onConflictUseIncoming;
    load.
```

## Example: slow inputs

This example ships with the tests (`PerfUMate-Tests`), so you can run it as is. A small checkout
processes orders: it sums the items, applies a coupon, computes the average unit price and the
loyalty points.

```smalltalk
PerfUMateExampleCheckout >> process: anOrder [
    | total units |
    
    total := anOrder items inject: 0 into: [ :sum :item | sum + (item quantity * item price) ].

    units := anOrder items inject: 0 into: [ :sum :item | sum + item quantity ].
    ^ { total - (self discountFor: anOrder). total // units. self loyaltyPointsFor: anOrder }
]

PerfUMateExampleCheckout >> loyaltyPointsFor: anOrder [
    "For every item, count the items with the same name"
    
    ^ anOrder items inject: 0 into: [ :points :item |
        points + (anOrder items count: [ :other | other name = item name ]) ]
]

PerfUMateExampleCheckout >> discountFor: anOrder [

    ^ (anOrder coupon first: 3) = 'VIP' ifTrue: [ 10 ] ifFalse: [ 0 ]
]
```

With the three example orders of the tests (one to three items, coupons `'VIP10'`, `'SPRING'`
and `'WELCOME5'`) nothing looks wrong. A one minute campaign:

```smalltalk
perfumate := PerfUMate new
    examples: PerfUMateExamples orders;                                  "required"
    benchmark: [ :order | PerfUMateExampleCheckout new process: order ]; "required"
    lookFor: #slowInputs;     "optional, the default"
    budget: 1 minute;         "optional, default 1 minute"
    slowdown: 10;             "optional, default 5"
    timeout: 1 second;        "optional, default 2 seconds"
    seed: 7;                  "optional, for reproducible runs"
    yourself.

perfumate grammar mateDefinition.   "optional: check what was inferred before running"
report := perfumate run.
report open.
```

The grammar inferred from the examples, with collection sizes widened to 16:

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

The report:

```
PerfUMate: 2 slow input(s), 2 error(s) in 0:00:01:00
17.5x slower than the median input (143 us vs 8 us) - breaks: Array size 56 not between 0 and 16
10.3x slower than the median input (84 us vs 8 us) - breaks: Array size 42 not between 0 and 16
SubscriptOutOfBounds in PerfUMateExampleCheckout>>#discountFor:: 1 in ''
ZeroDivide in PerfUMateExampleCheckout>>#process:
```

The slow inputs are orders with 56 and 42 items: `loyaltyPointsFor:` is quadratic in the number
of items. The broken rule says why the examples did not show it, as they never had more than 3
items. The two crashes were found on the way: coupons shorter than 3 characters, and orders
without units.

## Example: crashes and other bugs

To hunt for bugs instead of slow inputs, look for errors. The search is then guided by coverage
(each newly reached AST node counts) and by new error messages:

```smalltalk
report := PerfUMate new
    examples: PerfUMateExamples orders;                                  "required"
    benchmark: [ :order | PerfUMateExampleCheckout new process: order ]; "required"
    lookFor: #errors;
    instrument: { 'PerfUMate-Tests' };   "optional: code whose coverage guides the search"
    budget: 1 minute;                    "optional"
    run.
```

```
PerfUMate: 0 slow input(s), 2 error(s) in 0:00:00:48
SubscriptOutOfBounds in PerfUMateExampleCheckout>>#discountFor:: 1 in ''
    PerfUMateExampleOrder{#items:OrderedCollection[],#coupon:''}
ZeroDivide in PerfUMateExampleCheckout>>#process:
    PerfUMateExampleOrder{#items:OrderedCollection[],#coupon:'P10'}
```

Each error is minimized while keeping the same exception and the same method. The second input
keeps a 3 character coupon because a shorter one would hit the first bug instead. Errors are
located at the first method of your code on the stack, not at `Object>>errorSubscriptBounds:`.

## Performance Hunting Example Counting Method Calls

Execution time is noisy, and a loop that grows from 3 to 30 iterations barely shows in it.
Counting calls is exact. Give the methods to count and PerfUMate guides the search by how many
times they run (each method is its own objective, as in PerfFuzz):

```smalltalk
report := PerfUMate new
    examples: PerfUMateExamples orders;                                  "required"
    benchmark: [ :order | PerfUMateExampleCheckout new process: order ]; "required"
    measure: #methodCalls;                                               "or #bytecodes"
    instrument: {                                                        "required with #methodCalls"
        PerfUMateExampleCheckout >> #loyaltyPointsFor:.
        PerfUMateExampleItem >> #name
    };
    budget: 1 minute;                                                    "optional"
    run.
```

```
PerfUMate: 3 slow input(s), 1 error(s) in 0:00:01:00
9.1x slower than the median input (50 us vs 6 us) - breaks: Array size 41 not between 0 and 16
8.4x slower than the median input (46 us vs 6 us) - breaks: Array size 39 not between 0 and 16
7.6x slower than the median input (42 us vs 6 us) - breaks: Array size 37 not between 0 and 16
```

`instrument:` takes methods, classes or package names. Only what you give is instrumented, which
keeps each run cheap. Findings are still confirmed by execution time.

## Generated tests

`report generateTestsIn: #CheckoutFuzzTest package: 'MyShop-Tests'` turns the findings into
tests (inputs shortened here):

```smalltalk
testPerfUMate01Error
    "PerfUMate: SubscriptOutOfBounds in PerfUMateExampleCheckout>>#discountFor:: 1 in ''"
    self assertNoErrorOn: (STON fromString: 'PerfUMateExampleOrder{#items:OrderedCollection[],#coupon:''''}')

testPerfUMate03SlowInput
    "PerfUMate: 17.5x slower than the median input (143 us vs 8 us)"
    self
        assertInput: (STON fromString: 'PerfUMateExampleOrder{#items:OrderedCollection[...56 items...]}')
        isAtMost: 10
        timesSlowerThan: self perfumateReferenceInput
```

They fail while the problems are there and pass once they are fixed. The slow input test times
the input against one of the examples in the same run, so it does not depend on the machine.

## Options

Only `examples:` and `benchmark:` are required.

| Option | Default | What it does |
| --- | --- | --- |
| `examples:` | required | Example inputs. Mate infers a grammar from them (types, ranges, collection sizes), and the search starts from them. |
| `benchmark:` | required | A one argument block that runs the code under test on an input. |
| `receiver:selector:` | | Instead of `benchmark:`, runs `receiver perform: selector with: input`. |
| `lookFor:` | `#slowInputs` | `#slowInputs` searches for slow inputs. `#errors` searches for crashes, guided by coverage and new errors. A `UmeFeedbackGuide` gives your own measure. |
| `measure:` | `#executionTime` | For slow inputs: `#executionTime`, `#methodCalls` or `#bytecodes`. The last two count in the methods given to `instrument:`. |
| `instrument:` | from the benchmark | Methods, classes or package names. Required by `#methodCalls` and `#bytecodes`; for `#errors`, the code whose coverage guides the search. |
| `budget:` | `1 minute` | Total time. 80% goes to the search, the rest to confirming and minimizing the findings. |
| `slowdown:` | `5` | An input is slow when it is at least this many times slower than the median input (examples and generated inputs, each timed alone). |
| `timeout:` | `2 seconds` | Each run of the benchmark is stopped after this. An input that times out counts as slow. |
| `validity:` | `0.9` | Share of generated inputs that respect every rule of the grammar. The other 10% break exactly one rule, which is where code usually breaks. |
| `grammar` / `grammar:` | inferred | `grammar` answers the inferred grammar (`mateDefinition` prints it). Edit the text and pass it back with `grammar:` to fix a rule the examples got wrong, or to add one. |
| `widen:` | `true` | Inferred ranges and collection sizes are widened beyond the examples, since a few examples overfit. `false` keeps them as inferred. |
| `name:` | root class name | Names the campaign in summaries and saved reports. |
| `seed:` | random | Makes generation reproducible. |

Advanced options (`mutators:`, `mutatorSelector:`, `corpusHeuristic:`, `mutationsPerIteration:`,
`maxElements:`) are explained in [Technical architecture](https://github.com/FedeLoch/PerfUMate/wiki/PerfUMate-Technical-Architecture) and shown in
[Examples](https://github.com/FedeLoch/PerfUMate/wiki/Examples#9-choosing-mutators-selector-and-corpus-heuristic).

## In CI

A campaign can run as an SUnit test: subclass `PerfUMateCampaignTest` and call
`assertNoFindings:`. `PERFUMATE_BUDGET` (seconds) changes the budget without touching the code,
so pull requests can run short campaigns and nightly jobs long ones. See
[GitHub Actions integration](https://github.com/FedeLoch/PerfUMate/wiki/GitHub-Actions-Integration).

## More

- [Examples](https://github.com/FedeLoch/PerfUMate/wiki/Examples): step by step examples, from the minimal campaign to custom guides.
- [Technical architecture](https://github.com/FedeLoch/PerfUMate/wiki/PerfUMate-Technical-Architecture): how each part works and can be configured (corpus, grammar mutators, MOpt, feedback, weighted grammars, instrumentation, metrics).
- [Design](https://github.com/FedeLoch/PerfUMate/wiki/PerfUMate-design): design notes and proposed changes to Ume, Mate and Shin.
