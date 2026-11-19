<p align="center">
  <img src="images/logo.svg" alt="PerfUMate" width="380"/>
</p>

<p align="center">
  Fuzzing for Pharo objects: crashes and slow inputs from a few examples.
</p>

---

PerfUMate takes some example objects and the code you want to test. It infers what valid
inputs look like, searches for inputs that break or slow down your code, reduces each one to a
small input, and generates an SUnit test for it.

<p align="center">
  <img src="images/flow.svg" alt="Examples, Mate grammar, Ume campaign, Shin minimization, report and tests" width="820"/>
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
    lookFor: #slowInputs;          "or #errors"
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
