"
The Pharo campaigns first run with Ume, Mate and Shin from the Termo hunt (hunt 2, object graphs,
and the hashing target of the performance hunt), written with PerfUMate. Each class-side method
answers a configured PerfUMate; the checks it calls are the invariants of the original campaigns.

	report := PerfUMateCampaigns ston budget: 2 minutes; run.
	report open.

See campaigns/ in the repository for what each one found.
"
Class {
	#name : 'PerfUMateCampaigns',
	#superclass : 'Object',
	#category : 'PerfUMate-Campaigns',
	#package : 'PerfUMate-Campaigns'
}

{ #category : 'checks' }
PerfUMateCampaigns class >> broken: aLabel [

	PerfUMateBrokenInvariant signal: aLabel
]

{ #category : 'checks' }
PerfUMateCampaigns class >> checkCopies: aGraph [
	"veryDeepCopy and deepCopy keep the meaning, their hashed collections work, and veryDeepCopy
	shares no mutable object with the original"

	| before copy originals |
	before := PerfUMateCanonical describe: aGraph.
	copy := aGraph veryDeepCopy.
	(PerfUMateCanonical describe: copy) = before ifFalse: [ self broken: 'veryDeepCopy changes the graph' ].
	(PerfUMateCanonical problemIn: copy) ifNotNil: [ :problem | self broken: 'after veryDeepCopy, ' , (problem copyUpTo: $ ) , ' loses elements' ].
	originals := IdentitySet withAll: ((PerfUMateCanonical objectsIn: aGraph) select: [ :each | PerfUMateCanonical isMutable: each ]).
	(PerfUMateCanonical objectsIn: copy) do: [ :each |
		(originals includes: each) ifTrue: [ self broken: 'veryDeepCopy shares a ' , each class name ] ].
	copy := aGraph deepCopy.
	(PerfUMateCanonical describe: copy) = before ifFalse: [ self broken: 'deepCopy changes the graph' ].
	(PerfUMateCanonical problemIn: copy) ifNotNil: [ :problem | self broken: 'after deepCopy, ' , (problem copyUpTo: $ ) , ' loses elements' ].
	^ copy
]

{ #category : 'checks' }
PerfUMateCampaigns class >> checkEquality: aGraph [
	"For any two objects of the graph, and any object of the graph against a few values of related
	classes: = never raises, is symmetric, and equal objects have equal hashes. The related values
	are not compared with each other, so every finding depends on the generated graph"

	| graphObjects |
	graphObjects := (PerfUMateCanonical objectsIn: aGraph) asArray.
	graphObjects := graphObjects first: (graphObjects size min: 30).
	graphObjects do: [ :a |
		graphObjects , self relatedValues do: [ :b |
			a == b ifFalse: [
				self checkEqualityOf: a and: b.
				self checkEqualityOf: b and: a ] ] ].
	^ graphObjects size
]

{ #category : 'checks' }
PerfUMateCampaigns class >> checkEqualityOf: a and: b [

	| pair equal |
	"The pair in alphabetical order: Array, Interval and Interval, Array are one finding"
	pair := ', ' join: (Array with: a class name with: b class name) asSortedCollection asArray.
	equal := a = b.
	equal = (b = a) ifFalse: [ self broken: '= is not symmetric (' , pair , ')' ].
	(equal and: [ a hash ~= b hash ]) ifTrue: [ self broken: 'equal objects, different hashes (' , pair , ')' ]
]

{ #category : 'checks' }
PerfUMateCampaigns class >> checkHashing: aBatch [
	"Cost of putting the keys in hashed collections and finding them again"

	| set dictionary |
	set := Set new.
	dictionary := Dictionary new.
	aBatch keys do: [ :key |
		set add: key.
		dictionary at: key put: key ].
	aBatch keys do: [ :key |
		set includes: key.
		dictionary at: key ifAbsent: [ nil ] ].
	^ set size
]

{ #category : 'checks' }
PerfUMateCampaigns class >> checkPrinting: aGraph [
	"Every object prints, and the storeString of every object compiles back to an equal one"

	"Innermost objects first, so a broken part is reported, not every object that holds it"
	(PerfUMateCanonical objectsIn: aGraph) reverseDo: [ :each |
		| store copy |
		each printString.
		store := each storeString.
		copy := [ Smalltalk compiler evaluate: store ]
			        on: Error
			        do: [ :error | error return: #perfumateDoesNotCompile ].
		copy == #perfumateDoesNotCompile ifTrue: [ self broken: 'storeString does not compile (' , each class name , ')' ].
		"Identity collections cannot survive a storeString: the compiler shares equal literals"
		((self holdsIdentityCollection: each) not and: [
			 (PerfUMateCanonical describe: copy) ~= (PerfUMateCanonical describe: each) ]) ifTrue: [
			self broken: 'storeString gives another object (' , each class name , ')' ] ].
	^ aGraph
]

{ #category : 'checks' }
PerfUMateCampaigns class >> holdsIdentityCollection: anObject [

	^ (PerfUMateGraphWalker on: anObject) objects anySatisfy: [ :each |
		  (each isKindOf: IdentitySet) or: [ each isKindOf: IdentityDictionary ] ]
]

{ #category : 'checks' }
PerfUMateCampaigns class >> checkRoundTrip: aGraph through: aBlock [
	"aBlock writes and reads a graph back: the result means the same and its hashed collections work"

	| copy |
	copy := aBlock value: aGraph.
	(PerfUMateCanonical describe: copy) = (PerfUMateCanonical describe: aGraph) ifFalse: [
		self broken: 'round trip changes the graph' ].
	(PerfUMateCanonical problemIn: copy) ifNotNil: [ :problem |
		self broken: 'after the round trip, ' , (problem copyUpTo: $ ) , ' loses elements' ].
	^ copy
]

{ #category : 'campaigns' }
PerfUMateCampaigns class >> copying [
	"Termo: graphcopy"

	^ PerfUMate new
		  name: 'copying';
		  examples: PerfUMateGraphExamples boxes;
		  benchmark: [ :graph | PerfUMateCampaigns checkCopies: graph ];
		  lookFor: #errors;
		  instrument: { 'PerfUMate-Campaigns' };
		  maxElements: 64;
		  yourself
]

{ #category : 'campaigns' }
PerfUMateCampaigns class >> equality [
	"Termo: graphequal"

	^ PerfUMate new
		  name: 'equality';
		  examples: PerfUMateGraphExamples boxes;
		  benchmark: [ :graph | PerfUMateCampaigns checkEquality: graph ];
		  lookFor: #errors;
		  instrument: { 'PerfUMate-Campaigns' };
		  maxElements: 64;
		  yourself
]

{ #category : 'campaigns' }
PerfUMateCampaigns class >> fuel [
	"Termo: graphfuel"

	^ PerfUMate new
		  name: 'fuel';
		  examples: PerfUMateGraphExamples boxes;
		  benchmark: [ :graph |
			  PerfUMateCampaigns checkRoundTrip: graph through: [ :g |
					  FLMaterializer materializeFromByteArray: (FLSerializer serializeToByteArray: g) ] ];
		  lookFor: #errors;
		  instrument: { 'Fuel-Core' };
		  maxElements: 64;
		  yourself
]

{ #category : 'campaigns' }
PerfUMateCampaigns class >> hashing [
	"Termo performance hunt: hash-ints. Keys are wrapped in PerfUMateKey, so the probes of the
	hashed collections (hash and = of the keys) can be counted without instrumenting the kernel"

	^ PerfUMate new
		  name: 'hashing';
		  examples: PerfUMateGraphExamples keyBatches;
		  benchmark: [ :batch | PerfUMateCampaigns checkHashing: batch ];
		  measure: #methodCalls;
		  instrument: {
				  (PerfUMateKey >> #hash).
				  (PerfUMateKey >> #=) };
		  yourself
]

{ #category : 'campaigns' }
PerfUMateCampaigns class >> printing [
	"Termo: graphprint"

	^ PerfUMate new
		  name: 'printing';
		  examples: PerfUMateGraphExamples boxes;
		  benchmark: [ :graph | PerfUMateCampaigns checkPrinting: graph ];
		  lookFor: #errors;
		  instrument: { 'PerfUMate-Campaigns' };
		  maxElements: 64;
		  yourself
]

{ #category : 'checks' }
PerfUMateCampaigns class >> relatedValues [
	"Values of related classes that should compare across classes"

	^ {
		  1. 1.0. (1 / 2). 0.5. 0.5s1. (1 to: 3). #( 1 2 3 ). (OrderedCollection withAll: #( 1 2 3 )).
		  'abc'. #abc. 'abc' asWideString. #[ 97 ]. 'a'. (1 -> 2). (1 @ 2). (Set withAll: #( 1 2 )).
		  (IdentitySet withAll: #( 1 2 )). (Bag withAll: #( 1 2 )) }
]

{ #category : 'campaigns' }
PerfUMateCampaigns class >> ston [
	"Termo: graphston"

	^ PerfUMate new
		  name: 'ston';
		  examples: PerfUMateGraphExamples boxes;
		  benchmark: [ :graph |
			  PerfUMateCampaigns checkRoundTrip: graph through: [ :g | STON fromString: (STON toString: g) ] ];
		  lookFor: #errors;
		  instrument: { 'STON-Core' };
		  maxElements: 64;
		  yourself
]
