"
A canonical description of an object graph, to compare what a graph means before and after a
round trip or a copy: sequenceable collections in order, unordered ones sorted (a rehash is not a
change), floats with their sign and NaN, every other object by class and instance variables.

Also checks that hashed collections still find their own elements (#usable:).
"
Class {
	#name : 'PerfUMateCanonical',
	#superclass : 'Object',
	#category : 'PerfUMate-Campaigns',
	#package : 'PerfUMate-Campaigns'
}

{ #category : 'describing' }
PerfUMateCanonical class >> describe: anObject [

	^ String streamContents: [ :stream | self emit: anObject on: stream depth: 0 ]
]

{ #category : 'describing' }
PerfUMateCanonical class >> emit: anObject on: aStream depth: aDepth [

	aDepth > 40 ifTrue: [ ^ aStream nextPutAll: '...' ].
	anObject isFloat ifTrue: [ ^ aStream nextPutAll: (self floatString: anObject) ].
	(self isLeaf: anObject) ifTrue: [
		^ aStream
			  nextPutAll: anObject class name;
			  nextPut: $:;
			  print: anObject ].
	"An Interval by its bounds: listing the elements of 1 to: 10^18 would never end"
	(anObject isKindOf: Interval) ifTrue: [ ^ self emitFieldsOf: anObject on: aStream depth: aDepth ].
	(anObject isKindOf: Association) ifTrue: [
		aStream nextPutAll: 'Assoc('.
		self emit: anObject key on: aStream depth: aDepth + 1.
		aStream nextPutAll: ' -> '.
		self emit: anObject value on: aStream depth: aDepth + 1.
		^ aStream nextPut: $) ].
	anObject isCollection ifTrue: [
		| parts |
		parts := OrderedCollection new.
		anObject do: [ :each | parts add: (String streamContents: [ :s | self emit: each on: s depth: aDepth + 1 ]) ].
		anObject isSequenceable ifFalse: [ parts := parts asSortedCollection asOrderedCollection ].
		^ aStream
			  nextPutAll: anObject class name;
			  nextPut: $[;
			  nextPutAll: (', ' join: parts);
			  nextPut: $] ].
	self emitFieldsOf: anObject on: aStream depth: aDepth
]

{ #category : 'describing' }
PerfUMateCanonical class >> emitFieldsOf: anObject on: aStream depth: aDepth [

	aStream
		nextPutAll: anObject class name;
		nextPut: $(.
	1 to: anObject class instSize do: [ :i |
		i > 1 ifTrue: [ aStream nextPutAll: ', ' ].
		self emit: (anObject instVarAt: i) on: aStream depth: aDepth + 1 ].
	aStream nextPut: $)
]

{ #category : 'testing' }
PerfUMateCanonical class >> isMutable: anObject [
	"Objects a deep copy must not share with the original. Points are values by convention in
	Pharo, and copies may share them (as in the Termo hunt)"

	(anObject isKindOf: Point) ifTrue: [ ^ false ].
	^ (self isLeaf: anObject) not or: [ anObject isString and: [ anObject isSymbol not ] ]
]

{ #category : 'describing' }
PerfUMateCanonical class >> floatString: aFloat [

	aFloat isNaN ifTrue: [ ^ 'Float:nan' ].
	aFloat isInfinite ifTrue: [
		^ aFloat > 0
			  ifTrue: [ 'Float:+inf' ]
			  ifFalse: [ 'Float:-inf' ] ].
	(aFloat = 0 and: [ aFloat signBit = 1 ]) ifTrue: [ ^ 'Float:-0.0' ].
	^ 'Float:' , aFloat printString
]

{ #category : 'testing' }
PerfUMateCanonical class >> isLeaf: anObject [

	^ anObject isNil or: [
		  anObject isNumber or: [
			  anObject isString or: [
				  anObject isCharacter or: [
					  anObject == true or: [ anObject == false or: [ anObject isBehavior or: [ anObject class == ByteArray ] ] ] ] ] ] ]
]

{ #category : 'graphs' }
PerfUMateCanonical class >> objectsIn: aGraph [
	"The objects of the graph and the leaf values they hold"

	| walker values |
	walker := PerfUMateGraphWalker on: aGraph.
	values := OrderedCollection withAll: walker objects.
	walker slots do: [ :slot |
		(self isLeaf: slot value) ifTrue: [ values add: slot value ] ].
	^ values
]

{ #category : 'checking' }
PerfUMateCanonical class >> problemIn: aGraph [
	"nil when every hashed collection of the graph finds its own elements"

	(PerfUMateGraphWalker on: aGraph) objects do: [ :each |
		((each isKindOf: HashedCollection) or: [ each isKindOf: Bag ]) ifTrue: [
			each do: [ :element |
				| isNaN |
				isNaN := element isFloat and: [ element isNaN ].
				(isNaN or: [ each includes: element ]) ifFalse: [
					^ each class name , ' does not find its element ' , (self describe: element) ] ] ] ].
	^ nil
]
