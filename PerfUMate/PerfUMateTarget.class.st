"
I wrap the code under test. Ume calls #runOn: with a PerfUMateInput; PerfUMate times me and
checks my errors directly (#medianMicrosecondsOn:runs:, #errorSignatureOn:).

Every run is bounded by a timeout: an input that does not finish is the slowest input of all.
"
Class {
	#name : 'PerfUMateTarget',
	#superclass : 'Object',
	#instVars : [
		'block',
		'receiver',
		'selector',
		'timeout'
	],
	#category : 'PerfUMate-Core',
	#package : 'PerfUMate',
	#tag : 'Core'
}

{ #category : 'instance creation' }
PerfUMateTarget class >> block: aBlock [

	^ self new setBlock: aBlock
]

{ #category : 'statistics' }
PerfUMateTarget class >> median: numbers [

	| sorted |
	sorted := numbers asSortedCollection asArray.
	^ sorted at: sorted size + 1 // 2
]

{ #category : 'statistics' }
PerfUMateTarget class >> microsecondsToRun: aBlock [

	| start |
	start := Time microsecondClockValue.
	aBlock value.
	^ Time microsecondClockValue - start
]

{ #category : 'instance creation' }
PerfUMateTarget class >> receiver: anObject selector: aSelector [

	^ self new setReceiver: anObject selector: aSelector
]

{ #category : 'accessing' }
PerfUMateTarget >> block [

	^ block
]

{ #category : 'copying' }
PerfUMateTarget >> deepCopy [
	"I am configuration, not state: Ume copies every receiver it runs, I can be shared"

	^ self
]

{ #category : 'running' }
PerfUMateTarget >> errorSignatureOn: aGraph [
	"nil when aGraph runs fine, else what went wrong (class and signaling method)"

	^ [
	  self valueWith: aGraph veryDeepCopy.
	  nil ]
		  on: Error
		  do: [ :error | error return: (PerfUMateErrorSignature of: error) ]
]

{ #category : 'private' }
PerfUMateTarget >> isSelfContained: aBlockNode [

	block numCopiedValues > 0 ifTrue: [ ^ false ].
	^ aBlockNode allChildren noneSatisfy: [ :each |
		  each isVariable and: [
			  each isSelfVariable or: [
				  each isSuperVariable or: [ each isInstanceVariable or: [ each isThisContextVariable ] ] ] ] ]
]

{ #category : 'running' }
PerfUMateTarget >> medianMicrosecondsOn: aGraph runs: count [
	"nil if aGraph raises an error"

	| times |
	times := (1 to: count) collect: [ :i | self microsecondsOn: aGraph ].
	(times includes: nil) ifTrue: [ ^ nil ].
	^ self class median: times
]

{ #category : 'instrumentation' }
PerfUMateTarget >> methodsToInstrumentIn: packageNames [
	"Coverage scope for #errors: the given packages, the method behind receiver/selector, or the
	package where the target block was written"

	| package |
	packageNames isEmptyOrNil ifFalse: [
		^ (packageNames flatCollect: [ :name | (self packageOrganizer packageNamed: name) methods ])
			  reject: [ :method | method methodClass inheritsFrom: TestCase ] ].
	selector ifNotNil: [
		^ (receiver class lookupSelector: selector)
			  ifNil: [ { PerfUMateTarget >> #runOn: } ]
			  ifNotNil: [ :method | method sendReachableMethods ] ].
	package := [ block method package ]
		           on: Error
		           do: [ :error | error return: nil ].
	(package isNil or: [ package name = 'PerfUMate' ]) ifTrue: [ ^ { PerfUMateTarget >> #runOn: } ].
	^ package methods reject: [ :method | method methodClass inheritsFrom: TestCase ]
]

{ #category : 'running' }
PerfUMateTarget >> microsecondsOn: aGraph [
	"Time one run on a private copy. Fast runs are repeated on 20 copies and averaged.
	A timeout counts as the whole timeout, an error answers nil"

	| first copies total |
	first := self singleRunMicrosecondsOn: aGraph.
	(first isNil or: [ first >= 100 ]) ifTrue: [ ^ first ].
	copies := (1 to: 20) collect: [ :i | aGraph veryDeepCopy ].
	total := [ self class microsecondsToRun: [ copies do: [ :each | self valueWith: each ] ] ]
		         on: Error
		         do: [ :error | error return: nil ].
	total ifNil: [ ^ first ].
	^ (total / copies size) asFloat
]

{ #category : 'running' }
PerfUMateTarget >> runOn: anInput [
	"The method Ume's schema calls"

	^ self valueWith: anInput graph
]

{ #category : 'initialization' }
PerfUMateTarget >> setBlock: aBlock [

	block := aBlock
]

{ #category : 'initialization' }
PerfUMateTarget >> setReceiver: anObject selector: aSelector [

	receiver := anObject.
	selector := aSelector.
	block := [ :input | anObject perform: aSelector with: input ]
]

{ #category : 'running' }
PerfUMateTarget >> singleRunMicrosecondsOn: aGraph [

	| copy |
	copy := aGraph veryDeepCopy.
	^ [ self class microsecondsToRun: [ self valueWith: copy ] ]
		  on: Error
		  do: [ :error |
			  error return: ((error isKindOf: PerfUMateTimeout)
					   ifTrue: [ self timeout asMilliSeconds * 1000 ]
					   ifFalse: [ nil ]) ]
]

{ #category : 'test generation' }
PerfUMateTarget >> sourceForTests [
	"Source of a block equivalent to me, or nil when the block uses its context"

	| node |
	selector ifNotNil: [
		^ '[ :input | (STON fromString: ' , (STON toString: receiver) printString , ') perform: #'
		  , selector , ' with: input ]' ].
	node := [ block sourceNode ]
		        on: Error
		        do: [ :error | ^ nil ].
	(self isSelfContained: node) ifFalse: [ ^ nil ].
	^ node sourceCode
]

{ #category : 'accessing' }
PerfUMateTarget >> timeout [

	^ timeout ifNil: [ 2 seconds ]
]

{ #category : 'accessing' }
PerfUMateTarget >> timeout: aDuration [

	timeout := aDuration
]

{ #category : 'running' }
PerfUMateTarget >> valueWith: aGraph [

	^ [ block value: aGraph ]
		  valueWithin: self timeout
		  onTimeout: [ PerfUMateTimeout new signal: 'Did not finish within ' , self timeout printString ]
]

{ #category : 'copying' }
PerfUMateTarget >> veryDeepCopyWith: aDeepCopier [

	^ self
]
