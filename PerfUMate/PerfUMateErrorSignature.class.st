"
I identify an error: its class and the method that signaled it. Two inputs reproduce the same
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

{ #category : 'initialization' }
PerfUMateErrorSignature >> setError: anError [

	errorClassName := anError class name.
	location := anError signalerContext
		            ifNil: [ '?' ]
		            ifNotNil: [ :context | context method printString ].
	messageText := [ anError messageText asString ]
		               on: Error
		               do: [ :e | e return: '' ]
]
