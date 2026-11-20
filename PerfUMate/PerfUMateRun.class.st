"
One execution of the benchmark during the search: how long it took, how it ended, which mutator
produced its input, and whether it set a record (positive feedback).
"
Class {
	#name : 'PerfUMateRun',
	#superclass : 'Object',
	#instVars : [
		'index',
		'microseconds',
		'outcome',
		'errorClassName',
		'mutator',
		'objects',
		'isRecord',
		'input',
		'inputText'
	],
	#category : 'PerfUMate-Report',
	#package : 'PerfUMate',
	#tag : 'Report'
}

{ #category : 'ston' }
PerfUMateRun class >> stonAllInstVarNames [
	"The input is saved as text (see #prepareForSaving)"

	^ super stonAllInstVarNames copyWithout: #input
]

{ #category : 'accessing' }
PerfUMateRun >> beRecordWith: aGraphOrNil [
	"Only the inputs of records are kept, to keep the trace small"

	isRecord := true.
	input := aGraphOrNil
]

{ #category : 'accessing' }
PerfUMateRun >> input [
	"A run loaded from a saved report parses its input on demand"

	input ifNil: [ input := PerfUMateFinding parse: inputText ].
	^ input
]

{ #category : 'saving' }
PerfUMateRun >> prepareForSaving [

	input ifNotNil: [
		inputText := [ STON toString: input ]
			             on: Error
			             do: [ :error | error return: nil ] ]
]

{ #category : 'accessing' }
PerfUMateRun >> errorClassName [

	^ errorClassName
]

{ #category : 'accessing' }
PerfUMateRun >> index [

	^ index
]

{ #category : 'testing' }
PerfUMateRun >> isError [

	^ outcome = #error
]

{ #category : 'testing' }
PerfUMateRun >> isRecord [

	^ isRecord
]

{ #category : 'testing' }
PerfUMateRun >> isTimeout [

	^ outcome = #timeout
]

{ #category : 'accessing' }
PerfUMateRun >> microseconds [

	^ microseconds
]

{ #category : 'accessing' }
PerfUMateRun >> mutator [

	^ mutator
]

{ #category : 'accessing' }
PerfUMateRun >> objects [

	^ objects
]

{ #category : 'accessing' }
PerfUMateRun >> outcome [

	^ outcome
]

{ #category : 'initialization' }
PerfUMateRun >> setIndex: anInteger microseconds: aNumber outcome: aSymbol error: aClassName mutator: aString objects: aCount [

	index := anInteger.
	microseconds := aNumber.
	outcome := aSymbol.
	errorClassName := aClassName.
	mutator := aString.
	objects := aCount.
	isRecord := false
]
