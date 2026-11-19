"
I walk an object graph breadth-first (by identity, so cycles terminate) and answer its slots:
the collections that can grow or shrink, the strings and the numbers.

Collections are seen through their elements, not their private slots, like Mate's inferrer.
Strings, symbols, numbers, characters, booleans, classes and blocks are leaves.
"
Class {
	#name : 'PerfUMateGraphWalker',
	#superclass : 'Object',
	#instVars : [
		'root',
		'slots',
		'seen',
		'visited',
		'maxObjects'
	],
	#category : 'PerfUMate-Graphs',
	#package : 'PerfUMate',
	#tag : 'Graphs'
}

{ #category : 'instance creation' }
PerfUMateGraphWalker class >> on: aRoot [

	^ self new setRoot: aRoot
]

{ #category : 'slots' }
PerfUMateGraphWalker >> collectionSlots [

	^ self slots select: [ :slot | self isResizable: slot value ]
]

{ #category : 'private' }
PerfUMateGraphWalker >> enqueue: anObject into: aQueue [

	(self isLeaf: anObject) ifTrue: [ ^ self ].
	(seen includes: anObject) ifTrue: [ ^ self ].
	seen add: anObject.
	visited add: anObject.
	aQueue add: anObject
]

{ #category : 'testing' }
PerfUMateGraphWalker >> isLeaf: anObject [

	^ anObject isNil or: [
		  anObject isNumber or: [
			  anObject isString or: [
				  anObject isCharacter or: [
					  anObject == true or: [
						  anObject == false or: [
							  anObject isBehavior or: [ anObject isBlock or: [ anObject isCompiledMethod ] ] ] ] ] ] ] ]
]

{ #category : 'testing' }
PerfUMateGraphWalker >> isResizable: anObject [
	"A collection that can be rebuilt with `species withAll:` without changing its class"

	^ anObject isCollection and: [
		  anObject isString not and: [ anObject isDictionary not and: [ anObject species == anObject class ] ] ]
]

{ #category : 'slots' }
PerfUMateGraphWalker >> numberSlots [

	^ self slots select: [ :slot | slot value isInteger or: [ slot value isFloat ] ]
]

{ #category : 'slots' }
PerfUMateGraphWalker >> objects [
	"Every object of the graph, leaves (numbers, strings...) not included, breadth first from the root"

	self slots.
	^ visited asArray
]

{ #category : 'slots' }
PerfUMateGraphWalker >> objectCount [
	"Objects in the graph, leaves (numbers, strings...) not counted"

	self slots.
	^ seen size
]

{ #category : 'testing' }
PerfUMateGraphWalker >> reaches: anObject [

	self slots.
	^ anObject == root or: [ seen includes: anObject ]
]

{ #category : 'initialization' }
PerfUMateGraphWalker >> setRoot: aRoot [

	root := aRoot.
	maxObjects := 100000
]

{ #category : 'slots' }
PerfUMateGraphWalker >> slots [

	slots ifNil: [ self walk ].
	^ slots
]

{ #category : 'slots' }
PerfUMateGraphWalker >> stringSlots [

	^ self slots select: [ :slot | slot value isString and: [ slot value isSymbol not ] ]
]

{ #category : 'private' }
PerfUMateGraphWalker >> visit: anObject into: aQueue [

	(self isResizable: anObject) ifTrue: [
		anObject isSequenceable ifTrue: [
			1 to: anObject size do: [ :i | slots add: (PerfUMateSlot element: i of: anObject) ] ].
		anObject do: [ :each | self enqueue: each into: aQueue ].
		^ self ].
	1 to: anObject class instSize do: [ :i |
		slots add: (PerfUMateSlot instVar: i of: anObject).
		self enqueue: (anObject instVarAt: i) into: aQueue ]
]

{ #category : 'private' }
PerfUMateGraphWalker >> walk [

	| queue |
	slots := OrderedCollection new.
	seen := IdentitySet with: root.
	visited := OrderedCollection with: root.
	queue := OrderedCollection with: root.
	(self isLeaf: root) ifTrue: [ ^ self ].
	[ queue notEmpty and: [ seen size < maxObjects ] ] whileTrue: [
		self visit: queue removeFirst into: queue ]
]
