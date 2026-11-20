"
I am the whole user-facing API of PerfUMate.

Give me examples, the code to test, what to look for and a time budget:

	report := PerfUMate new
		examples: { order1. order2. order3 };
		benchmark: [ :order | Checkout new process: order ];
		lookFor: #slowInputs;
		budget: 5 minutes;
		run.
	report open.

Mate infers a grammar from the examples (widened, see #grammar), Ume runs a guided campaign whose
mutators are scheduled by MOpt, and every finding is confirmed, minimized with Shin and turned
into an SUnit test (see PerfUMateReport).
"
Class {
	#name : 'PerfUMate',
	#superclass : 'Object',
	#instVars : [
		'examples',
		'benchmark',
		'intent',
		'budget',
		'grammar',
		'grammarIsInferred',
		'widen',
		'validity',
		'slowdown',
		'toInstrument',
		'measure',
		'name',
		'corpusHeuristic',
		'mutatorSelector',
		'mutatorsBlock',
		'mutationsPerIteration',
		'maxElements',
		'seed',
		'timeout'
	],
	#category : 'PerfUMate-Core',
	#package : 'PerfUMate',
	#tag : 'Core'
}

{ #category : 'ci' }
PerfUMate class >> budgetFromEnvironmentOr: aDuration [
	"PERFUMATE_BUDGET (seconds) when set, else aDuration. Lets CI give short campaigns to pull
	requests and long ones to nightly runs without changing the code"

	^ (Smalltalk os environment at: 'PERFUMATE_BUDGET' ifAbsent: [ nil ])
		  ifNil: [ aDuration ]
		  ifNotNil: [ :seconds | seconds asNumber seconds ]
]

{ #category : 'ci' }
PerfUMate class >> campaignsIn: aClass [
	"The campaigns a class declares: class-side methods with the <perfumate> pragma, each answering
	a configured PerfUMate"

	^ (aClass class methods select: [ :method | method hasPragmaNamed: #perfumate ]) asSortedCollection: [ :a :b |
		  a selector <= b selector ]
]

{ #category : 'ci' }
PerfUMate class >> runCampaignsIn: someClassesOrNames into: aDirectoryName [
	"Run every campaign the given classes declare (see #campaignsIn:), each for PERFUMATE_BUDGET
	seconds when set, and save each report into aDirectoryName (see PerfUMateReport >> #saveTo:).
	The classes: a class, its name, several names separated by commas, or a collection of them.
	Also write summary.md, a markdown summary of all the campaigns for a CI job page, and
	findings.txt, the number of findings. A campaign that fails is reported in the summary; the
	others still run"

	| classes directory results |
	classes := (someClassesOrNames isString
		            ifTrue: [ someClassesOrNames substrings: ', ' ]
		            ifFalse: [
			            someClassesOrNames isBehavior
				            ifTrue: [ { someClassesOrNames } ]
				            ifFalse: [ someClassesOrNames ] ]) collect: [ :each |
		           each isString
			           ifTrue: [ self environment at: each asSymbol ]
			           ifFalse: [ each ] ].
	directory := aDirectoryName asFileReference.
	directory ensureCreateDirectory.
	results := classes flatCollect: [ :campaignClass |
		           (self campaignsIn: campaignClass) collect: [ :method |
		           | perfumate |
		           [
		           perfumate := campaignClass perform: method selector.
		           perfumate isNamed ifFalse: [ perfumate name: method selector asString ].
		           perfumate budget: (self budgetFromEnvironmentOr: perfumate budget).
		           method selector -> (perfumate run
				            saveTo: directory;
				            yourself) ]
			           on: Error
			           do: [ :error | error return: method selector -> error ] ] ].
	(directory / 'summary.md') ensureDelete; writeStreamDo: [ :stream |
		self writeSummaryOf: results on: stream ].
	(directory / 'findings.txt') ensureDelete; writeStreamDo: [ :stream |
		stream print: (results inject: 0 into: [ :sum :each |
				  sum + ((each value isKindOf: PerfUMateReport)
					   ifTrue: [ each value findings size ]
					   ifFalse: [ 0 ]) ]) ].
	^ results
]

{ #category : 'ci' }
PerfUMate class >> writeSummaryOf: someResults on: aStream [
	"Markdown for a CI job page: one table of campaigns, then the findings of each"

	aStream
		nextPutAll: '## PerfUMate'; lf; lf;
		nextPutAll: '| Campaign | Slow inputs | Errors | Runs | Time |'; lf;
		nextPutAll: '| --- | ---: | ---: | ---: | --- |'; lf.
	someResults do: [ :each |
		(each value isKindOf: PerfUMateReport)
			ifTrue: [
				aStream
					nextPutAll: '| '; nextPutAll: each value name;
					nextPutAll: ' | '; print: each value slowInputs size;
					nextPutAll: ' | '; print: each value errors size;
					nextPutAll: ' | '; print: each value trace runs size;
					nextPutAll: ' | '; nextPutAll: each value elapsedString;
					nextPutAll: ' |'; lf ]
			ifFalse: [
				aStream
					nextPutAll: '| '; nextPutAll: each key;
					nextPutAll: ' | failed: '; nextPutAll: (each value messageText asString copyReplaceAll: '|' with: '/');
					nextPutAll: ' | | | |'; lf ] ].
	someResults do: [ :each |
		((each value isKindOf: PerfUMateReport) and: [ each value findings notEmpty ]) ifTrue: [
			aStream lf; nextPutAll: '### '; nextPutAll: each value name; lf; lf.
			aStream nextPutAll: '| Finding | Minimized input |'; lf; nextPutAll: '| --- | --- |'; lf.
			each value findings do: [ :finding |
				| input |
				input := finding minimizedSton.
				input size > 160 ifTrue: [ input := (input first: 160) , '...' ].
				aStream
					nextPutAll: '| '; nextPutAll: (finding summary copyReplaceAll: '|' with: '/');
					nextPutAll: ' | `'; nextPutAll: (input copyReplaceAll: '`' with: '''');
					nextPutAll: '` |'; lf ] ] ].
	aStream lf; nextPutAll: 'Charts, generated tests and the full reports (`<campaign>.html`) are in the job''s artifact.'; lf
]

{ #category : 'grammars' }
PerfUMate class >> grammarFromSource: aString [

	^ MateOGGrammar new
		  addTypeDeclarations: (MateLanguageParser parse: aString);
		  yourself
]

{ #category : 'accessing' }
PerfUMate >> budget [

	^ budget
]

{ #category : 'api' }
PerfUMate >> budget: aDuration [
	"The whole wall-clock time: campaign, confirmation and minimization"

	budget := aDuration
]

{ #category : 'accessing' }
PerfUMate >> examples [

	^ examples
]

{ #category : 'api' }
PerfUMate >> examples: aCollection [
	"Example inputs. Mate infers the grammar from them"

	examples := aCollection asArray.
	grammarIsInferred ifTrue: [ grammar := nil ]
]

{ #category : 'api' }
PerfUMate >> grammar [
	"The grammar the campaign will use. Print `grammar mateDefinition` to review it, and pass an
	edited version to #grammar: to tighten it"

	^ grammar ifNil: [
		  grammarIsInferred := true.
		  grammar := self inferGrammar ]
]

{ #category : 'api' }
PerfUMate >> grammar: aGrammarOrMateSource [

	grammarIsInferred := false.
	grammar := aGrammarOrMateSource isString
		           ifTrue: [ self class grammarFromSource: aGrammarOrMateSource ]
		           ifFalse: [ aGrammarOrMateSource ]
]

{ #category : 'private' }
PerfUMate >> inferGrammar [

	| inferred |
	self validateExamples.
	inferred := MateOGGrammar inferFrom: examples.
	widen ifTrue: [ PerfUMateGrammarWidener new widen: inferred ].
	^ inferred
]

{ #category : 'initialization' }
PerfUMate >> initialize [

	super initialize.
	intent := #slowInputs.
	budget := 1 minute.
	grammarIsInferred := false.
	widen := true.
	validity := 0.9.
	slowdown := 5.
	timeout := 2 seconds.
	measure := #executionTime.
	mutationsPerIteration := 2.
	maxElements := 1024
]

{ #category : 'api' }
PerfUMate >> instrument: methodsClassesOrPackageNames [
	"What to instrument: methods, classes, or package names. Needed by `measure: #methodCalls` and
	`measure: #bytecodes`; for #errors it sets the code whose coverage guides the search (by
	default, derived from the benchmark)"

	toInstrument := methodsClassesOrPackageNames asArray
]

{ #category : 'accessing' }
PerfUMate >> intent [

	^ intent
]

{ #category : 'api' }
PerfUMate >> lookFor: anIntentOrGuide [
	"#slowInputs, #errors, or any UmeFeedbackGuide"

	intent := anIntentOrGuide
]

{ #category : 'accessing' }
PerfUMate >> toInstrument [

	^ toInstrument
]

{ #category : 'advanced' }
PerfUMate >> corpusHeuristic [

	^ corpusHeuristic ifNil: [ UmeRandomSelectorHeuristic new ]
]

{ #category : 'advanced' }
PerfUMate >> corpusHeuristic: aUmeSelectorHeuristic [
	"How the next input to mutate is picked from the corpus (default: at random)"

	corpusHeuristic := aUmeSelectorHeuristic
]

{ #category : 'advanced' }
PerfUMate >> maxElements [

	^ maxElements
]

{ #category : 'advanced' }
PerfUMate >> maxElements: anInteger [
	"No collection grows past this many elements through the repeat mutator (default 1024)"

	maxElements := anInteger
]

{ #category : 'advanced' }
PerfUMate >> mutationsPerIteration [

	^ mutationsPerIteration
]

{ #category : 'advanced' }
PerfUMate >> mutationsPerIteration: anInteger [
	"How many times the selected mutator is applied to the picked input (default 2)"

	mutationsPerIteration := anInteger
]

{ #category : 'advanced' }
PerfUMate >> mutatorSelector [

	^ mutatorSelector ifNil: [ UmeMOPTMutatorSelector new ]
]

{ #category : 'advanced' }
PerfUMate >> mutatorSelector: aUmeMutatorSelector [
	"How the mutator is chosen at each step (default: MOpt)"

	mutatorSelector := aUmeMutatorSelector
]

{ #category : 'advanced' }
PerfUMate >> mutators: aBlock [
	"A one argument block answering the mutators, given the PerfUMateSearchSpace. The default
	is `[ :space | space defaultMutators ]`"

	mutatorsBlock := aBlock
]

{ #category : 'advanced' }
PerfUMate >> mutatorsFor: aSearchSpace [

	^ mutatorsBlock
		  ifNil: [ aSearchSpace defaultMutators ]
		  ifNotNil: [ mutatorsBlock value: aSearchSpace ]
]

{ #category : 'accessing' }
PerfUMate >> name [

	^ name ifNil: [
		  examples isEmptyOrNil
			  ifTrue: [ 'perfumate' ]
			  ifFalse: [ self rootType name ] ]
]

{ #category : 'accessing' }
PerfUMate >> isNamed [

	^ name notNil
]

{ #category : 'api' }
PerfUMate >> name: aString [
	"Names the campaign in summaries and saved files"

	name := aString
]

{ #category : 'accessing' }
PerfUMate >> measure [

	^ measure
]

{ #category : 'api' }
PerfUMate >> measure: aSymbol [
	"What guides the search for slow inputs: #executionTime (default), #methodCalls or #bytecodes.
	The last two count what happens in the methods given to #instrument:, which is deterministic
	and finds growing loops before they show in the time. Findings are always confirmed by time"

	measure := aSymbol
]

{ #category : 'api' }
PerfUMate >> receiver: anObject selector: aSelector [
	"Test `anObject perform: aSelector with: input`"

	benchmark := PerfUMateBenchmark receiver: anObject selector: aSelector
]

{ #category : 'accessing' }
PerfUMate >> rootType [

	^ examples first class
]

{ #category : 'api' }
PerfUMate >> run [

	^ (PerfUMateCampaign on: self) run
]

{ #category : 'accessing' }
PerfUMate >> seed [

	^ seed
]

{ #category : 'api' }
PerfUMate >> seed: anInteger [

	seed := anInteger
]

{ #category : 'accessing' }
PerfUMate >> slowdown [

	^ slowdown
]

{ #category : 'api' }
PerfUMate >> slowdown: aNumber [
	"A slow input must be at least aNumber times slower than the median input"

	slowdown := aNumber
]

{ #category : 'accessing' }
PerfUMate >> benchmark [

	^ benchmark
]

{ #category : 'api' }
PerfUMate >> benchmark: aBlock [
	"A one-argument block that runs the code under test on an input"

	benchmark := PerfUMateBenchmark block: aBlock
]

{ #category : 'accessing' }
PerfUMate >> timeout [

	^ timeout
]

{ #category : 'api' }
PerfUMate >> timeout: aDuration [
	"An input running longer than this is stopped and counted as slow"

	timeout := aDuration
]

{ #category : 'validation' }
PerfUMate >> validate [

	self validateExamples.
	benchmark ifNil: [ self error: 'PerfUMate needs a benchmark: benchmark: [ :input | ... ]' ].
	(#( #slowInputs #errors ) includes: intent) | (intent isKindOf: UmeFeedbackGuide) ifFalse: [
		self error: 'lookFor: expects #slowInputs, #errors or a UmeFeedbackGuide' ].
	(#( #executionTime #methodCalls #bytecodes ) includes: measure) ifFalse: [
		self error: 'measure: expects #executionTime, #methodCalls or #bytecodes' ].
	(measure ~= #executionTime and: [ toInstrument isEmptyOrNil ]) ifTrue: [
		self error: 'measure: #' , measure , ' counts in the instrumented methods: give them with instrument: { ... }' ]
]

{ #category : 'validation' }
PerfUMate >> validateExamples [

	examples isEmptyOrNil ifTrue: [ self error: 'PerfUMate needs at least one example: examples: { ... }' ]
]

{ #category : 'accessing' }
PerfUMate >> validity [

	^ validity
]

{ #category : 'api' }
PerfUMate >> validity: aNumber [
	"Share of generated graphs that satisfy every rule of the grammar (the rest break exactly one)"

	validity := aNumber
]

{ #category : 'api' }
PerfUMate >> widen: aBoolean [
	"Widen numeric ranges and collection sizes of the inferred grammar (true by default)"

	widen := aBoolean.
	grammarIsInferred ifTrue: [ grammar := nil ]
]
