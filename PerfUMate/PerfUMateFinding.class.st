"
One confirmed problem: a slow input or an error, with the input the campaign found, its
minimized version (Shin), the rule of the grammar it breaks if any, and either its slowdown
against the median input or its error signature.
"
Class {
	#name : 'PerfUMateFinding',
	#superclass : 'Object',
	#instVars : [
		'kind',
		'original',
		'minimized',
		'isMinimized',
		'brokenRule',
		'signature',
		'microseconds',
		'baselineMicroseconds'
	],
	#category : 'PerfUMate-Report',
	#package : 'PerfUMate',
	#tag : 'Report'
}

{ #category : 'accessing' }
PerfUMateFinding >> baselineMicroseconds [

	^ baselineMicroseconds
]

{ #category : 'accessing' }
PerfUMateFinding >> brokenRule [
	"nil when the minimized input satisfies the grammar"

	^ brokenRule
]

{ #category : 'accessing' }
PerfUMateFinding >> brokenRule: aStringOrNil [

	brokenRule := aStringOrNil
]

{ #category : 'testing' }
PerfUMateFinding >> isError [

	^ kind = #error
]

{ #category : 'accessing' }
PerfUMateFinding >> isMinimized [
	"false when minimization ran out of time"

	^ isMinimized
]

{ #category : 'testing' }
PerfUMateFinding >> isSlowInput [

	^ kind = #slowInput
]

{ #category : 'accessing' }
PerfUMateFinding >> kind [

	^ kind
]

{ #category : 'accessing' }
PerfUMateFinding >> microseconds [

	^ microseconds
]

{ #category : 'initialization' }
PerfUMateFinding >> microseconds: aNumber baseline: aBaseline [

	microseconds := aNumber.
	baselineMicroseconds := aBaseline
]

{ #category : 'accessing' }
PerfUMateFinding >> minimized [

	^ minimized
]

{ #category : 'accessing' }
PerfUMateFinding >> minimizedSton [

	^ STON toString: minimized
]

{ #category : 'accessing' }
PerfUMateFinding >> original [

	^ original
]

{ #category : 'printing' }
PerfUMateFinding >> printOn: aStream [

	aStream nextPutAll: self summary
]

{ #category : 'initialization' }
PerfUMateFinding >> setKind: aSymbol original: anOriginal minimized: aMinimized completely: aBoolean [

	kind := aSymbol.
	original := anOriginal.
	minimized := aMinimized.
	isMinimized := aBoolean
]

{ #category : 'accessing' }
PerfUMateFinding >> signature [

	^ signature
]

{ #category : 'accessing' }
PerfUMateFinding >> signature: anErrorSignature [

	signature := anErrorSignature
]

{ #category : 'accessing' }
PerfUMateFinding >> slowdown [
	"How many times slower than the median input"

	microseconds ifNil: [ ^ nil ].
	^ (microseconds / (baselineMicroseconds max: 1)) asFloat
]

{ #category : 'printing' }
PerfUMateFinding >> summary [

	^ String streamContents: [ :stream |
		  self isSlowInput
			  ifTrue: [
				  stream
					  nextPutAll: (self slowdown printShowingDecimalPlaces: 1);
					  nextPutAll: 'x slower than the median input ('.
				  stream
					  print: microseconds rounded;
					  nextPutAll: ' us vs ';
					  print: baselineMicroseconds rounded;
					  nextPutAll: ' us)' ]
			  ifFalse: [
				  stream
					  print: signature;
					  nextPutAll: ': ';
					  nextPutAll: signature messageText ].
		  brokenRule ifNotNil: [ stream nextPutAll: ' - breaks: ' , brokenRule ].
		  isMinimized ifFalse: [ stream nextPutAll: ' (not fully minimized)' ] ]
]

{ #category : 'test generation' }
PerfUMateFinding >> testMethodSourceNamed: aSelector slowdown: aRatio [

	^ String streamContents: [ :stream |
		  stream
			  nextPutAll: aSelector;
			  cr;
			  tab;
			  nextPut: $";
			  nextPutAll: ('PerfUMate: ' , self summary copyReplaceAll: '"' with: '''');
			  nextPut: $";
			  cr;
			  cr;
			  tab.
		  self isSlowInput
			  ifTrue: [
				  stream
					  nextPutAll: 'self';
					  cr;
					  tab;
					  tab;
					  nextPutAll: 'assertInput: (STON fromString: ';
					  print: self minimizedSton;
					  nextPut: $);
					  cr;
					  tab;
					  tab;
					  nextPutAll: 'isAtMost: ';
					  print: aRatio;
					  cr;
					  tab;
					  tab;
					  nextPutAll: 'timesSlowerThan: self perfumateReferenceInput' ]
			  ifFalse: [
				  stream
					  nextPutAll: 'self assertNoErrorOn: (STON fromString: ';
					  print: self minimizedSton;
					  nextPut: $) ] ]
]
