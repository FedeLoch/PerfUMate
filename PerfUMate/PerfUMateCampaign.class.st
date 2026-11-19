"
One run of a PerfUMate configuration:

1. measure the baseline: median time of the examples and of fresh valid graphs;
2. run a Ume campaign (80% of the budget): corpus seeded with the examples, PerfUMate mutators
   scheduled by MOpt, guided by execution time or by coverage and errors;
3. confirm each candidate on its own (re-time it, re-raise its error);
4. minimize it with Shin (PerfUMateGraphShrinker) while the behavior holds;
5. answer a PerfUMateReport.
"
Class {
	#name : 'PerfUMateCampaign',
	#superclass : 'Object',
	#instVars : [
		'configuration',
		'grammar',
		'space',
		'target',
		'startTime',
		'deadline',
		'baselineMicroseconds',
		'referenceExample'
	],
	#category : 'PerfUMate-Core',
	#package : 'PerfUMate',
	#tag : 'Core'
}

{ #category : 'instance creation' }
PerfUMateCampaign class >> on: aPerfUMate [

	^ self new setConfiguration: aPerfUMate
]

{ #category : 'candidates' }
PerfUMateCampaign >> errorCandidatesIn: someTests [
	"One input per distinct error message, at most 10"

	| byMessage |
	byMessage := OrderedDictionary new.
	(someTests select: [ :test | test isError ]) do: [ :test |
		byMessage at: test result message asString ifAbsentPut: [ test ] ].
	^ (byMessage values first: (byMessage size min: 10)) collect: [ :test | self graphOf: test ]
]

{ #category : 'candidates' }
PerfUMateCampaign >> confirmedSlowCandidatesIn: aUmeResult [
	"Re-time the slow candidates alone and keep the slowest two: the records of one campaign are
	usually the same problem growing, and minimizing each would split the time between copies"

	| timed |
	timed := (self slowCandidatesIn: aUmeResult)
		         collect: [ :graph | graph -> (target medianMicrosecondsOn: graph runs: 3) ]
		         thenSelect: [ :each | each value notNil ].
	^ ((timed asSortedCollection: [ :a :b | a value >= b value ]) asArray first: (timed size min: 2))
		  collect: [ :each | each key ]
]

{ #category : 'findings' }
PerfUMateCampaign >> errorFindingFor: aGraph signature: aSignature until: aDeadline [

	| minimized |
	minimized := self minimize: aGraph until: aDeadline while: [ :graph |
		             (target errorSignatureOn: graph) = aSignature ].
	^ PerfUMateFinding new
		  setKind: #error
		  original: aGraph
		  minimized: minimized key
		  completely: minimized value;
		  signature: aSignature;
		  brokenRule: (space brokenRuleOf: minimized key);
		  yourself
]

{ #category : 'findings' }
PerfUMateCampaign >> findingFor: aGraph until: aDeadline [
	"Confirm aGraph alone and minimize it. nil when it does not reproduce"

	| signature |
	signature := target errorSignatureOn: aGraph.
	(signature isNil or: [ signature isTimeout ]) ifTrue: [ ^ self slowFindingFor: aGraph until: aDeadline ].
	^ self errorFindingFor: aGraph signature: signature until: aDeadline
]

{ #category : 'findings' }
PerfUMateCampaign >> findingsFrom: aUmeResult [

	| candidates findings signatures |
	candidates := (self errorCandidatesIn: aUmeResult tests) , (self confirmedSlowCandidatesIn: aUmeResult).
	findings := OrderedCollection new.
	signatures := Set new.
	candidates withIndexDo: [ :graph :index |
		self hasTime ifTrue: [
			(self findingFor: graph until: (self shareOfRemainingTimeFor: candidates size - index + 1))
				ifNotNil: [ :finding |
					finding isError
						ifTrue: [
							(signatures includes: finding signature) ifFalse: [
								signatures add: finding signature.
								findings add: finding ] ]
						ifFalse: [ findings add: finding ] ] ] ].
	^ findings
]

{ #category : 'private' }
PerfUMateCampaign >> graphOf: aUmeTest [

	^ aUmeTest arguments first graph
]

{ #category : 'campaign' }
PerfUMateCampaign >> guide: aRunner [

	| guide evaluator |
	aRunner guidedByExecutionTime.
	configuration intent = #slowInputs ifTrue: [ ^ self ].
	guide := configuration intent = #errors
		         ifTrue: [ PerfUMateCoverageAndErrorsGuide new ]
		         ifFalse: [ configuration intent ].
	evaluator := aRunner feedbackEvaluator.
	guide evaluator: evaluator.
	"Ume has no guide setter yet (see docs/DESIGN.md, proposed changes)"
	(evaluator respondsTo: #guide:)
		ifTrue: [ evaluator guide: guide ]
		ifFalse: [ evaluator instVarNamed: #guide put: guide ]
]

{ #category : 'testing' }
PerfUMateCampaign >> hasTime [

	^ DateAndTime now < deadline
]

{ #category : 'baseline' }
PerfUMateCampaign >> measureBaseline [
	"Median time of the examples and of up to 20 fresh valid graphs, within 10% of the budget"

	| until exampleTimes times |
	until := startTime + (configuration budget * 0.1).
	exampleTimes := configuration examples
		                collect: [ :example | example -> (target medianMicrosecondsOn: example runs: 3) ]
		                thenSelect: [ :each | each value notNil ].
	times := OrderedCollection withAll: (exampleTimes collect: [ :each | each value ]).
	20 timesRepeat: [
		DateAndTime now < until ifTrue: [
			[ (target medianMicrosecondsOn: space generateValidGraph runs: 3) ifNotNil: [ :time | times add: time ] ]
				on: Error
				do: [ :error | error return: nil ] ] ].
	baselineMicroseconds := times isEmpty
		                        ifTrue: [ 1 ]
		                        ifFalse: [ (PerfUMateTarget median: times) max: 1 ].
	referenceExample := exampleTimes isEmpty
		                    ifTrue: [ configuration examples first ]
		                    ifFalse: [
			                    (exampleTimes detectMin: [ :each | (each value - baselineMicroseconds) abs ]) key ]
]

{ #category : 'minimization' }
PerfUMateCampaign >> minimize: aGraph until: aDeadline while: aBlock [
	"Answer minimizedGraph -> whether minimization finished. A graph that satisfied the grammar
	must keep satisfying it, so minimization never adds a broken rule"

	| shrinker minimized |
	shrinker := PerfUMateGraphShrinker oracle: ((space accepts: aGraph)
			             ifTrue: [ [ :graph | (space accepts: graph) and: [ aBlock value: graph ] ] ]
			             ifFalse: [ aBlock ]).
	shrinker deadline: aDeadline.
	minimized := shrinker shrink: aGraph.
	^ minimized -> shrinker completed
]

{ #category : 'minimization' }
PerfUMateCampaign >> isClearlySlow: aGraph limit: aLimit [
	"Oracle for minimizing slow inputs. Keeps twice the limit, so the minimized input does not sit
	on the threshold where timing noise decides. A median, because one GC pause is enough to make
	a small input look slow"

	^ ((target medianMicrosecondsOn: aGraph runs: 3) ifNil: [ 0 ]) >= (aLimit * 2)
]

{ #category : 'instrumentation' }
PerfUMateCampaign >> methodsToInstrument [

	configuration intent = #slowInputs ifTrue: [ ^ { PerfUMateTarget >> #runOn: } ].
	^ target methodsToInstrumentIn: configuration packagesToInstrument
]

{ #category : 'running' }
PerfUMateCampaign >> run [

	| umeResult findings |
	configuration validate.
	startTime := DateAndTime now.
	deadline := startTime + configuration budget.
	grammar := configuration grammar.
	configuration seed ifNotNil: [ :seed | grammar seed: seed ].
	target := configuration target.
	target timeout: configuration timeout.
	space := PerfUMateSearchSpace grammar: grammar rootType: configuration rootType validity: configuration validity.
	self measureBaseline.
	umeResult := self runUmeFor: deadline - (configuration budget * 0.2) - DateAndTime now.
	findings := self findingsFrom: umeResult.
	^ PerfUMateReport new
		  setConfiguration: configuration
		  grammar: grammar
		  campaign: umeResult
		  findings: findings
		  baseline: baselineMicroseconds
		  reference: referenceExample
		  elapsed: DateAndTime now - startTime
]

{ #category : 'campaign' }
PerfUMateCampaign >> runUmeFor: aDuration [

	| corpus schema runner |
	corpus := UmeCorpusGenerator new
		          seeds: (configuration examples collect: [ :example | space inputForGraph: example veryDeepCopy ]);
		          mutators: space defaultMutators;
		          mutationsPerIteration: 2;
		          yourself.
	corpus mutatorSelector: UmeMOPTMutatorSelector new.
	schema := UmeSchema new
		          receiverConstraint: (UmeObjectConstraint new generator: (UmeGenerator always: target));
		          argumentConstraints: { (UmeObjectConstraint new generator: corpus) };
		          property: [ :receiver :arguments :result | true ];
		          method: PerfUMateTarget >> #runOn:;
		          yourself.
	runner := UmeRunner test: schema for: (aDuration max: 1 second).
	self guide: runner.
	runner methodsToInstrument: self methodsToInstrument.
	^ runner run
]

{ #category : 'initialization' }
PerfUMateCampaign >> setConfiguration: aPerfUMate [

	configuration := aPerfUMate
]

{ #category : 'private' }
PerfUMateCampaign >> shareOfRemainingTimeFor: aNumberOfCandidates [

	^ DateAndTime now + (deadline - DateAndTime now / (aNumberOfCandidates max: 1))
]

{ #category : 'candidates' }
PerfUMateCampaign >> slowCandidatesIn: aUmeResult [
	"The latest records are the slowest inputs found (fewer when looking for errors)"

	| records count |
	count := configuration intent = #slowInputs
		         ifTrue: [ 6 ]
		         ifFalse: [ 2 ].
	records := (aUmeResult topCases ifNil: [ #(  ) ]) reject: [ :test | test isError ].
	^ (records last: (records size min: count)) reverse collect: [ :test | self graphOf: test ]
]

{ #category : 'findings' }
PerfUMateCampaign >> slowFindingFor: aGraph until: aDeadline [

	| median limit minimized minimizedMedian |
	median := (target medianMicrosecondsOn: aGraph runs: 5) ifNil: [ ^ nil ].
	limit := baselineMicroseconds * configuration slowdown.
	median < limit ifTrue: [ ^ nil ].
	minimized := self minimize: aGraph until: aDeadline while: [ :graph | self isClearlySlow: graph limit: limit ].
	minimizedMedian := (target medianMicrosecondsOn: minimized key runs: 5) ifNil: [ 0 ].
	minimizedMedian < limit ifTrue: [
		"The minimized input does not reproduce when measured again: report the original"
		minimized := aGraph -> false.
		minimizedMedian := median ].
	^ PerfUMateFinding new
		  setKind: #slowInput
		  original: aGraph
		  minimized: minimized key
		  completely: minimized value;
		  microseconds: minimizedMedian baseline: baselineMicroseconds;
		  brokenRule: (space brokenRuleOf: minimized key);
		  yourself
]
