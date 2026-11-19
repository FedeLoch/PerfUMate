"
Unit tests of the pieces PerfUMate adds between Ume, Mate and Shin.
"
Class {
	#name : 'PerfUMatePartsTest',
	#superclass : 'TestCase',
	#category : 'PerfUMate-Tests-Parts',
	#package : 'PerfUMate-Tests',
	#tag : 'Parts'
}

{ #category : 'private' }
PerfUMatePartsTest >> order [

	^ PerfUMateExamples orders first
]

{ #category : 'private' }
PerfUMatePartsTest >> space [

	^ PerfUMateSearchSpace
		  grammar: (MateOGGrammar inferFrom: PerfUMateExamples orders)
		  rootType: PerfUMateExampleOrder
		  validity: 0.9
]

{ #category : 'tests' }
PerfUMatePartsTest >> testDerivationIsKeptWithTheInput [

	| space derivation input |
	space := self space.
	derivation := space generateDerivation: 1.
	input := space inputFor: derivation.
	self assert: (space takeDerivationFor: input) identicalTo: derivation.
	"The benchmark gets a snapshot, not the derivation's own graph"
	self deny: input graph identicalTo: derivation instance
]

{ #category : 'tests' }
PerfUMatePartsTest >> testErrorSignature [

	| benchmark signature |
	benchmark := PerfUMateBenchmark block: [ :order | PerfUMateExampleCheckout new process: order ].
	self assert: (benchmark errorSignatureOn: self order) isNil.
	signature := benchmark errorSignatureOn: (self order coupon: 'V'; yourself).
	self deny: signature isNil.
	self
		assert: signature
		equals: (benchmark errorSignatureOn: (self order coupon: ''; yourself))
]

{ #category : 'tests' }
PerfUMatePartsTest >> testInstrumentationNeverReachesSystemPackages [
	"A block written in a Playground is a DoIt of UndefinedObject: its package must not be used"

	| block methods |
	block := Smalltalk compiler evaluate: '[ :order | PerfUMateExampleCheckout new process: order ]'.
	methods := (PerfUMateBenchmark block: block) methodsToInstrumentIn: nil.
	self assert: (methods includes: PerfUMateExampleCheckout >> #loyaltyPointsFor:).
	self deny: (methods anySatisfy: [ :method | method methodClass == UndefinedObject or: [ method methodClass == Object ] ]).
	self deny: (methods anySatisfy: [ :method | method methodClass inheritsFrom: TestCase ])
]

{ #category : 'tests' }
PerfUMatePartsTest >> testGraphWalkerFindsSlots [

	| walker |
	walker := PerfUMateGraphWalker on: self order.
	self assert: walker collectionSlots size equals: 1.
	self assert: (walker stringSlots collect: [ :slot | slot value ]) asSet equals: #( 'VIP10' 'tea' 'cake' ) asSet.
	self assert: walker numberSlots size equals: 4
]

{ #category : 'tests' }
PerfUMatePartsTest >> testGraphWalkerTerminatesOnCycles [

	| a b |
	a := OrderedCollection new.
	b := OrderedCollection with: a.
	a add: b.
	self assert: (PerfUMateGraphWalker on: a) collectionSlots size equals: 2
]

{ #category : 'tests' }
PerfUMatePartsTest >> testPrimitiveMutatorChangesOneValue [

	| space input mutated |
	space := self space.
	input := space inputForGraph: self order.
	mutated := (PerfUMatePrimitiveMutator on: space) mutate: input.
	self deny: mutated graph identicalTo: input graph.
	self assert: input graph coupon equals: 'VIP10'
]

{ #category : 'tests' }
PerfUMatePartsTest >> testRepeatMutatorRepeatsARun [

	| space input mutated |
	space := self space.
	input := space inputForGraph: self order.
	mutated := (PerfUMateRepeatMutator on: space) mutate: input.
	self assert: mutated graph items size > 2.
	self assert: mutated graph items size <= (2 + (64 * 2)).
	self assert: input graph items size equals: 2.
	"Copies are deep"
	self assert: (mutated graph items asIdentitySet size) equals: mutated graph items size
]

{ #category : 'tests' }
PerfUMatePartsTest >> testRepeatMutatorRespectsMaxElements [

	| space input |
	space := self space.
	space maxElements: 3.
	input := space inputForGraph: self order.
	20 timesRepeat: [ self assert: ((PerfUMateRepeatMutator on: space) mutate: input) graph items size <= 4 ]
]

{ #category : 'tests' }
PerfUMatePartsTest >> testShrinkerKeepsTheBehavior [

	| order minimized |
	order := PerfUMateExampleOrder coupon: 'WELCOME' items: ((1 to: 40) collect: [ :i |
			          PerfUMateExampleItem name: (i = 17 ifTrue: [ 'bad' ] ifFalse: [ 'ok' ]) quantity: i price: 100 ]).
	minimized := (PerfUMateGraphShrinker oracle: [ :graph |
		              graph items anySatisfy: [ :item | item name = 'bad' ] ]) shrink: order.
	self assert: minimized items size equals: 1.
	self assert: minimized items first name equals: 'bad'.
	self assert: minimized coupon equals: ''.
	self assert: minimized items first quantity equals: 0.
	"The original is untouched"
	self assert: order items size equals: 40
]

{ #category : 'tests' }
PerfUMatePartsTest >> testShrinkerMinimizesStrings [

	| order minimized |
	order := PerfUMateExampleOrder coupon: 'xxAxxBxx' items: #(  ).
	minimized := (PerfUMateGraphShrinker oracle: [ :graph |
		              (graph coupon includes: $A) and: [ graph coupon includes: $B ] ]) shrink: order.
	self assert: minimized coupon equals: 'AB'
]

{ #category : 'tests' }
PerfUMatePartsTest >> testTimeoutCountsAsSlow [

	| benchmark |
	benchmark := PerfUMateBenchmark block: [ :x | (Delay forSeconds: 5) wait ].
	benchmark timeout: 100 milliSeconds.
	self assert: (benchmark errorSignatureOn: 1) isTimeout.
	self assert: (benchmark singleRunMicrosecondsOn: 1) equals: 100000
]

{ #category : 'tests' }
PerfUMatePartsTest >> testWidenerWidensSizes [

	| grammar widened |
	grammar := MateOGGrammar inferFrom: PerfUMateExamples orders.
	widened := PerfUMateGrammarWidener new widen: grammar.
	widened typeDeclarations do: [ :declaration |
		(declaration respondsTo: #instanceVariableDeclarations) ifTrue: [
			declaration instanceVariableDeclarations do: [ :variable |
				((variable isKindOf: MateInstArrayVarDecl) and: [ variable maxSize notNil ]) ifTrue: [
					self assert: variable maxSize >= 16 ] ] ] ]
]
