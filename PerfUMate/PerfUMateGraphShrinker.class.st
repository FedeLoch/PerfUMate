"
I minimize an object graph with Shin while an oracle (a block on the graph) keeps holding:

1. every collection is reduced with Shin's ddmin over its elements;
2. every string with ddmin over its characters;
3. every number is replaced by 0, 1 or -1, or halved toward 0;

and I repeat until nothing shrinks or the deadline passes. Each change is made in place and
undone when the oracle rejects it, so the oracle should run the benchmark on a copy.
"
Class {
	#name : 'PerfUMateGraphShrinker',
	#superclass : 'Object',
	#instVars : [
		'oracle',
		'deadline',
		'maxPasses',
		'completed'
	],
	#category : 'PerfUMate-Graphs',
	#package : 'PerfUMate',
	#tag : 'Graphs'
}

{ #category : 'instance creation' }
PerfUMateGraphShrinker class >> oracle: aBlock [

	^ self new oracle: aBlock
]

{ #category : 'accessing' }
PerfUMateGraphShrinker >> completed [
	"true when the last #shrink: stopped because nothing else shrinks, not because of the deadline"

	^ completed
]

{ #category : 'accessing' }
PerfUMateGraphShrinker >> deadline: aDateAndTime [

	deadline := aDateAndTime
]

{ #category : 'testing' }
PerfUMateGraphShrinker >> hasTime [

	^ deadline isNil or: [ DateAndTime now < deadline ]
]

{ #category : 'testing' }
PerfUMateGraphShrinker >> holds: aGraph [

	^ [ (oracle value: aGraph) == true ]
		  on: Error
		  do: [ :error | error return: false ]
]

{ #category : 'initialization' }
PerfUMateGraphShrinker >> initialize [

	super initialize.
	maxPasses := 5.
	completed := false
]

{ #category : 'private' }
PerfUMateGraphShrinker >> minimize: aSequence with: aBlock [
	"Try the empty sequence first, then Shin's ddmin"

	(self hasTime and: [ aBlock value: aSequence species new ]) ifTrue: [ ^ aSequence species new ].
	aSequence size <= 1 ifTrue: [ ^ aSequence ].
	^ ShinDDminPaperShrinker new
		  oracle: (ShinBooleanInputOracle from: [ :candidate | self hasTime and: [ aBlock value: candidate ] ]);
		  shrink: aSequence
]

{ #category : 'accessing' }
PerfUMateGraphShrinker >> oracle: aBlock [

	oracle := aBlock
]

{ #category : 'shrinking' }
PerfUMateGraphShrinker >> shrink: aGraph [

	| current passes changed |
	current := aGraph veryDeepCopy.
	completed := false.
	(self holds: current) ifFalse: [ ^ current ].
	passes := 0.
	[
	changed := self shrinkPass: current.
	passes := passes + 1.
	changed and: [ passes < maxPasses and: [ self hasTime ] ] ] whileTrue.
	completed := changed not and: [ self hasTime ].
	^ current
]

{ #category : 'shrinking' }
PerfUMateGraphShrinker >> shrinkCollectionAt: aSlot in: aRoot [

	| original elements kept |
	original := aSlot value.
	elements := original asArray.
	elements isEmpty ifTrue: [ ^ false ].
	kept := [
	        self minimize: elements with: [ :candidate |
		        aSlot value: (original species withAll: candidate).
		        self holds: aRoot ] ] ensure: [ aSlot value: original ].
	^ self try: (original species withAll: kept) at: aSlot in: aRoot ifSmallerThan: elements size
]

{ #category : 'shrinking' }
PerfUMateGraphShrinker >> shrinkNumberAt: aSlot in: aRoot [

	| original |
	original := aSlot value.
	(self simplerNumbersThan: original) do: [ :candidate |
		self hasTime ifTrue: [
			aSlot value: candidate.
			(self holds: aRoot) ifTrue: [ ^ true ] ] ].
	aSlot value: original.
	^ false
]

{ #category : 'shrinking' }
PerfUMateGraphShrinker >> shrinkPass: aRoot [

	"Slots are listed once per kind; a slot whose owner a previous reduction detached is skipped"

	| changed reach |
	changed := false.
	#( #collectionSlots #stringSlots #numberSlots ) do: [ :kind |
		reach := PerfUMateGraphWalker on: aRoot.
		(reach perform: kind) do: [ :slot |
			(self hasTime and: [ reach reaches: slot owner ]) ifTrue: [
				(self shrinkSlot: slot kind: kind in: aRoot) ifTrue: [
					changed := true.
					reach := PerfUMateGraphWalker on: aRoot ] ] ] ].
	^ changed
]

{ #category : 'shrinking' }
PerfUMateGraphShrinker >> shrinkSlot: aSlot kind: aKind in: aRoot [

	aKind = #collectionSlots ifTrue: [ ^ self shrinkCollectionAt: aSlot in: aRoot ].
	aKind = #stringSlots ifTrue: [ ^ self shrinkStringAt: aSlot in: aRoot ].
	^ self shrinkNumberAt: aSlot in: aRoot
]

{ #category : 'shrinking' }
PerfUMateGraphShrinker >> shrinkStringAt: aSlot in: aRoot [

	| original kept |
	original := aSlot value.
	original isEmpty ifTrue: [ ^ false ].
	kept := [
	        self minimize: original with: [ :candidate |
		        aSlot value: candidate.
		        self holds: aRoot ] ] ensure: [ aSlot value: original ].
	^ self try: kept at: aSlot in: aRoot ifSmallerThan: original size
]

{ #category : 'private' }
PerfUMateGraphShrinker >> simplerNumbersThan: aNumber [
	"Simplest first: 0, then the sign, then halvings from the smallest"

	| candidates half halvings |
	aNumber isZero ifTrue: [ ^ #(  ) ].
	candidates := OrderedCollection with: aNumber * 0.
	aNumber abs > 1 ifTrue: [ candidates add: aNumber sign * (aNumber isFloat ifTrue: [ 1.0 ] ifFalse: [ 1 ]) ].
	halvings := OrderedCollection new.
	half := aNumber isFloat ifTrue: [ aNumber / 2.0 ] ifFalse: [ aNumber quo: 2 ].
	[ half abs > 1 and: [ halvings size < 64 ] ] whileTrue: [
		halvings addFirst: half.
		half := aNumber isFloat ifTrue: [ half / 2.0 ] ifFalse: [ half quo: 2 ] ].
	^ candidates , halvings
]

{ #category : 'private' }
PerfUMateGraphShrinker >> try: aValue at: aSlot in: aRoot ifSmallerThan: aSize [
	"aValue was accepted by the oracle during the reduction. It is not checked again: with a
	timing oracle a second check near the threshold can fail by noise and throw the whole
	reduction away"

	aValue size < aSize ifFalse: [ ^ false ].
	aSlot value: aValue.
	^ true
]
