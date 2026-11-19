# Collections

Three campaigns on Pharo's collections: copying, equality and hashing, and the cost of hashed
collections.

## Copying

**Property:** `veryDeepCopy` and `deepCopy` keep the meaning of a graph, their hashed collections
still find their elements, and `veryDeepCopy` shares no mutable object with the original (Points
may be shared: they are values by convention, as in the Termo hunt).

### In the Termo hunt

Campaign `graphcopy` (hunt 2), 2 trials of 600 s per guide (execution time and method calls), on
Pharo 14. Found: `deepCopy` of an IdentitySet or an IdentityDictionary loses its elements.

### With PerfUMate

```smalltalk
PerfUMate new
    name: 'copying';
    examples: PerfUMateGraphExamples boxes;
    benchmark: [ :graph | PerfUMateCampaigns checkCopies: graph ];
    lookFor: #errors;
    instrument: { 'PerfUMate-Campaigns' };
    maxElements: 64;
    budget: 3 minutes;
    seed: 1;
    run.
```

### Result

Pharo 13.1, 3 minutes: 5,610 runs, 7 records, 1,043 failing runs.

| Finding | Minimized input | Termo |
| --- | --- | --- |
| After `deepCopy`, an IdentitySet loses its elements | a box whose second slot is `IdentitySet['k']` | hunt 2, bug 4 |

```smalltalk
| set copy |
set := IdentitySet with: 'k' copy.
copy := set deepCopy.
copy includes: copy anyOne.     "false"
```

`deepCopy` copies the elements (new identities, new identity hashes) but keeps the old table.
`veryDeepCopy` rehashes and works.

## Equality and hash

**Property:** for any two objects of a graph, and any object of the graph against a few values of
related classes (`1 to: 3`, `#(1 2 3)`, `'abc'`, `#abc`, `#[97]`, Sets, Bags...): `=` is symmetric
and equal objects have equal hashes.

### In the Termo hunt

Campaign `graphequal` (hunt 2), 2 trials of 600 s per guide, on Pharo 14. Found: Interval = Array
and Set = IdentitySet with different hashes, ByteArray = String not symmetric (and ScaledDecimal =
Integer with different hashes, already known as pharo#17352).

### With PerfUMate

```smalltalk
PerfUMate new
    name: 'equality';
    examples: PerfUMateGraphExamples boxes;
    benchmark: [ :graph | PerfUMateCampaigns checkEquality: graph ];
    lookFor: #errors;
    instrument: { 'PerfUMate-Campaigns' };
    maxElements: 64;
    budget: 3 minutes;
    seed: 1;
    run.
```

### Result

Pharo 13.1, 3 minutes: 6,351 runs, 7 records, 2,742 failing runs.

| Finding | Minimized input | Termo |
| --- | --- | --- |
| Equal objects, different hashes (Array, Interval) | a box holding `Interval{1, 3, 1}` | hunt 2, bug 5 |
| Equal objects, different hashes (IdentitySet, Set) | a box holding `Set[1, 2]` | hunt 2, bug 6 |
| `=` is not symmetric (ByteArray, ByteString) | a box holding `ByteArray['']` and `''` | hunt 2, bug 7 |
| `=` is not symmetric (ByteArray, ByteSymbol) | a box holding a Bag of `#a -> ''` | hunt 2, bug 7 (the Symbol case) |

```smalltalk
(1 to: 3) = #(1 2 3).                                    "true"
(1 to: 3) hash = #(1 2 3) hash.                          "false"
(Set withAll: #(1 2)) = (IdentitySet withAll: #(1 2)).   "true, different hashes"
#[] = ''.     "true"
'' = #[].     "false"
```

Not bugs, left out: a `ZeroDivide` from an Interval with step 0. Mate builds objects by setting
their instance variables, so it can build an Interval that `to:by:` would refuse. And one "slow
input" that is the check itself: comparing every pair of a box full of large integers is
quadratic.

## Hashed collections (performance)

**Question:** do some keys make Set and Dictionary super-linear (colliding hashes)?

### In the Termo hunt

Target `hash-ints` of the performance hunt: Ume guided by method calls, integer keys wrapped in
`HuntKey` so their `hash` and `=` (the probes of the hashed collections) could be counted.
Verdict: linear, no colliding family found.

### With PerfUMate

The same wrapping: keys are `PerfUMateKey` objects, and only their `hash` and `=` are
instrumented.

```smalltalk
PerfUMate new
    name: 'hashing';
    examples: PerfUMateGraphExamples keyBatches;
    benchmark: [ :batch | PerfUMateCampaigns checkHashing: batch ];
    measure: #methodCalls;
    instrument: { PerfUMateKey >> #hash. PerfUMateKey >> #= };
    budget: 3 minutes;
    seed: 1;
    run.
```

### Result

Pharo 13.1, 3 minutes: 7,966 runs, 4 records. One "slow input": 510 keys, 16 times slower than the
median input of a few keys. The repeat mutator found the records (2 of 4) by growing the batch.

The cost is linear, the same verdict as Termo. Timing `checkHashing:` at growing sizes:

| Keys | 256 | 512 | 1,024 | 2,048 | 4,096 |
| --- | --- | --- | --- | --- | --- |
| Distinct keys | 0.65 ms | 0.85 ms | 3.75 ms | 6.7 ms | 12.85 ms |

A slow input is not a super-linear one: PerfUMate reports how much slower an input is than the
median, and the Campaign tab's "time against input size" chart shows whether the cost grows
faster than the input. Here it does not. Like in the Termo hunt, this campaign is a negative
control.
