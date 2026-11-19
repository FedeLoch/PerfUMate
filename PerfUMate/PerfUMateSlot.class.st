"
A place in an object graph that holds a value: an instance variable of an object, or an element
of a sequenceable collection. Mutators and the shrinker read and replace values through me.
"
Class {
	#name : 'PerfUMateSlot',
	#superclass : 'Object',
	#instVars : [
		'owner',
		'index',
		'isInstanceVariable'
	],
	#category : 'PerfUMate-Graphs',
	#package : 'PerfUMate',
	#tag : 'Graphs'
}

{ #category : 'instance creation' }
PerfUMateSlot class >> element: anIndex of: aCollection [

	^ self new setOwner: aCollection index: anIndex instanceVariable: false
]

{ #category : 'instance creation' }
PerfUMateSlot class >> instVar: anIndex of: anObject [

	^ self new setOwner: anObject index: anIndex instanceVariable: true
]

{ #category : 'accessing' }
PerfUMateSlot >> owner [

	^ owner
]

{ #category : 'printing' }
PerfUMateSlot >> printOn: aStream [

	aStream print: owner class.
	isInstanceVariable
		ifTrue: [ aStream nextPut: $.; nextPutAll: (owner class allInstVarNames at: index) ]
		ifFalse: [ aStream nextPut: $[; print: index; nextPut: $] ]
]

{ #category : 'initialization' }
PerfUMateSlot >> setOwner: anObject index: anIndex instanceVariable: aBoolean [

	owner := anObject.
	index := anIndex.
	isInstanceVariable := aBoolean
]

{ #category : 'accessing' }
PerfUMateSlot >> value [

	^ isInstanceVariable
		  ifTrue: [ owner instVarAt: index ]
		  ifFalse: [ owner at: index ]
]

{ #category : 'accessing' }
PerfUMateSlot >> value: anObject [

	isInstanceVariable
		ifTrue: [ owner instVarAt: index put: anObject ]
		ifFalse: [ owner at: index put: anObject ]
]
