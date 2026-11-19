"
I am the whole user-facing API of PerfUMate.

Give me examples, the code to test, what to look for and a time budget:

	report := PerfUMate new
		examples: { order1. order2. order3 };
		target: [ :order | Checkout new process: order ];
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
		'target',
		'intent',
		'budget',
		'grammar',
		'grammarIsInferred',
		'widen',
		'validity',
		'slowdown',
		'packagesToInstrument',
		'seed',
		'timeout'
	],
	#category : 'PerfUMate-Core',
	#package : 'PerfUMate',
	#tag : 'Core'
}

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
	timeout := 2 seconds
]

{ #category : 'api' }
PerfUMate >> instrument: packageNames [
	"Packages whose coverage guides #errors. By default, derived from the target"

	packagesToInstrument := packageNames asArray
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
PerfUMate >> packagesToInstrument [

	^ packagesToInstrument
]

{ #category : 'api' }
PerfUMate >> receiver: anObject selector: aSelector [
	"Test `anObject perform: aSelector with: input`"

	target := PerfUMateTarget receiver: anObject selector: aSelector
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
PerfUMate >> target [

	^ target
]

{ #category : 'api' }
PerfUMate >> target: aBlock [
	"A one-argument block that runs the code under test on an input"

	target := PerfUMateTarget block: aBlock
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
	target ifNil: [ self error: 'PerfUMate needs a target: target: [ :input | ... ]' ].
	(#( #slowInputs #errors ) includes: intent) | (intent isKindOf: UmeFeedbackGuide) ifFalse: [
		self error: 'lookFor: expects #slowInputs, #errors or a UmeFeedbackGuide' ]
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
