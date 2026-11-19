# STON

**Property:** an object graph written by STON reads back with the same meaning, and its hashed
collections still find their elements.

## In the Termo hunt

Campaign `graphston` (hunt 2): Mate recipes built into graphs by `TermoGraphBuilder`, checked by
`TermoHuntGraphSTON`. 2 trials of 600 s per guide (coverage of `STON-Core`, and execution time),
on Pharo 14. Found two bugs:

- reading a LinkedList that refers back to itself never returns (`STON fromString: 'LinkedList[@1]'`);
- a Bag holding an Association cannot be read back (`Bag{1:2:1}`).

## With PerfUMate

```smalltalk
PerfUMate new
    name: 'ston';
    examples: PerfUMateGraphExamples boxes;
    benchmark: [ :graph |
        PerfUMateCampaigns checkRoundTrip: graph through: [ :g | STON fromString: (STON toString: g) ] ];
    lookFor: #errors;
    instrument: { 'STON-Core' };
    maxElements: 64;
    budget: 3 minutes;
    seed: 1;
    run.
```

`checkRoundTrip:through:` compares a canonical description of the graph before and after
(`PerfUMateCanonical`), and checks that every Set, Bag and Dictionary of the copy finds its own
elements. A failed check signals `PerfUMateBrokenInvariant`.

## Result

Pharo 13.1, 3 minutes: 3,599 runs, 17 records, 106 failing runs.

| Finding | Minimized input | Termo |
| --- | --- | --- |
| `MessageNotUnderstood: Association >> #adaptToNumber:andSend:` in `Bag class>>#fromSton:` | a box whose third slot is `Bag{0:0:1}`, a Bag holding `0 -> 0` | hunt 2, bug 3 |

Reproducer, from the minimized input:

```smalltalk
STON fromString: (STON toString: (Bag with: 0 -> 0)).
"MessageNotUnderstood: Association >> #adaptToNumber:andSend:"
```

`Bag{0:0:1}` reads as element `0`, count `0:1`: the format cannot tell an Association element from
a count.

Not found: the LinkedList that refers back to itself. Mate generates trees, so PerfUMate's graphs
have no cycles.

Generated test (from `report generateTestsIn:package:`):

```smalltalk
testPerfUMate01Error
    "PerfUMate: MessageNotUnderstood in Bag class>>#fromSton:: Message not understood: Association >> #adaptToNumber:andSend:"
    self assertNoErrorOn: (STON fromString: 'PerfUMateGraphBox{#first:Set[],#second:IdentitySet[],#third:Bag{0:0:1}}')
```

Generated tests store their inputs as STON, so this input hits the bug while it is loaded: the
test errors instead of failing. It still reproduces the bug, and passes once STON is fixed.
