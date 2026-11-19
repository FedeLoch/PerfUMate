"
A key of the hashing campaign: an integer whose hash and = can be instrumented, so the probes of
Set and Dictionary are counted without instrumenting the kernel (Termo's HuntKey).
"
Class {
	#name : 'PerfUMateKey',
	#superclass : 'Object',
	#instVars : [
		'value'
	],
	#category : 'PerfUMate-Campaigns',
	#package : 'PerfUMate-Campaigns'
}

{ #category : 'instance creation' }
PerfUMateKey class >> value: anInteger [

	^ self new setValue: anInteger
]

{ #category : 'comparing' }
PerfUMateKey >> = anObject [

	^ self class == anObject class and: [ value = anObject value ]
]

{ #category : 'comparing' }
PerfUMateKey >> hash [

	^ value hash
]

{ #category : 'initialization' }
PerfUMateKey >> setValue: anInteger [

	value := anInteger
]

{ #category : 'accessing' }
PerfUMateKey >> value [

	^ value
]
