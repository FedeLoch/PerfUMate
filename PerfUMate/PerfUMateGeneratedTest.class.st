"
Superclass of the test classes a PerfUMateReport generates. Each test holds one minimized input
as STON and fails while the problem it reproduces is still there.
"
Class {
	#name : 'PerfUMateGeneratedTest',
	#superclass : 'TestCase',
	#category : 'PerfUMate-Report',
	#package : 'PerfUMate',
	#tag : 'Report'
}

{ #category : 'testing' }
PerfUMateGeneratedTest class >> isAbstract [

	^ self == PerfUMateGeneratedTest
]

{ #category : 'asserting' }
PerfUMateGeneratedTest >> assertInput: anInput isAtMost: aRatio timesSlowerThan: aReferenceInput [
	"Both inputs are timed in the same run, so the test does not depend on the machine"

	| target inputTime referenceTime |
	target := PerfUMateTarget block: self perfumateTarget.
	inputTime := target medianMicrosecondsOn: anInput runs: 5.
	self assert: inputTime notNil description: 'The input raised an error'.
	referenceTime := (target medianMicrosecondsOn: aReferenceInput runs: 5) ifNil: [ 1 ].
	self
		assert: inputTime / (referenceTime max: 1) < aRatio
		description: [
			'PerfUMate: the input is ' , (inputTime / (referenceTime max: 1)) rounded printString
			, 'x slower than the reference input (limit ' , aRatio printString , 'x)' ]
]

{ #category : 'asserting' }
PerfUMateGeneratedTest >> assertNoErrorOn: anInput [

	self shouldnt: [ self perfumateTarget value: anInput ] raise: Error
]

{ #category : 'accessing' }
PerfUMateGeneratedTest >> perfumateReferenceInput [

	^ self subclassResponsibility
]

{ #category : 'accessing' }
PerfUMateGeneratedTest >> perfumateTarget [

	^ self subclassResponsibility
]
