"
The whole flow on the example checkout: one campaign looking for slow inputs, one for errors.
"
Class {
	#name : 'PerfUMateTest',
	#superclass : 'TestCase',
	#category : 'PerfUMate-Tests-Flow',
	#package : 'PerfUMate-Tests',
	#tag : 'Flow'
}

{ #category : 'running' }
PerfUMateTest >> perfumate [

	^ PerfUMate new
		  examples: PerfUMateExamples orders;
		  target: [ :order | PerfUMateExampleCheckout new process: order ];
		  seed: 42;
		  yourself
]

{ #category : 'running' }
PerfUMateTest >> setUp [

	super setUp.
	self timeLimit: 2 minutes
]

{ #category : 'tests' }
PerfUMateTest >> testFindsErrors [

	| report finding |
	report := self perfumate
		          lookFor: #errors;
		          budget: 30 seconds;
		          run.
	finding := report errors
		           detect: [ :each | each minimized coupon isString and: [ each minimized coupon size < 3 ] ]
		           ifNone: [ nil ].
	self assert: finding notNil description: 'PerfUMate should find the short coupon crash'.
	"Minimization keeps the crash and drops what does not matter"
	self assert: finding minimized items size <= 1.
	self assert: (report testSource includesSubstring: 'assertNoErrorOn:')
]

{ #category : 'tests' }
PerfUMateTest >> testFindsSlowInputs [

	| report finding |
	report := self perfumate
		          lookFor: #slowInputs;
		          budget: 30 seconds;
		          run.
	self denyEmpty: report slowInputs.
	finding := report slowInputs first.
	self assert: finding slowdown >= 5.
	"Confirmed alone and still slow once minimized"
	self assert: finding minimized items size <= finding original items size.
	self assert: (report testSource includesSubstring: 'timesSlowerThan:')
]

{ #category : 'tests' }
PerfUMateTest >> testGrammarCanBeReviewedAndReplaced [

	| perfumate source |
	perfumate := self perfumate.
	source := perfumate grammar mateDefinition.
	self assert: (source includesSubstring: 'PerfUMateExampleOrder').
	perfumate grammar: source.
	self assert: perfumate grammar mateDefinition equals: source
]

{ #category : 'tests' }
PerfUMateTest >> testRequiresExamplesAndTarget [

	self should: [ PerfUMate new run ] raise: Error.
	self should: [ PerfUMate new examples: PerfUMateExamples orders; run ] raise: Error
]
