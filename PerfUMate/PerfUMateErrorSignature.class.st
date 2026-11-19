"
I identify an error: its class and the first method of the code under test on its stack. Two inputs reproduce the same
bug when their signatures are equal; the message is kept for the report only.
"
Class {
	#name : 'PerfUMateErrorSignature',
	#superclass : 'Object',
	#instVars : [
		'errorClassName',
		'location',
		'messageText'
	],
	#category : 'PerfUMate-Core',
	#package : 'PerfUMate',
	#tag : 'Core'
}

{ #category : 'instance creation' }
PerfUMateErrorSignature class >> of: anError [

	^ self new setError: anError
]

{ #category : 'comparing' }
PerfUMateErrorSignature >> = anObject [

	^ self class = anObject class and: [
		  errorClassName = anObject errorClassName and: [ location = anObject location ] ]
]

{ #category : 'accessing' }
PerfUMateErrorSignature >> errorClassName [

	^ errorClassName
]

{ #category : 'comparing' }
PerfUMateErrorSignature >> hash [

	^ errorClassName hash bitXor: location hash
]

{ #category : 'private' }
PerfUMateErrorSignature >> methodOf: aContext [
	"The method a block context belongs to, so blocks are attributed to their package"

	^ [ aContext homeMethod ]
		  on: Error
		  do: [ :error | error return: aContext method ]
]

{ #category : 'private' }
PerfUMateErrorSignature >> userContextFrom: aContext [
	"The first method of the code under test on the stack, so the report points at it rather
	than at Object>>errorSubscriptBounds:. Falls back to the signaler"

	| context |
	context := aContext.
	[ context notNil ] whileTrue: [
		(self isSystemMethod: (self methodOf: context)) ifFalse: [ ^ context ].
		context := context sender ].
	^ aContext
]

{ #category : 'testing' }
PerfUMateErrorSignature >> isTimeout [

	^ errorClassName = #PerfUMateTimeout
]

{ #category : 'accessing' }
PerfUMateErrorSignature >> location [

	^ location
]

{ #category : 'accessing' }
PerfUMateErrorSignature >> messageText [

	^ messageText
]

{ #category : 'printing' }
PerfUMateErrorSignature >> printOn: aStream [

	aStream
		nextPutAll: errorClassName;
		nextPutAll: ' in ';
		nextPutAll: location
]

{ #category : 'private' }
PerfUMateErrorSignature >> isSystemMethod: aMethod [

	| packageName |
	packageName := [ aMethod package name ]
		               on: Error
		               do: [ :error | error return: '' ].
	packageName = 'PerfUMate' ifTrue: [ ^ true ].
	^ #( 'Kernel' 'Collections' ) anySatisfy: [ :prefix | packageName beginsWith: prefix ]
]

{ #category : 'initialization' }
PerfUMateErrorSignature >> setError: anError [

	errorClassName := anError class name.
	location := (self userContextFrom: anError signalerContext)
		            ifNil: [ '?' ]
		            ifNotNil: [ :context | (self methodOf: context) printString ].
	messageText := [ anError messageText asString ]
		               on: Error
		               do: [ :e | e return: '' ].
	"A broken invariant is identified by what broke, not only by where"
	(anError isKindOf: PerfUMateBrokenInvariant) ifTrue: [ location := location , ' (' , messageText , ')' ]
]
