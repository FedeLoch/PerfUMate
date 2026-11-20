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
		'baselineMicroseconds',
		'originalText',
		'minimizedText'
	],
	#category : 'PerfUMate-Report',
	#package : 'PerfUMate',
	#tag : 'Report'
}

{ #category : 'saving' }
PerfUMateFinding class >> parse: aStonStringOrNil [
	"nil when the text is missing or STON cannot read it"

	aStonStringOrNil ifNil: [ ^ nil ].
	^ [ STON fromString: aStonStringOrNil ]
		  on: Error
		  do: [ :error | error return: nil ]
]

{ #category : 'ston' }
PerfUMateFinding class >> stonAllInstVarNames [
	"The inputs are saved as text (see #prepareForSaving)"

	^ super stonAllInstVarNames copyWithoutAll: #( #original #minimized )
]

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
	"A finding loaded from a saved report parses its input on demand"

	minimized ifNil: [ minimized := self class parse: minimizedText ].
	^ minimized
]

{ #category : 'accessing' }
PerfUMateFinding >> minimizedSton [

	^ minimizedText ifNil: [ STON toString: minimized ]
]

{ #category : 'accessing' }
PerfUMateFinding >> original [

	original ifNil: [ original := self class parse: originalText ].
	^ original
]

{ #category : 'saving' }
PerfUMateFinding >> prepareForSaving [
	"Saved reports keep the inputs as STON text: an input that STON cannot read back (a finding
	about STON, say) then costs that input, not the whole report"

	originalText := [ STON toString: original ]
		                on: Error
		                do: [ :error | error return: nil ].
	minimizedText := [ STON toString: minimized ]
		                 on: Error
		                 do: [ :error | error return: nil ]
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
				  stream print: signature.
				  "A broken invariant's label is already in its signature"
				  (signature messageText notEmpty and: [ (signature location includesSubstring: signature messageText) not ]) ifTrue: [
					  | text |
					  text := signature messageText.
					  stream
						  nextPutAll: ': ';
						  nextPutAll: text ] ].
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
