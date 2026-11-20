Extension { #name : 'UmeBugLocalizer' }

{ #category : '*PerfUMate' }
UmeBugLocalizer >> coveredMethodDeltaBetween: baseline and: test [
	"Fix for Ume: a case that failed before its coverage was collected has no coverage result, and
	the localization (built eagerly by UmeResult) raised MessageNotUnderstood and lost the whole
	campaign. Such a case covers nothing new"

	| baselineMethods testMethods |
	baselineMethods := baseline result coverageResult
		                   ifNil: [ #(  ) ]
		                   ifNotNil: [ :coverage | coverage methods ].
	testMethods := test result coverageResult
		               ifNil: [ ^ #(  ) ]
		               ifNotNil: [ :coverage | coverage methods ].
	^ testMethods difference: baselineMethods
]

{ #category : '*PerfUMate' }
UmeBugLocalizer >> coveredNodesDeltaBetween: baseline and: test [
	"Fix for Ume: as #coveredMethodDeltaBetween:and:, a case without coverage executed no node"

	| baselineNodes testNodes |
	baselineNodes := baseline result coverageResult
		                 ifNil: [ Dictionary new ]
		                 ifNotNil: [ :coverage | coverage timesExecuted ].
	testNodes := test result coverageResult
		             ifNil: [ ^ Dictionary new ]
		             ifNotNil: [ :coverage | coverage timesExecuted ].
	^ testNodes keys inject: Dictionary new into: [ :dic :key |
		  | currentValue baselineValue |
		  currentValue := testNodes at: key.
		  baselineValue := baselineNodes at: key ifAbsent: [ 0 ].
		  currentValue > baselineValue ifTrue: [ dic at: key put: currentValue - baselineValue ].
		  dic ]
]
