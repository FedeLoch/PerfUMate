"
Every run of the benchmark during the search, recorded by PerfUMateBenchmark >> #runOn:. The
report's charts are drawn from it.
"
Class {
	#name : 'PerfUMateTrace',
	#superclass : 'Object',
	#instVars : [
		'runs',
		'corpus'
	],
	#category : 'PerfUMate-Report',
	#package : 'PerfUMate',
	#tag : 'Report'
}

{ #category : 'accessing' }
PerfUMateTrace >> corpus: aUmeCorpusGenerator [

	corpus := aUmeCorpusGenerator
]

{ #category : 'private' }
PerfUMateTrace >> currentMutatorLabel [

	| mutator |
	mutator := corpus ifNotNil: [ corpus lastSelectedMutator ].
	mutator ifNil: [ ^ 'example' ].
	^ (mutator respondsTo: #label)
		  ifTrue: [ mutator label ]
		  ifFalse: [ mutator class name ]
]

{ #category : 'initialization' }
PerfUMateTrace >> initialize [

	super initialize.
	runs := OrderedCollection new
]

{ #category : 'recording' }
PerfUMateTrace >> markLastAsRecordWith: aGraphOrNil [

	runs ifNotEmpty: [ runs last beRecordWith: aGraphOrNil ]
]

{ #category : 'statistics' }
PerfUMateTrace >> mutatorProbabilities [
	"label -> selection probability, when the selector exposes them (MOpt does)"

	| selector weights mutators |
	corpus ifNil: [ ^ Dictionary new ].
	selector := corpus instVarNamed: #mutatorSelector.
	weights := [ selector mutatorWeights ]
		           on: Error
		           do: [ :error | error return: nil ].
	mutators := corpus mutators.
	(weights isNil or: [ weights size ~= mutators size ]) ifTrue: [ ^ Dictionary new ].
	^ (mutators with: weights collect: [ :mutator :weight |
		   ((mutator respondsTo: #label)
			    ifTrue: [ mutator label ]
			    ifFalse: [ mutator class name ]) -> weight ]) asDictionary
]

{ #category : 'statistics' }
PerfUMateTrace >> mutatorStatistics [
	"label -> { runs. records }, in the order the mutators first ran"

	| statistics |
	statistics := OrderedDictionary new.
	runs do: [ :run |
		| counts |
		counts := statistics at: run mutator ifAbsentPut: [ Array with: 0 with: 0 ].
		counts at: 1 put: (counts at: 1) + 1.
		run isRecord ifTrue: [ counts at: 2 put: (counts at: 2) + 1 ] ].
	^ statistics
]

{ #category : 'recording' }
PerfUMateTrace >> objectCountOf: aGraph [

	^ [ (PerfUMateGraphWalker on: aGraph) objectCount ]
		  on: Error
		  do: [ :error | error return: 0 ]
]

{ #category : 'recording' }
PerfUMateTrace >> record: aNumber outcome: aSymbol error: aClassName objects: aCount [

	runs add: (PerfUMateRun new
			 setIndex: runs size + 1
			 microseconds: aNumber
			 outcome: aSymbol
			 error: aClassName
			 mutator: self currentMutatorLabel
			 objects: aCount)
]

{ #category : 'accessing' }
PerfUMateTrace >> records [

	^ runs select: [ :run | run isRecord ]
]

{ #category : 'accessing' }
PerfUMateTrace >> runs [

	^ runs
]
