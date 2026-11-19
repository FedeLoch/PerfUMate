# Kernel: printing and storeString

**Property:** every object of a graph prints without an error, and its `storeString` compiles back
to an equal object (identity collections are left out: the compiler shares equal literals, so they
cannot survive a `storeString`, as noted in the Termo hunt).

## In the Termo hunt

Campaign `graphprint` (hunt 2), 2 trials of 600 s per guide, on Pharo 14. Found three
`storeString`s that do not compile: a Point whose y is -0.0, an Association whose key is a
binary-selector symbol, and symbols with characters the scanner rejects.

## With PerfUMate

```smalltalk
PerfUMate new
    name: 'printing';
    examples: PerfUMateGraphExamples boxes;
    benchmark: [ :graph | PerfUMateCampaigns checkPrinting: graph ];
    lookFor: #errors;
    instrument: { 'PerfUMate-Campaigns' };
    maxElements: 64;
    budget: 3 minutes;
    seed: 1;
    run.
```

`checkPrinting:` goes through the graph's objects innermost first, so a broken part is reported,
not every object that holds it.

## Result

Pharo 13.1, 3 minutes: 16,588 runs, 9 records, 3,357 failing runs.

| Finding | Minimized input | Termo |
| --- | --- | --- |
| `storeString` does not compile (Association) | a box holding `#+ -> 0` | hunt 2, bug 10 |
| `storeString` does not compile (ByteSymbol) | a box holding a symbol of one non-ASCII character | hunt 2, bug 11 |

```smalltalk
(#+ -> 0) storeString.     "'(#+->0)': #+-> is read as one symbol"
(String with: (Character value: 137)) asSymbol storeString.     "does not compile"
```

Not found in this run: the Point with y = -0.0 (bug 9), although it is still there in Pharo 13:

```smalltalk
(1 @ -0.0) storeString.     "'((1@-0.0))': evaluating it raises MessageNotUnderstood: SmallInteger >> #@-"
```

The search did generate `0 @ -0.0` (the primitive mutator makes signed zeros), but in the same
inputs an Interval with step 0 failed first: `storeString` gives `(0 to: 0 by: 0)`, which raises.
That Interval cannot be built through Pharo's API (Mate sets instance variables directly), so it is
left out as an artifact. A longer run, or examples without Intervals, would separate the two.

The two "slow inputs" of this run are the check itself: compiling a `storeString` costs a few
milliseconds, so a box with more objects takes longer.
