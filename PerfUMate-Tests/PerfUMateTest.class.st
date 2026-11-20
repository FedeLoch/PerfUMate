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
		  benchmark: [ :order | PerfUMateExampleCheckout new process: order ];
		  seed: 42;
		  yourself
]

{ #category : 'running' }
PerfUMateTest >> setUp [

	super setUp.
	self timeLimit: 3 minutes
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
PerfUMateTest >> testFindsSlowInputsCountingMethodCalls [

	| report |
	report := self perfumate
		          measure: #methodCalls;
		          instrument: {
				          (PerfUMateExampleCheckout >> #loyaltyPointsFor:).
				          (PerfUMateExampleItem >> #name) };
		          budget: 30 seconds;
		          run.
	self denyEmpty: report slowInputs.
	self assert: report slowInputs first slowdown >= 5
]

{ #category : 'tests' }
PerfUMateTest >> testMethodCallsNeedInstrumentedMethods [

	self should: [ self perfumate measure: #methodCalls; validate ] raise: Error.
	self should: [ self perfumate measure: #heapSize; validate ] raise: Error
]

{ #category : 'tests' }
PerfUMateTest >> testReportIsSaved [

	| report directory |
	report := self perfumate
		          name: 'checkout';
		          budget: 10 seconds;
		          run.
	directory := FileSystem memory root / 'out'.
	report saveTo: directory.
	self assert: ((directory / 'checkout.md') contents includesSubstring: '# PerfUMate: checkout').
	self assert: (directory / 'checkout-tests.st') exists.
	self assert: ((directory / 'checkout-trace.csv') contents lines size) equals: report trace runs size + 1.
	self assertInspectorTabsOf: report.
	self assertLoadedFrom: directory matches: report
]

{ #category : 'tests' }
PerfUMateTest >> assertInspectorTabsOf: aReport [
	"The Findings, Tests and Grammar tabs build with the inspector's presenter builder"

	| builder findings |
	builder := SpPresenterBuilder new.
	builder application: StPharoApplication current.
	findings := aReport inspectionFindings: builder.
	self assert: findings items size equals: aReport findings size.
	self assert: findings columns size equals: 3.
	self assert: ((aReport inspectionTests: builder) text asString includesSubstring: 'perfumateBenchmark').
	self assert: ((aReport inspectionGrammar: builder) text asString includesSubstring: 'PerfUMateExampleOrder').
	self assertChartsOf: aReport
]

{ #category : 'tests' }
PerfUMateTest >> assertLoadedFrom: aDirectory matches: aReport [
	"A saved report comes back with its findings, trace, grammar and tests, and charts again"

	| loaded |
	loaded := PerfUMateReport fromFolder: aDirectory name: 'checkout'.
	self assert: loaded findings size equals: aReport findings size.
	self assert: loaded trace runs size equals: aReport trace runs size.
	self assert: loaded testSource equals: aReport testSource.
	self assert: loaded grammar mateDefinition equals: aReport grammar mateDefinition.
	self assertChartsOf: loaded
]

{ #category : 'tests' }
PerfUMateTest >> assertChartsOf: aReport [
	"Every chart builds and draws, and the trace saw the campaign"

	self denyEmpty: aReport trace runs.
	self assert: (aReport trace runs allSatisfy: [ :run | run microseconds >= 0 ]).
	self denyEmpty: aReport trace mutatorStatistics.
	#( #campaignCanvas #bugsCanvas #mutatorsCanvas #grammarCanvas ) do: [ :selector |
		| canvas morph |
		canvas := aReport charts perform: selector.
		self assert: canvas shapes size > 3.
		morph := canvas createMorph.
		morph extent: 800 @ 400.
		self assert: morph imageForm notNil ]
]

{ #category : 'tests' }
PerfUMateTest >> testAdvancedOptions [
	"Repeat mutator alone, weighted selection, tournament over the corpus"

	| report |
	report := self perfumate
		          mutators: [ :space | { PerfUMateRepeatMutator on: space } ];
		          mutatorSelector: UmeWeightedMutatorSelector new;
		          corpusHeuristic: UmeTournamentSelectorHeuristic new;
		          mutationsPerIteration: 1;
		          maxElements: 256;
		          budget: 20 seconds;
		          run.
	self denyEmpty: report slowInputs.
	self assert: (report slowInputs allSatisfy: [ :finding | finding original items size <= 256 ])
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
PerfUMateTest >> testRequiresExamplesAndBenchmark [

	self should: [ PerfUMate new run ] raise: Error.
	self should: [ PerfUMate new examples: PerfUMateExamples orders; run ] raise: Error
]
