"
I pick a collection in the graph, a run of 1 to 4 of its elements, and insert 2 to 64 deep copies
of that run after it (never past the space's maxElements).

Super-linear behavior needs many copies of one construct, which derivation mutation (one node at
a time, within declared sizes) rarely builds. In Termo, the same mutator found the structural
slowdowns of cmark, cmark-gfm and sqlparse 4 to 10 times faster.
"
Class {
	#name : 'PerfUMateRepeatMutator',
	#superclass : 'PerfUMateMutator',
	#category : 'PerfUMate-Mutators',
	#package : 'PerfUMate',
	#tag : 'Mutators'
}

{ #category : 'mutating' }
PerfUMateRepeatMutator >> mutateInput: anInput [

	| graph slots slot elements runSize start copies inserted |
	graph := anInput graph veryDeepCopy.
	slots := (PerfUMateGraphWalker on: graph) collectionSlots reject: [ :each | each value isEmpty ].
	slots ifEmpty: [ ^ anInput ].
	slot := slots atRandom.
	elements := slot value asArray.
	runSize := (1 to: (4 min: elements size)) atRandom.
	start := (1 to: elements size - runSize + 1) atRandom.
	copies := (2 to: 64) atRandom min: space maxElements - elements size // runSize.
	copies < 1 ifTrue: [ ^ anInput ].
	inserted := Array new: copies * runSize streamContents: [ :stream |
		            copies timesRepeat: [
			            start to: start + runSize - 1 do: [ :i | stream nextPut: (elements at: i) veryDeepCopy ] ] ].
	slot value: (slot value species withAll:
			 (elements first: start + runSize - 1) , inserted , (elements allButFirst: start + runSize - 1)).
	^ space inputForGraph: graph
]

{ #category : 'printing' }
PerfUMateRepeatMutator >> label [

	^ 'repeat elements'
]
