"
What a PerfUMate run answers.

	report findings.      report slowInputs.      report errors.
	report trace.         ""every run of the search: time, outcome, size, mutator""
	report grammar.       ""the grammar the campaign used""
	report charts.        ""the Roassal charts of the inspector tabs""
	report testSource.    ""an SUnit class reproducing every finding""
	report generateTestsIn: #CheckoutFuzzTest package: 'MyShop-Tests'.
	report saveTo: 'perfumate-out'.
	PerfUMateReport fromFolder: 'perfumate-out' name: 'checkout'.
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
		'elapsed',
		'trace',
		'name',
		'slowdown',
		'savedTests'
	],
	#category : 'PerfUMate-Report',
	#package : 'PerfUMate',
	#tag : 'Report'
}

{ #category : 'saving' }
PerfUMateReport class >> fromFolder: aDirectoryName name: aName [
	"A report saved with #saveTo:, back: findings, trace, grammar and tests, to inspect and chart
	again (for example the artifact of a CI run)"

	| saved |
	saved := STON fromString: (aDirectoryName asFileReference / (aName , '.ston')) contents.
	^ self new setSaved: saved
]

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

{ #category : 'printing' }
PerfUMateReport >> elapsedString [
	"'48 s', '1 min', '5 min 12 s'"

	| seconds |
	seconds := elapsed asSeconds rounded.
	seconds < 60 ifTrue: [ ^ seconds printString , ' s' ].
	^ String streamContents: [ :stream |
		  stream print: seconds // 60; nextPutAll: ' min'.
		  seconds \\ 60 > 0 ifTrue: [ stream space; print: seconds \\ 60; nextPutAll: ' s' ] ]
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
PerfUMateReport >> inspectionFindings: aBuilder [

	<inspectorPresentationOrder: 0 title: 'Findings'>
	^ aBuilder newTable
		  addStyle: 'stList';
		  items: findings asArray;
		  addColumn: ((SpStringTableColumn title: 'Kind' evaluated: [ :finding |
				    finding isError
					    ifTrue: [ 'error' ]
					    ifFalse: [ 'slow input' ] ])
				   width: 80;
				   yourself);
		  addColumn: ((SpStringTableColumn title: 'Finding' evaluated: [ :finding | finding summary ])
				   width: 600;
				   yourself);
		  addColumn: (SpStringTableColumn title: 'Minimized input' evaluated: [ :finding | finding minimizedSton ]);
		  yourself
]

{ #category : 'inspecting' }
PerfUMateReport >> charts [

	^ PerfUMateCharts on: self
]

{ #category : 'inspecting' }
PerfUMateReport >> inspectionBugs: aBuilder [

	<inspectorPresentationOrder: 2 title: 'Bugs'>
	^ aBuilder newRoassal
		  canvas: self charts bugsCanvas;
		  yourself
]

{ #category : 'inspecting' }
PerfUMateReport >> inspectionCampaign: aBuilder [

	<inspectorPresentationOrder: 1 title: 'Campaign'>
	^ aBuilder newRoassal
		  canvas: self charts campaignCanvas;
		  yourself
]

{ #category : 'inspecting' }
PerfUMateReport >> inspectionGrammarHits: aBuilder [

	<inspectorPresentationOrder: 4 title: 'Grammar hits'>
	^ aBuilder newRoassal
		  canvas: self charts grammarCanvas;
		  yourself
]

{ #category : 'inspecting' }
PerfUMateReport >> inspectionMutators: aBuilder [

	<inspectorPresentationOrder: 3 title: 'Mutators'>
	^ aBuilder newRoassal
		  canvas: self charts mutatorsCanvas;
		  yourself
]

{ #category : 'inspecting' }
PerfUMateReport >> inspectionGrammar: aBuilder [

	<inspectorPresentationOrder: 6 title: 'Grammar'>
	^ aBuilder newCode
		  withoutSyntaxHighlight;
		  text: (grammar mateDefinition copyReplaceAll: String lf with: String cr);
		  beNotEditable;
		  yourself
]

{ #category : 'inspecting' }
PerfUMateReport >> inspectionTests: aBuilder [

	<inspectorPresentationOrder: 5 title: 'Tests'>
	^ aBuilder newCode
		  text: self testSource;
		  beForScripting;
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
		nextPutAll: self elapsedString
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

{ #category : 'saving' }
PerfUMateReport >> saveTo: aDirectoryName [
	"Write into aDirectoryName, under the campaign's name:
	- <name>.md: the summary, with the minimized inputs;
	- <name>-tests.st: the generated test methods;
	- <name>-trace.csv: one row per run of the search;
	- <name>.ston: the whole report, to load back with #fromFolder:name:;
	- <name>-campaign.png, -bugs.png, -mutators.png, -grammar.png: the charts;
	- <name>.html: one page with the findings, the charts, the tests and the grammar.
	Several campaigns can share the directory"

	| directory charts |
	directory := aDirectoryName asFileReference.
	directory ensureCreateDirectory.
	(directory / (self name , '.md')) ensureDelete; writeStreamDo: [ :stream | stream nextPutAll: self summary ].
	(directory / (self name , '-tests.st')) ensureDelete; writeStreamDo: [ :stream |
		stream nextPutAll: (self testSource copyReplaceAll: String cr with: String lf) ].
	(directory / (self name , '-trace.csv')) ensureDelete; writeStreamDo: [ :stream | self trace writeCsvOn: stream ].
	(directory / (self name , '.ston')) ensureDelete; writeStreamDo: [ :stream |
		STON put: self savedDictionary onStreamPretty: stream ].
	charts := self writeChartsTo: directory.
	(directory / (self name , '.html')) ensureDelete; writeStreamDo: [ :stream | self writeHtmlOn: stream charts: charts ].
	^ directory
]

{ #category : 'saving' }
PerfUMateReport >> writeChartsTo: aDirectory [
	"The charts of the inspector tabs as PNG files, <name>-campaign.png and so on, drawn with the
	current theme. Answers the files written; a chart that cannot be drawn is skipped"

	| files |
	files := OrderedCollection new.
	#( #campaignCanvas 'campaign' #bugsCanvas 'bugs' #mutatorsCanvas 'mutators' #grammarCanvas 'grammar' )
		pairsDo: [ :selector :suffix |
			| file |
			file := aDirectory / (self name , '-' , suffix , '.png').
			[
			| canvas morph content extent |
			canvas := self charts
				          beStatic;
				          perform: selector.
			"The image takes the shape of the charts, 1200 pixels wide"
			content := canvas encompassingRectangle.
			extent := 1200 @ (1200 * content height / (content width max: 1) + 24) rounded.
			morph := canvas createMorph.
			morph extent: extent.
			canvas extent: extent.
			canvas camera zoomToFit: extent * 0.97.
			file ensureDelete.
			file binaryWriteStreamDo: [ :out | PNGReadWriter putForm: morph imageForm onStream: out ].
			files add: file ]
				on: Error
				do: [ :error | error return: nil ] ].
	^ files
]

{ #category : 'saving' }
PerfUMateReport >> htmlColor: aColor [
	"#rrggbb"

	^ String streamContents: [ :stream |
		  stream nextPut: $#.
		  { aColor red. aColor green. aColor blue } do: [ :component |
			  | hex |
			  hex := ((component * 255) rounded printStringBase: 16) asLowercase.
			  hex size < 2 ifTrue: [ stream nextPut: $0 ].
			  stream nextPutAll: hex ] ]
]

{ #category : 'saving' }
PerfUMateReport >> writeHtmlOn: aStream charts: someFiles [
	"One self-contained page: findings, charts (embedded), generated tests and grammar"

	| escape theme |
	escape := [ :text |
	          (((text asString copyReplaceAll: '&' with: '&amp;') copyReplaceAll: '<' with: '&lt;')
		           copyReplaceAll: '>'
		           with: '&gt;') copyReplaceAll: String cr with: String lf ].
	theme := Smalltalk ui theme.
	aStream
		nextPutAll: '<!doctype html><html lang="en"><head><meta charset="utf-8">'; lf;
		nextPutAll: '<meta name="viewport" content="width=device-width, initial-scale=1">'; lf;
		nextPutAll: '<title>PerfUMate: '; nextPutAll: (escape value: self name); nextPutAll: '</title>'; lf;
		nextPutAll: '<style>body{font-family:-apple-system,"Segoe UI",Helvetica,Arial,sans-serif;background:';
		nextPutAll: (self htmlColor: theme backgroundColor);
		nextPutAll: ';color:'; nextPutAll: (self htmlColor: theme textColor);
		nextPutAll: ';max-width:1100px;margin:24px auto;padding:0 16px;line-height:1.45}';
		nextPutAll: 'table{border-collapse:collapse;width:100%;table-layout:fixed}th:nth-child(1){width:10%}th:nth-child(2){width:40%}td,th{border-bottom:1px solid rgba(128,128,128,.3);padding:6px 8px;text-align:left;vertical-align:top}';
		nextPutAll: 'code,pre{font-family:SFMono-Regular,Menlo,Consolas,monospace;font-size:12px}pre{white-space:pre-wrap;word-break:break-all;background:rgba(128,128,128,.12);padding:12px;border-radius:6px}';
		nextPutAll: 'img{max-width:100%;display:block;margin:12px 0}.muted{opacity:.7}code{word-break:break-all}</style></head><body>'; lf;
		nextPutAll: '<h1>PerfUMate: '; nextPutAll: (escape value: self name); nextPutAll: '</h1>'; lf;
		nextPutAll: '<p class="muted">'; nextPutAll: (escape value: self printString); nextPutAll: '</p>'; lf;
		nextPutAll: '<h2>Findings</h2>'; lf.
	findings isEmpty
		ifTrue: [ aStream nextPutAll: '<p>No findings.</p>'; lf ]
		ifFalse: [
			aStream nextPutAll: '<table><tr><th>Kind</th><th>Finding</th><th>Minimized input</th></tr>'; lf.
			findings do: [ :finding |
				aStream
					nextPutAll: '<tr><td>'; nextPutAll: (finding isError ifTrue: [ 'error' ] ifFalse: [ 'slow input' ]);
					nextPutAll: '</td><td>'; nextPutAll: (escape value: finding summary);
					nextPutAll: '</td><td><code>'; nextPutAll: (escape value: finding minimizedSton);
					nextPutAll: '</code></td></tr>'; lf ].
			aStream nextPutAll: '</table>'; lf ].
	someFiles ifNotEmpty: [
		aStream nextPutAll: '<h2>Charts</h2>'; lf.
		someFiles do: [ :file |
			aStream
				nextPutAll: '<img alt="'; nextPutAll: file basenameWithoutExtension;
				nextPutAll: '" src="data:image/png;base64,';
				nextPutAll: (file binaryReadStreamDo: [ :in | in upToEnd ]) base64Encoded;
				nextPutAll: '">'; lf ] ].
	aStream
		nextPutAll: '<h2>Generated tests</h2><pre>'; nextPutAll: (escape value: self testSource); nextPutAll: '</pre>'; lf;
		nextPutAll: '<h2>Grammar</h2><pre>'; nextPutAll: (escape value: grammar mateDefinition); nextPutAll: '</pre>'; lf;
		nextPutAll: '</body></html>'; lf
]

{ #category : 'saving' }
PerfUMateReport >> savedDictionary [

	findings do: [ :finding | finding prepareForSaving ].
	self trace prepareForSaving.
	^ OrderedDictionary new
		  at: #name put: self name;
		  at: #elapsedMilliseconds put: elapsed asMilliSeconds;
		  at: #baselineMicroseconds put: baselineMicroseconds;
		  at: #slowdown put: self slowdown;
		  at: #grammar put: grammar mateDefinition;
		  at: #referenceExample put: ([ STON toString: referenceExample ]
				   on: Error
				   do: [ :error | error return: nil ]);
		  at: #findings put: findings;
		  at: #trace put: self trace;
		  at: #tests put: self testSource;
		  yourself
]

{ #category : 'initialization' }
PerfUMateReport >> setSaved: aDictionary [

	name := aDictionary at: #name.
	elapsed := Duration milliSeconds: (aDictionary at: #elapsedMilliseconds).
	baselineMicroseconds := aDictionary at: #baselineMicroseconds.
	slowdown := aDictionary at: #slowdown.
	grammar := PerfUMate grammarFromSource: (aDictionary at: #grammar).
	referenceExample := PerfUMateFinding parse: (aDictionary at: #referenceExample).
	findings := (aDictionary at: #findings) asArray.
	trace := aDictionary at: #trace.
	savedTests := aDictionary at: #tests
]

{ #category : 'accessing' }
PerfUMateReport >> name [

	^ configuration
		  ifNil: [ name ]
		  ifNotNil: [ configuration name ]
]

{ #category : 'accessing' }
PerfUMateReport >> slowdown [

	^ configuration
		  ifNil: [ slowdown ]
		  ifNotNil: [ configuration slowdown ]
]

{ #category : 'accessing' }
PerfUMateReport >> trace [
	"Every run of the search (PerfUMateTrace)"

	^ trace ifNil: [ trace := PerfUMateTrace new ]
]

{ #category : 'accessing' }
PerfUMateReport >> trace: aPerfUMateTrace [

	trace := aPerfUMateTrace
]

{ #category : 'accessing' }
PerfUMateReport >> slowInputs [

	^ findings select: [ :finding | finding isSlowInput ]
]

{ #category : 'printing' }
PerfUMateReport >> summary [
	"Markdown, for CI logs and artifacts"

	^ String streamContents: [ :stream |
		  stream
			  nextPutAll: '# PerfUMate: ';
			  nextPutAll: self name;
			  lf;
			  lf;
			  print: self;
			  lf;
			  lf.
		  findings isEmpty ifTrue: [ stream nextPutAll: 'No findings.'; lf ].
		  findings withIndexDo: [ :finding :index |
			  stream
				  print: index;
				  nextPutAll: '. ';
				  nextPutAll: finding summary;
				  lf;
				  lf;
				  nextPutAll: '    ';
				  nextPutAll: finding minimizedSton;
				  lf;
				  lf ] ]
]

{ #category : 'test generation' }
PerfUMateReport >> benchmarkMethodSource [

	^ String streamContents: [ :stream |
		  stream
			  nextPutAll: 'perfumateBenchmark';
			  cr;
			  tab.
		  configuration benchmark sourceForTests
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
	sources add: self benchmarkMethodSource.
	sources add: 'perfumateReferenceInput
	^ STON fromString: ' , (STON toString: referenceExample) printString.
	findings withIndexDo: [ :finding :index |
		sources add: (finding
				 testMethodSourceNamed: 'testPerfUMate' , (index printPaddedWith: $0 to: 2) , (finding isError
						  ifTrue: [ 'Error' ]
						  ifFalse: [ 'SlowInput' ])
				 slowdown: self slowdown) ].
	^ sources
]

{ #category : 'test generation' }
PerfUMateReport >> testSource [
	"A report loaded from a folder keeps the tests it was saved with"

	savedTests ifNotNil: [ ^ savedTests ].
	^ String streamContents: [ :stream |
		  self testMethodSources
			  do: [ :source | stream nextPutAll: source ]
			  separatedBy: [
				  stream
					  cr;
					  cr ] ]
]
