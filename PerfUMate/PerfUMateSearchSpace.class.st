"
I am what the mutators share: the Mate grammar, the root type, the validity, and a cache from
input keys to the Mate derivations that built them.

A derivation is handed to the next mutation of its input and then forgotten (the mutation
changes the tree in place), so stacked mutations never re-parse the graph. On a miss (examples,
inputs changed by the repeat or primitive mutators) the graph is parsed again; invalid graphs
cannot be parsed, and only the non-grammar mutators apply to them.
"
Class {
	#name : 'PerfUMateSearchSpace',
	#superclass : 'Object',
	#instVars : [
		'grammar',
		'rootType',
		'validity',
		'cache',
		'nextKey',
		'maxCached',
		'maxElements',
		'lastFeedback'
	],
	#category : 'PerfUMate-Core',
	#package : 'PerfUMate',
	#tag : 'Core'
}

{ #category : 'instance creation' }
PerfUMateSearchSpace class >> grammar: aGrammar rootType: aClass validity: aNumber [

	^ self new setGrammar: aGrammar rootType: aClass validity: aNumber
]

{ #category : 'validation' }
PerfUMateSearchSpace >> accepts: aGraph [

	^ (self parse: aGraph) notNil
]

{ #category : 'generation' }
PerfUMateSearchSpace >> breakOneRuleIn: aDerivation [
	"Make the graph of aDerivation break exactly one rule, in place. nil when this Mate has no
	violation injector (it lives on Mate's confidence-generation branch)"

	| injectorClass |
	injectorClass := self class environment at: #MateViolationInjector ifAbsent: [ ^ nil ].
	(grammar generator respondsTo: #injector) ifFalse: [ ^ nil ].
	aDerivation violations: (grammar generator injector
			 inject: 1
			 into: aDerivation
			 kinds: injectorClass allKinds
			 random: Random new).
	^ aDerivation
]

{ #category : 'validation' }
PerfUMateSearchSpace >> brokenRuleOf: aGraph [
	"nil when aGraph satisfies the grammar, else the first rule it breaks"

	^ [
	  grammar parse: aGraph.
	  nil ]
		  on: Error
		  do: [ :error | error return: error messageText ]
]

{ #category : 'mutators' }
PerfUMateSearchSpace >> defaultMutators [
	"The mutators MOpt chooses from (see docs/DESIGN.md, 3.3)"

	^ {
		  PerfUMateGenerateMutator on: self.
		  (PerfUMateDerivationMutator on: self) leastRewarded.
		  (PerfUMateDerivationMutator on: self) random.
		  (PerfUMateDerivationMutator on: self) breakingRule.
		  PerfUMateRepeatMutator on: self.
		  PerfUMatePrimitiveMutator on: self }
]

{ #category : 'feedback' }
PerfUMateSearchSpace >> feed: aFeedback [
	"Reward the derivation that built the case, once per feedback (every mutator forwards it)"

	| derivation |
	(aFeedback isNil or: [ aFeedback == lastFeedback ]) ifTrue: [ ^ self ].
	lastFeedback := aFeedback.
	(aFeedback case isKindOf: PerfUMateInput) ifFalse: [ ^ self ].
	derivation := aFeedback case key ifNotNil: [ :key | cache at: key ifAbsent: [ nil ] ].
	derivation ifNil: [ ^ self ].
	[ grammar backpropagate: derivation improvement: aFeedback improvement ]
		on: Error
		do: [ :error | error return: nil ]
]

{ #category : 'generation' }
PerfUMateSearchSpace >> generateDerivation: aValidity [

	^ (aValidity < 1 and: [ self supportsValidity ])
		  ifTrue: [ grammar gen: rootType from: MateContext new validity: aValidity ]
		  ifFalse: [ grammar gen: rootType from: MateContext new ]
]

{ #category : 'generation' }
PerfUMateSearchSpace >> generateValidGraph [

	^ (grammar gen: rootType from: MateContext new) instance
]

{ #category : 'accessing' }
PerfUMateSearchSpace >> grammar [

	^ grammar
]

{ #category : 'inputs' }
PerfUMateSearchSpace >> inputFor: aDerivation [
	"The target gets a snapshot; the derivation keeps its own instance to be mutated later"

	^ PerfUMateInput graph: aDerivation instance veryDeepCopy key: (self register: aDerivation)
]

{ #category : 'inputs' }
PerfUMateSearchSpace >> inputForGraph: aGraph [

	^ PerfUMateInput graph: aGraph key: nil
]

{ #category : 'accessing' }
PerfUMateSearchSpace >> maxElements [

	^ maxElements
]

{ #category : 'accessing' }
PerfUMateSearchSpace >> maxElements: anInteger [

	maxElements := anInteger
]

{ #category : 'validation' }
PerfUMateSearchSpace >> parse: aGraph [

	^ [ grammar parse: aGraph ]
		  on: Error
		  do: [ :error | error return: nil ]
]

{ #category : 'inputs' }
PerfUMateSearchSpace >> register: aDerivation [

	nextKey := nextKey + 1.
	cache at: nextKey put: aDerivation.
	cache size > maxCached ifTrue: [ cache removeKey: cache keys first ].
	^ nextKey
]

{ #category : 'accessing' }
PerfUMateSearchSpace >> rootType [

	^ rootType
]

{ #category : 'initialization' }
PerfUMateSearchSpace >> setGrammar: aGrammar rootType: aClass validity: aNumber [

	grammar := aGrammar.
	rootType := aClass.
	validity := aNumber.
	cache := OrderedDictionary new.
	nextKey := 0.
	maxCached := 1000.
	maxElements := 1024
]

{ #category : 'testing' }
PerfUMateSearchSpace >> supportsValidity [

	^ grammar respondsTo: #gen:from:validity:
]

{ #category : 'inputs' }
PerfUMateSearchSpace >> takeDerivationFor: anInput [
	"The derivation of anInput, to be changed in place by a mutation. nil if the graph is invalid"

	anInput key ifNotNil: [ :key |
		(cache removeKey: key ifAbsent: [ nil ]) ifNotNil: [ :derivation | ^ derivation ] ].
	^ self parse: anInput graph veryDeepCopy
]

{ #category : 'accessing' }
PerfUMateSearchSpace >> validity [

	^ validity
]
