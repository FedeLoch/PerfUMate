# Fuel

**Property:** an object graph serialized by Fuel materializes with the same meaning, and its hashed
collections still find their elements.

## In the Termo hunt

Campaign `graphfuel` (hunt 2), checked by `TermoHuntGraphFuel`. 2 trials of 600 s per guide
(coverage of `Fuel-Core`, and execution time), on Pharo 14. The first hunt's Fuel campaign, on a
single small class, found nothing; with recipes for every collection kind, hunt 2 found one bug:

- a Set, a Bag or a Dictionary key holding a collection cannot find it after materialization.

## With PerfUMate

```smalltalk
PerfUMate new
    name: 'fuel';
    examples: PerfUMateGraphExamples boxes;
    benchmark: [ :graph |
        PerfUMateCampaigns checkRoundTrip: graph through: [ :g |
            FLMaterializer materializeFromByteArray: (FLSerializer serializeToByteArray: g) ] ];
    lookFor: #errors;
    instrument: { 'Fuel-Core' };
    maxElements: 64;
    budget: 3 minutes;
    seed: 1;
    run.
```

## Result

Pharo 13.1, 3 minutes: 485 runs (Fuel is the slowest round trip: 20 ms for a median input), 17
records, 22 failing runs.

| Finding | Minimized input | Termo |
| --- | --- | --- |
| After the round trip, a Set loses its elements | a box whose first slot is `Set[Set[1,2,3]]` | hunt 2, bug 1 |

Reproducer, from the minimized input. It fails about half the time (54 of 100 round trips, in two
separate images): whether it fails depends on identity hashes, so run it a few times:

```smalltalk
(1 to: 100) count: [ :i |
    | outer copy |
    outer := Set with: (Set withAll: #(1 2 3)).
    copy := FLMaterializer materializeFromByteArray: (FLSerializer serializeToByteArray: outer).
    (copy includes: copy anyOne) not ].     "54"
```

A Set holding an OrderedCollection (`Set with: (OrderedCollection withAll: #(4 5))`) survived the
round trip in this image.

It looks like the outer Set is rebuilt before its inner Set is filled in, so the inner Set sits in
the slot of its empty hash.

Generated test:

```smalltalk
testPerfUMate01Error
    "PerfUMate: PerfUMateBrokenInvariant in PerfUMateCampaigns class>>#broken: (after the round trip, Set loses elements)"
    self assertNoErrorOn: (STON fromString: 'PerfUMateGraphBox{#first:Set[Set[1,2,3]],#second:IdentitySet[''k''],#third:Bag{}}')
```

Like the bug, this test fails about half the time.
