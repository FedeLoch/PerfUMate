"
A Ume mutator over PerfUMateInputs. A mutation that fails answers its input unchanged, so one
bad mutation never stops the campaign (MOpt sees no gain and moves on).
"
Class {
	#name : 'PerfUMateMutator',
	#superclass : 'UmeMutator',
	#instVars : [
		'space'
	],
	#category : 'PerfUMate-Mutators',
	#package : 'PerfUMate',
	#tag : 'Mutators'
}

{ #category : 'instance creation' }
PerfUMateMutator class >> on: aSearchSpace [

	^ self new space: aSearchSpace
]

{ #category : 'feedback' }
PerfUMateMutator >> feed: aFeedback [

	space feed: aFeedback
]

{ #category : 'mutating' }
PerfUMateMutator >> mutate: anInput [

	^ [ self mutateInput: anInput ]
		  on: Error
		  do: [ :error | error return: anInput ]
]

{ #category : 'mutating' }
PerfUMateMutator >> mutateInput: anInput [

	self subclassResponsibility
]

{ #category : 'printing' }
PerfUMateMutator >> printOn: aStream [

	aStream nextPutAll: self class name
]

{ #category : 'accessing' }
PerfUMateMutator >> space: aSearchSpace [

	space := aSearchSpace
]
