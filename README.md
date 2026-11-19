# PerfUMate

Performance fuzzing for Pharo, from a few example objects.

PerfUMate looks for the inputs that make your code slow. You give it some example objects and
the code to test. It infers what valid inputs look like, searches for the ones that take the
longest, reduces each one to a small input that is still slow, and generates an SUnit test for
it. Crashes found on the way are reported too, and `lookFor: #errors` searches for any kind of
bug instead.

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

## Example

This example ships with the tests (`PerfUMate-Tests`), so you can run it as is. A small checkout
processes orders: it sums the items, applies a coupon and computes loyalty points.

```smalltalk
PerfUMateExampleCheckout >> process: anOrder [
    | total |
    total := anOrder items inject: 0 into: [ :sum :item | sum + (item quantity * item price) ].
    ^ { total - (self discountFor: anOrder). self loyaltyPointsFor: anOrder }
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
    examples: PerfUMateExamples orders;
    target: [ :order | PerfUMateExampleCheckout new process: order ];
    lookFor: #slowInputs;
    budget: 1 minute;
    slowdown: 10;
    timeout: 1 second;
    seed: 7;
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
PerfUMate: 2 slow input(s), 1 error(s) in 0:00:01:00
16.8x slower than the median input (124 us vs 7 us) - breaks: Array size 70 not between 0 and 16
12.5x slower than the median input (92 us vs 7 us) - breaks: Array size 59 not between 0 and 16
SubscriptOutOfBounds in PerfUMateExampleCheckout>>#discountFor:: 1 in ''
```

The slow inputs are orders with 59 and 70 items, mostly with the same name: `loyaltyPointsFor:`
is quadratic in the number of items. The broken rule says why the examples did not show it, as
they never had more than 3 items. The error was found on the way: the minimized order has no
items and an empty coupon, and `first: 3` fails on coupons shorter than 3 characters.

`report generateTestsIn: #CheckoutFuzzTest package: 'MyShop-Tests'` turns the findings into
tests (inputs shortened here):

```smalltalk
testPerfUMate01Error
    "PerfUMate: SubscriptOutOfBounds in PerfUMateExampleCheckout>>#discountFor:: 1 in ''"
    self assertNoErrorOn: (STON fromString: 'PerfUMateExampleOrder{#items:OrderedCollection[],#coupon:''''}')

testPerfUMate02SlowInput
    "PerfUMate: 16.8x slower than the median input (124 us vs 7 us)"
    self
        assertInput: (STON fromString: 'PerfUMateExampleOrder{#items:OrderedCollection[...70 items...]}')
        isAtMost: 10
        timesSlowerThan: self perfumateReferenceInput
```

They fail while the problems are there and pass once they are fixed. The slow input test times
the input against one of the examples in the same run, so it does not depend on the machine.

## Options

`examples:`, `target:` and `budget:` are the ones you normally set; everything else has a default.

| Option | Default | What it does |
| --- | --- | --- |
| `examples:` | | Example inputs. Mate infers a grammar from them (types, ranges, collection sizes), and the search starts from them. |
| `target:` | | A one argument block that runs the code under test on an input. |
| `receiver:selector:` | | Instead of `target:`, calls `receiver perform: selector with: input`. |
| `lookFor:` | `#slowInputs` | `#slowInputs` guides the search by execution time. `#errors` guides it by coverage and new errors, for any kind of bug. A `UmeFeedbackGuide` gives your own measure. |
| `budget:` | `1 minute` | Total time. 80% goes to the search, the rest to confirming and minimizing the findings. |
| `slowdown:` | `5` | An input is reported as slow when it is at least this many times slower than the median input (examples and generated inputs, each timed alone). |
| `timeout:` | `2 seconds` | Each run of the target is stopped after this. An input that times out counts as slow. |
| `validity:` | `0.9` | Share of generated inputs that respect every rule of the grammar. The other 10% break exactly one rule, which is where code usually breaks. |
| `grammar` / `grammar:` | inferred | `grammar` answers the inferred grammar (`mateDefinition` prints it). Edit the text and pass it back with `grammar:` to fix a rule the examples got wrong, or to add one. |
| `widen:` | `true` | Inferred ranges and collection sizes are widened beyond the examples, since a few examples overfit. `false` keeps them as inferred. |
| `instrument:` | from the target | Package names whose coverage guides `#errors`. |
| `seed:` | random | Makes generation reproducible. |

## Built on

[Mate](https://github.com/FedeLoch/Mate) (object graph grammars),
[Ume](https://github.com/FedeLoch/Ume) (guided fuzzing) and
[Shin](https://github.com/FedeLoch/Shin) (input minimization).
Design notes: [docs/DESIGN.md](docs/DESIGN.md).
