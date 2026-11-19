"
The input of the object-graph campaigns: three slots holding any objects (collections, numbers,
strings, symbols, points, associations...). Mate infers what each slot can hold from the examples
in PerfUMateGraphExamples.
"
Class {
	#name : 'PerfUMateGraphBox',
	#superclass : 'Object',
	#instVars : [
		'first',
		'second',
		'third'
	],
	#category : 'PerfUMate-Campaigns',
	#package : 'PerfUMate-Campaigns'
}

{ #category : 'instance creation' }
PerfUMateGraphBox class >> first: a second: b third: c [

	^ self new setFirst: a second: b third: c
]

{ #category : 'accessing' }
PerfUMateGraphBox >> first [

	^ first
]

{ #category : 'accessing' }
PerfUMateGraphBox >> second [

	^ second
]

{ #category : 'initialization' }
PerfUMateGraphBox >> setFirst: a second: b third: c [

	first := a.
	second := b.
	third := c
]

{ #category : 'accessing' }
PerfUMateGraphBox >> third [

	^ third
]
