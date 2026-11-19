"
The input of the hashing campaign: keys to put in hashed collections.
"
Class {
	#name : 'PerfUMateKeyBatch',
	#superclass : 'Object',
	#instVars : [
		'keys'
	],
	#category : 'PerfUMate-Campaigns',
	#package : 'PerfUMate-Campaigns'
}

{ #category : 'instance creation' }
PerfUMateKeyBatch class >> keys: aCollection [

	^ self new keys: aCollection
]

{ #category : 'accessing' }
PerfUMateKeyBatch >> keys [

	^ keys
]

{ #category : 'accessing' }
PerfUMateKeyBatch >> keys: aCollection [

	keys := aCollection
]
