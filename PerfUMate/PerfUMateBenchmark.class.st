"
I wrap the code under test. Ume calls #runOn: with a PerfUMateInput; PerfUMate times me and
checks my errors directly (#medianMicrosecondsOn:runs:, #errorSignatureOn:).

Every run is bounded by a timeout: an input that does not finish is the slowest input of all.
"
Class {
	#name : 'PerfUMateBenchmark',
	#superclass : 'Object',
	#instVars : [
		'block',
		'receiver',
		'selector',
		'timeout',
		'trace'
	],
	#category : 'PerfUMate-Core',
	#package : 'PerfUMate',
	#tag : 'Core'
}

{ #category : 'instance creation' }
PerfUMateBenchmark class >> block: aBlock [

	^ self new setBlock: aBlock
]

{ #category : 'statistics' }
PerfUMateBenchmark class >> median: numbers [

	| sorted |
	sorted := numbers asSortedCollection asArray.
	^ sorted at: sorted size + 1 // 2
]

{ #category : 'statistics' }
PerfUMateBenchmark class >> microsecondsToRun: aBlock [

	| start |
	start := Time microsecondClockValue.
	aBlock value.
	^ Time microsecondClockValue - start
]

{ #category : 'instance creation' }
PerfUMateBenchmark class >> receiver: anObject selector: aSelector [

	^ self new setReceiver: anObject selector: aSelector
]

{ #category : 'accessing' }
PerfUMateBenchmark >> block [

	^ block
]

{ #category : 'copying' }
PerfUMateBenchmark >> deepCopy [
	"I am configuration, not state: Ume copies every receiver it runs, I can be shared"

	^ self
]

{ #category : 'running' }
PerfUMateBenchmark >> errorSignatureOn: aGraph [
	"nil when aGraph runs fine, else what went wrong (class and signaling method)"

	^ [
	  self valueWith: aGraph veryDeepCopy.
	  nil ]
		  on: Error
		  do: [ :error | error return: (PerfUMateErrorSignature of: error) ]
]

{ #category : 'private' }
PerfUMateBenchmark >> isSelfContained: aBlockNode [

	block numCopiedValues > 0 ifTrue: [ ^ false ].
	^ aBlockNode allChildren noneSatisfy: [ :each |
		  each isVariable and: [
			  each isSelfVariable or: [
				  each isSuperVariable or: [ each isInstanceVariable or: [ each isThisContextVariable ] ] ] ] ]
]

{ #category : 'running' }
PerfUMateBenchmark >> medianMicrosecondsOn: aGraph runs: count [
	"nil if aGraph raises an error"

	| times |
	times := (1 to: count) collect: [ :i | self microsecondsOn: aGraph ].
	(times includes: nil) ifTrue: [ ^ nil ].
	^ self class median: times
]

{ #category : 'instrumentation' }
PerfUMateBenchmark >> methodsIn: aMethodClassOrPackageName [

	aMethodClassOrPackageName isCompiledMethod ifTrue: [ ^ { aMethodClassOrPackageName } ].
	aMethodClassOrPackageName isBehavior ifTrue: [
		^ aMethodClassOrPackageName methods , aMethodClassOrPackageName class methods ].
	^ (self packageOrganizer packageNamed: aMethodClassOrPackageName) methods reject: [ :method |
		  method methodClass inheritsFrom: TestCase ]
]

{ #category : 'instrumentation' }
PerfUMateBenchmark >> classesReferencedBy: aCompiledCode into: aSet [

	aCompiledCode literals do: [ :literal |
		(literal isVariableBinding and: [ literal value isBehavior ]) ifTrue: [ aSet add: literal value ].
		literal isCompiledBlock ifTrue: [ self classesReferencedBy: literal into: aSet ] ].
	^ aSet
]

{ #category : 'instrumentation' }
PerfUMateBenchmark >> isSystemPackage: aPackage [
	"Never instrument these: instrumenting Kernel or Collections would instrument everything the
	image runs"

	| packageName |
	aPackage ifNil: [ ^ true ].
	packageName := aPackage name.
	(#( 'PerfUMate' 'Ume' 'Mate' 'Shin' 'Coverage2' ) includes: packageName) ifTrue: [ ^ true ].
	^ #( 'Kernel' 'Collections' 'System' 'Announcements' 'Text' 'Files' 'FileSystem' 'Zinc' 'STON'
	     'OpalCompiler' 'AST' 'Debugging' 'Morphic' 'Spec' 'UndefinedObject' ) anySatisfy: [ :prefix |
		  packageName beginsWith: prefix ]
]

{ #category : 'instrumentation' }
PerfUMateBenchmark >> methodsToInstrumentIn: someMethodsClassesOrPackageNames [
	"The given methods, classes and packages. Else: the method behind receiver/selector and what
	it sends in its package, or the packages of the classes the benchmark block references (not
	the package where the block was written, which for a Playground is Kernel's)"

	| packages |
	someMethodsClassesOrPackageNames isEmptyOrNil ifFalse: [
		^ (someMethodsClassesOrPackageNames flatCollect: [ :each | self methodsIn: each ]) asSet asArray ].
	selector ifNotNil: [
		^ (receiver class lookupSelector: selector)
			  ifNil: [ { PerfUMateBenchmark >> #runOn: } ]
			  ifNotNil: [ :method | method sendReachableMethods asArray ] ].
	packages := ((self classesReferencedBy: block compiledBlock into: Set new) collect: [ :class |
		             class package ]) reject: [ :package | self isSystemPackage: package ].
	packages ifEmpty: [ ^ { PerfUMateBenchmark >> #runOn: } ].
	^ (packages flatCollect: [ :package | package methods ]) asArray reject: [ :method |
		  method methodClass inheritsFrom: TestCase ]
]

{ #category : 'running' }
PerfUMateBenchmark >> microsecondsOn: aGraph [
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
PerfUMateBenchmark >> runOn: anInput [
	"The method Ume's schema calls. During a campaign every run is recorded in the trace"

	| objects start |
	trace ifNil: [ ^ self valueWith: anInput graph ].
	objects := trace objectCountOf: anInput graph.
	start := Time microsecondClockValue.
	^ [
	  | result |
	  result := self valueWith: anInput graph.
	  trace record: Time microsecondClockValue - start outcome: #ok error: nil objects: objects.
	  result ]
		  on: Error
		  do: [ :error |
			  trace
				  record: Time microsecondClockValue - start
				  outcome: ((error isKindOf: PerfUMateTimeout)
						   ifTrue: [ #timeout ]
						   ifFalse: [ #error ])
				  error: error class name
				  objects: objects.
			  error pass ]
]

{ #category : 'accessing' }
PerfUMateBenchmark >> trace: aPerfUMateTraceOrNil [

	trace := aPerfUMateTraceOrNil
]

{ #category : 'initialization' }
PerfUMateBenchmark >> setBlock: aBlock [

	block := aBlock
]

{ #category : 'initialization' }
PerfUMateBenchmark >> setReceiver: anObject selector: aSelector [

	receiver := anObject.
	selector := aSelector.
	block := [ :input | anObject perform: aSelector with: input ]
]

{ #category : 'running' }
PerfUMateBenchmark >> singleRunMicrosecondsOn: aGraph [

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
PerfUMateBenchmark >> sourceForTests [
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
PerfUMateBenchmark >> timeout [

	^ timeout ifNil: [ 2 seconds ]
]

{ #category : 'accessing' }
PerfUMateBenchmark >> timeout: aDuration [

	timeout := aDuration
]

{ #category : 'running' }
PerfUMateBenchmark >> valueWith: aGraph [

	^ [ block value: aGraph ]
		  valueWithin: self timeout
		  onTimeout: [ PerfUMateTimeout new signal: 'Did not finish within ' , self timeout printString ]
]

{ #category : 'copying' }
PerfUMateBenchmark >> veryDeepCopyWith: aDeepCopier [

	^ self
]
