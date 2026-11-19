"
I guide Ume toward new code and new errors at once: every covered AST node and every distinct
error message is an objective, so an input that reaches one new node, or fails in a new way, is
progress. Ume runners hold a single guide; I combine its coverage and errors guides.
"
Class {
	#name : 'PerfUMateCoverageAndErrorsGuide',
	#superclass : 'UmeFeedbackGuide',
	#instVars : [
		'table'
	],
	#category : 'PerfUMate-Core',
	#package : 'PerfUMate',
	#tag : 'Core'
}

{ #category : 'accessing' }
PerfUMateCoverageAndErrorsGuide >> category: aValue [

	^ aValue
]

{ #category : 'accessing' }
PerfUMateCoverageAndErrorsGuide >> tableOfValue [

	^ table ifNil: [ table := Dictionary new ]
]

{ #category : 'accessing' }
PerfUMateCoverageAndErrorsGuide >> values: aCase [

	| values |
	values := Dictionary new.
	aCase result coverageResult ifNotNil: [ :coverage |
		coverage nodes do: [ :node | values at: node put: 1 ] ].
	aCase isError ifTrue: [ values at: 'error: ' , aCase result message asString put: 1 ].
	^ values
]
