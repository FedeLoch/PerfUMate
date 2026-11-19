"
What Ume's corpus holds: an object graph and the key of the Mate derivation that built it
(see PerfUMateSearchSpace). Keeping the derivation next to the input means stacked mutations do
not re-parse the whole graph each time.
"
Class {
	#name : 'PerfUMateInput',
	#superclass : 'Object',
	#instVars : [
		'graph',
		'key'
	],
	#category : 'PerfUMate-Core',
	#package : 'PerfUMate',
	#tag : 'Core'
}

{ #category : 'instance creation' }
PerfUMateInput class >> graph: anObject key: aKeyOrNil [

	^ self new setGraph: anObject key: aKeyOrNil
]

{ #category : 'accessing' }
PerfUMateInput >> graph [

	^ graph
]

{ #category : 'accessing' }
PerfUMateInput >> key [

	^ key
]

{ #category : 'printing' }
PerfUMateInput >> printOn: aStream [

	graph printOn: aStream
]

{ #category : 'initialization' }
PerfUMateInput >> setGraph: anObject key: aKeyOrNil [

	graph := anObject.
	key := aKeyOrNil
]
