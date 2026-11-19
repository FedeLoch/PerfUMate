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

## Use

```smalltalk
report := PerfUMate new
    examples: { order1. order2. order3 };
    target: [ :order | Checkout new process: order ];
    lookFor: #slowInputs;          "the default; #errors for any kind of bug"
    budget: 5 minutes;
    run.

report open.
```

```smalltalk
report findings.
"9.7x slower than the median input (61 us vs 6 us) - breaks: Array size 33 not between 0 and 16"
"SubscriptOutOfBounds in Checkout>>#discountFor:: 1 in ''"

report generateTestsIn: #CheckoutFuzzTest package: 'MyShop-Tests'.
```

The generated tests fail while the problem is there and pass once it is fixed.

## Options

| | Default | |
| --- | --- | --- |
| `grammar` / `grammar:` | inferred | print the inferred grammar, edit it, pass it back |
| `receiver:selector:` | | instead of a block |
| `validity:` | `0.9` | share of inputs that respect every rule |
| `slowdown:` | `5` | how much slower than the median counts as slow |
| `timeout:` | `2 seconds` | longer runs are stopped and count as slow |
| `seed:` | | reproducible campaigns |

## Built on

[Mate](https://github.com/FedeLoch/Mate) (object graph grammars),
[Ume](https://github.com/FedeLoch/Ume) (guided fuzzing) and
[Shin](https://github.com/FedeLoch/Shin) (input minimization).
Design notes: [docs/DESIGN.md](docs/DESIGN.md).
