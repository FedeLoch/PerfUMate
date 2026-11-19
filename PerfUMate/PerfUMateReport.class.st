"
What a PerfUMate run answers.

	report findings.      report slowInputs.      report errors.
	report grammar.       ""the grammar the campaign used""
	report campaign.      ""the UmeResult: plots, CSV export""
	report testSource.    ""an SUnit class reproducing every finding""
	report generateTestsIn: #CheckoutFuzzTest package: 'MyShop-Tests'.
	report open.

The generated tests fail while the problems are there and pass once they are fixed, so they can
be committed and run by CI.
"
Class {
	#name : 'PerfUMateReport',
	#superclass : 'Object',
	#instVars : [
		'configuration',
		'grammar',
		'campaign',
		'findings',
		'baselineMicroseconds',
		'referenceExample',
		'elapsed'
	],
	#category : 'PerfUMate-Report',
	#package : 'PerfUMate',
	#tag : 'Report'
}

{ #category : 'accessing' }
PerfUMateReport >> baselineMicroseconds [

	^ baselineMicroseconds
]

{ #category : 'accessing' }
PerfUMateReport >> campaign [

	^ campaign
]

{ #category : 'accessing' }
PerfUMateReport >> elapsed [

	^ elapsed
]

{ #category : 'accessing' }
PerfUMateReport >> errors [

	^ findings select: [ :finding | finding isError ]
]

{ #category : 'accessing' }
PerfUMateReport >> findings [

	^ findings
]

{ #category : 'test generation' }
PerfUMateReport >> generateTestsIn: aClassName package: aPackageName [
	"Compile a PerfUMateGeneratedTest subclass with one test per finding"

	| testClass |
	testClass := Smalltalk classInstaller make: [ :builder |
		             builder
			             name: aClassName;
			             superclass: PerfUMateGeneratedTest;
			             package: aPackageName ].
	self testMethodSources do: [ :source | testClass compile: source classified: 'perfumate' ].
	^ testClass
]

{ #category : 'accessing' }
PerfUMateReport >> grammar [

	^ grammar
]

{ #category : 'inspecting' }
PerfUMateReport >> inspectionFindings [

	<inspectorPresentationOrder: 0 title: 'Findings'>
	^ SpTablePresenter new
		  items: findings asArray;
		  addColumn: (SpStringTableColumn title: 'Kind' evaluated: [ :finding | finding kind ]);
		  addColumn: (SpStringTableColumn title: 'Finding' evaluated: [ :finding | finding summary ]);
		  addColumn: (SpStringTableColumn title: 'Minimized input' evaluated: [ :finding | finding minimizedSton ]);
		  yourself
]

{ #category : 'inspecting' }
PerfUMateReport >> inspectionGrammar [

	<inspectorPresentationOrder: 2 title: 'Grammar'>
	^ SpTextPresenter new
		  text: grammar mateDefinition;
		  yourself
]

{ #category : 'inspecting' }
PerfUMateReport >> inspectionTests [

	<inspectorPresentationOrder: 1 title: 'Tests'>
	^ SpCodePresenter new
		  text: self testSource;
		  yourself
]

{ #category : 'ui' }
PerfUMateReport >> open [

	^ self inspect
]

{ #category : 'printing' }
PerfUMateReport >> printOn: aStream [

	aStream
		nextPutAll: 'PerfUMate: ';
		print: self slowInputs size;
		nextPutAll: ' slow input(s), ';
		print: self errors size;
		nextPutAll: ' error(s) in ';
		print: elapsed
]

{ #category : 'accessing' }
PerfUMateReport >> referenceExample [
	"The example whose time is closest to the median: generated slow-input tests compare to it"

	^ referenceExample
]

{ #category : 'initialization' }
PerfUMateReport >> setConfiguration: aPerfUMate grammar: aGrammar campaign: aUmeResult findings: someFindings baseline: aNumber reference: anExample elapsed: aDuration [

	configuration := aPerfUMate.
	grammar := aGrammar.
	campaign := aUmeResult.
	findings := someFindings asArray.
	baselineMicroseconds := aNumber.
	referenceExample := anExample.
	elapsed := aDuration
]

{ #category : 'accessing' }
PerfUMateReport >> slowInputs [

	^ findings select: [ :finding | finding isSlowInput ]
]

{ #category : 'test generation' }
PerfUMateReport >> targetMethodSource [

	^ String streamContents: [ :stream |
		  stream
			  nextPutAll: 'perfumateTarget';
			  cr;
			  tab.
		  configuration target sourceForTests
			  ifNil: [
				  stream nextPutAll:
					  '"The campaign block uses variables from its context: return an equivalent block here"
	^ self error: ''Write the code under test as a one-argument block''' ]
			  ifNotNil: [ :source | stream nextPutAll: '^ ' , source ] ]
]

{ #category : 'test generation' }
PerfUMateReport >> testMethodSources [

	| sources |
	sources := OrderedCollection new.
	sources add: self targetMethodSource.
	sources add: 'perfumateReferenceInput
	^ STON fromString: ' , (STON toString: referenceExample) printString.
	findings withIndexDo: [ :finding :index |
		sources add: (finding
				 testMethodSourceNamed: 'testPerfUMate' , (index printPaddedWith: $0 to: 2) , (finding isError
						  ifTrue: [ 'Error' ]
						  ifFalse: [ 'SlowInput' ])
				 slowdown: configuration slowdown) ].
	^ sources
]

{ #category : 'test generation' }
PerfUMateReport >> testSource [

	^ String streamContents: [ :stream |
		  self testMethodSources
			  do: [ :source | stream nextPutAll: source ]
			  separatedBy: [
				  stream
					  cr;
					  cr ] ]
]
