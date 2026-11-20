"
Roassal charts of a PerfUMateReport, shown as tabs of its inspector:

- campaign: time of every run over the search, records in pink, errors and timeouts, and time
  against input size (the shape of that curve is the complexity of the slow path);
- bugs: errors hit during the search by class, and each finding with its size before and
  after minimization;
- mutators: runs and records per mutator, and MOpt's final probabilities;
- grammar: the most generated grammar fields and how much each paid off (Mate's rewards).

Colors come from the current theme, so the charts read in light and dark themes.
"
Class {
	#name : 'PerfUMateCharts',
	#superclass : 'Object',
	#instVars : [
		'report',
		'canvas'
	],
	#category : 'PerfUMate-Report',
	#package : 'PerfUMate',
	#tag : 'Report'
}

{ #category : 'instance creation' }
PerfUMateCharts class >> on: aPerfUMateReport [

	^ self new setReport: aPerfUMateReport
]

{ #category : 'colors' }
PerfUMateCharts >> accent [

	^ Color fromHexString: 'f24379'
]

{ #category : 'drawing' }
PerfUMateCharts >> add: aShape [

	canvas add: aShape.
	^ aShape
]

{ #category : 'drawing' }
PerfUMateCharts >> barRows: rows at: aPoint labelWidth: labelWidth barWidth: barWidth [
	"rows: arrays { label. total. highlighted. detail. popup }. A gray bar for the total, a pink
	bar for the highlighted part. Answers the y below the last row"

	| max y |
	rows isEmpty ifTrue: [
		self text: 'nothing to show' at: aPoint size: 12 color: self muted.
		^ aPoint y + 24 ].
	max := (rows collect: [ :row | row second ]) max max: 1.
	y := aPoint y.
	rows do: [ :row |
		| total highlighted totalWidth box |
		total := row second.
		highlighted := row third min: total.
		totalWidth := (barWidth * total / max) max: 2.
		self textRight: row first at: aPoint x + labelWidth - 10 @ y size: 12 color: self ink.
		box := self box: aPoint x + labelWidth @ (y - 7) extent: totalWidth @ 14 color: self track.
		highlighted > 0 ifTrue: [
			self
				box: aPoint x + labelWidth @ (y - 7)
				extent: ((barWidth * highlighted / max) max: 2) @ 14
				color: self accent ].
		self text: row fourth at: aPoint x + labelWidth + totalWidth + 8 @ y size: 11 color: self muted.
		(row size >= 5 and: [ row fifth notNil ]) ifTrue: [ self popup: row fifth on: box ].
		y := y + 24 ].
	^ y
]

{ #category : 'drawing' }
PerfUMateCharts >> box: aTopLeft extent: anExtent color: aColor [

	^ self add: (RSBox new
			   extent: anExtent;
			   color: aColor;
			   cornerRadius: 2;
			   position: aTopLeft + (anExtent / 2);
			   yourself)
]

{ #category : 'charts' }
PerfUMateCharts >> bugsCanvas [

	| y |
	self newCanvas.
	y := self
		     title: 'Bugs'
		     subtitle: 'Errors the search ran into, and what each finding looked like before and after minimization'.
	y := self section: 'Runs that failed, by error' at: 0 @ y.
	y := self barRows: self errorRows at: 0 @ y labelWidth: 220 barWidth: 420.
	y := self section: 'Findings: objects in the input, found (gray) and minimized (pink)' at: 0 @ (y + 16).
	self barRows: self findingRows at: 0 @ y labelWidth: 220 barWidth: 420.
	^ self finish
]

{ #category : 'charts' }
PerfUMateCharts >> campaignCanvas [

	| y runs |
	self newCanvas.
	runs := report trace runs.
	y := self title: 'Campaign' subtitle: self campaignSummary.
	self section: 'Time of every run' at: 0 @ y.
	self section: 'Time against input size' at: 500 @ y.
	self scatter: runs x: [ :run | run index ] xName: 'run' at: y + 36 left: 52 width: 400.
	self scatter: runs x: [ :run | run objects ] xName: 'objects' at: y + 36 left: 552 width: 400.
	self legendAt: 0 @ (y + 36 + 170 + 44).
	^ self finish
]

{ #category : 'charts' }
PerfUMateCharts >> campaignSummary [

	| runs |
	runs := report trace runs.
	^ String streamContents: [ :stream |
		  stream
			  print: runs size;
			  nextPutAll: ' runs, ';
			  print: (runs count: [ :run | run isRecord ]);
			  nextPutAll: ' records, ';
			  print: (runs count: [ :run | run isError ]);
			  nextPutAll: ' errors, ';
			  print: (runs count: [ :run | run isTimeout ]);
			  nextPutAll: ' timeouts. Median input: ';
			  nextPutAll: (self timeString: report baselineMicroseconds) ]
]

{ #category : 'data' }
PerfUMateCharts >> errorRows [

	| byClass |
	byClass := Dictionary new.
	report trace runs do: [ :run |
		(run isError or: [ run isTimeout ]) ifTrue: [
			| key |
			key := run isTimeout
				       ifTrue: [ 'timeout' ]
				       ifFalse: [ run errorClassName asString ].
			byClass at: key put: (byClass at: key ifAbsent: [ 0 ]) + 1 ] ].
	^ (byClass associations asSortedCollection: [ :a :b | a value >= b value ]) asArray collect: [ :each |
		  {
			  each key asString.
			  each value.
			  each value.
			  (self count: each value of: 'run').
			  nil } ]
]

{ #category : 'data' }
PerfUMateCharts >> findingRows [

	^ report findings withIndexCollect: [ :finding :index |
		  | found minimized |
		  found := self objectCountOf: finding original.
		  minimized := self objectCountOf: finding minimized.
		  {
			  (finding isError
				   ifTrue: [ finding signature errorClassName ]
				   ifFalse: [ 'slow input ' , index printString ]).
			  found.
			  minimized.
			  (found printString , ' -> ' , minimized printString , ' objects' , (finding isSlowInput
				    ifTrue: [ ', ' , (finding slowdown printShowingDecimalPlaces: 1) , 'x slower' ]
				    ifFalse: [ '' ])).
			  finding summary } ]
]

{ #category : 'drawing' }
PerfUMateCharts >> finish [
	"A fixed, invisible frame, so every chart is shown at the same scale"

	| bounds |
	bounds := canvas encompassingRectangle.
	canvas addShape: (RSBox new
			 extent: 1000 @ ((bounds bottom max: 400) + 40);
			 color: Color transparent;
			 position: 1000 @ ((bounds bottom max: 400) + 40) / 2 - (20 @ 30);
			 yourself).
	canvas shapes last pushBack.
	canvas @ RSCanvasController.
	^ canvas
]

{ #category : 'charts' }
PerfUMateCharts >> grammarCanvas [

	| y points maxReward totalReward rows |
	self newCanvas.
	y := self title: 'Grammar' subtitle: 'Where generation spent its time, and which rules the best inputs break'.
	y := self section: 'Most visited grammar points (pink: share of Mate''s reward)' at: 0 @ y.
	points := (self grammarPoints asSortedCollection: [ :a :b | a second >= b second ]) asArray.
	points := points first: (points size min: 8).
	maxReward := (points collect: [ :each | each third ]) ifEmpty: [ 0 ] ifNotEmpty: [ :all | all max ].
	totalReward := self grammarPoints inject: 0 into: [ :sum :each | sum + each third ].
	rows := points collect: [ :each |
		        {
			        each first.
			        each second.
			        (maxReward > 0
				         ifTrue: [ (each third / maxReward * each second) rounded ]
				         ifFalse: [ 0 ]).
			        (each second printString , ' visits' , (each third > 0
				          ifTrue: [ ', ' , (each third * 100 / totalReward) rounded printString , '% of the reward' ]
				          ifFalse: [ '' ])).
			        nil } ].
	y := self barRows: rows at: 0 @ y labelWidth: 300 barWidth: 380.
	y := self section: 'Rules broken by the inputs that set records' at: 0 @ (y + 16).
	self barRows: self ruleRows at: 0 @ y labelWidth: 300 barWidth: 380.
	^ self finish
]

{ #category : 'data' }
PerfUMateCharts >> grammarPoints [
	"Mate's search points: a type in the context of the declarations that lead to it, with its
	visits and its reward (what the campaign's feedback added to Mate's initial reward of 1)"

	| points |
	points := Dictionary new.
	report grammar typeDeclarations do: [ :declaration |
		| visits rewards |
		visits := declaration visits.
		rewards := declaration rewards.
		visits ifNotNil: [
			visits keysAndValuesDo: [ :key :count |
				| label point |
				label := self labelOfPath: key first type: declaration type.
				point := points at: label ifAbsentPut: [ Array with: label with: 0 with: 0 ].
				point at: 2 put: (point at: 2) + count.
				rewards ifNotNil: [
					point at: 3 put: (point at: 3) + ((rewards at: key ifAbsent: [ 1 ]) - 1 max: 0) ] ] ] ].
	^ points values
]

{ #category : 'data' }
PerfUMateCharts >> labelOfPath: aPath type: aType [

	| names |
	names := aPath asArray collect: [ :declaration |
		         (declaration isKindOf: MateInstVarDecl)
			         ifTrue: [ declaration name ]
			         ifFalse: [ self shortName: declaration type ] ].
	names := names copyWith: (self shortName: aType).
	"An array field shows up twice in Mate's path (the field and its elements)"
	names := names inject: OrderedCollection new into: [ :kept :name |
		         (kept notEmpty and: [ kept last = name ]) ifFalse: [ kept add: name ].
		         kept ].
	^ ' > ' join: names
]

{ #category : 'data' }
PerfUMateCharts >> commonPrefix [
	"The prefix shared by the classes the grammar declares (PerfUMateExampleOrder and
	PerfUMateExampleItem share PerfUMateExample), dropped from labels"

	| names prefix |
	names := (report grammar typeDeclarations values select: [ :declaration |
		          declaration respondsTo: #instanceVariableDeclarations ]) collect: [ :declaration |
		         declaration type name ].
	names size < 2 ifTrue: [ ^ '' ].
	prefix := names first.
	names do: [ :name |
		| size |
		size := 0.
		[ size < prefix size and: [ size < name size and: [ (prefix at: size + 1) = (name at: size + 1) ] ] ]
			whileTrue: [ size := size + 1 ].
		prefix := prefix first: size ].
	"Keep whole words: cut back to the last capital letter"
	[ prefix notEmpty and: [ (names allSatisfy: [ :name | name size > prefix size and: [ (name at: prefix size + 1) isUppercase ] ]) not ] ]
		whileTrue: [ prefix := prefix allButLast ].
	^ prefix
]

{ #category : 'data' }
PerfUMateCharts >> shortName: aType [

	| name prefix |
	name := aType isBehavior
		        ifTrue: [ aType name ]
		        ifFalse: [ aType printString ].
	prefix := self commonPrefix.
	^ (prefix notEmpty and: [ name size > prefix size and: [ name beginsWith: prefix ] ])
		  ifTrue: [ name allButFirst: prefix size ]
		  ifFalse: [ name ]
]

{ #category : 'data' }
PerfUMateCharts >> ruleRows [
	"Records grouped by the rule they break, numbers in the message replaced by N"

	| byRule space |
	byRule := Dictionary new.
	space := PerfUMateSearchSpace grammar: report grammar rootType: nil validity: 1.
	(report trace records select: [ :run | run input notNil ]) do: [ :run |
		| rule |
		rule := (space brokenRuleOf: run input)
			        ifNil: [ 'respects the grammar' ]
			        ifNotNil: [ :message | self generalize: message ].
		byRule at: rule put: (byRule at: rule ifAbsent: [ 0 ]) + 1 ].
	^ (byRule associations asSortedCollection: [ :a :b | a value >= b value ]) asArray collect: [ :each |
		  {
			  (each key size > 40
				   ifTrue: [ (each key first: 38) , '...' ]
				   ifFalse: [ each key ]).
			  each value.
			  each value.
			  (self count: each value of: 'record').
			  each key } ]
]

{ #category : 'data' }
PerfUMateCharts >> generalize: aRuleMessage [
	"'Array size 94 not between 0 and 16' -> 'Array size N not between 0 and 16'"

	^ (aRuleMessage asString
		   copyWithRegex: '(size|Value) [^ ]+'
		   matchesTranslatedUsing: [ :match | (match copyUpTo: Character space) , ' N' ]) lines first
]

{ #category : 'colors' }
PerfUMateCharts >> grid [

	^ self ink alpha: 0.1
]

{ #category : 'colors' }
PerfUMateCharts >> ink [

	^ Smalltalk ui theme textColor
]

{ #category : 'drawing' }
PerfUMateCharts >> line: aPoint to: anotherPoint color: aColor [

	^ self add: (RSLine new
			   startPoint: aPoint;
			   endPoint: anotherPoint;
			   color: aColor;
			   width: 1;
			   yourself)
]

{ #category : 'charts' }
PerfUMateCharts >> mutatorsCanvas [

	| y probabilities rows |
	self newCanvas.
	y := self
		     title: 'Mutators'
		     subtitle: 'How often each mutator ran (gray) and how often its input set a record (pink)'.
	probabilities := report trace mutatorProbabilities.
	rows := report trace mutatorStatistics associations collect: [ :each |
		        | runs records |
		        runs := each value first.
		        records := each value second.
		        {
			        each key.
			        runs.
			        records.
			        (String streamContents: [ :stream |
				         stream
					         nextPutAll: (self count: runs of: 'run');
					         nextPutAll: ', ';
					         nextPutAll: (self count: records of: 'record').
				         probabilities at: each key ifPresent: [ :probability |
					         stream
						         nextPutAll: ', MOpt ';
						         nextPutAll: ((probability * 100) printShowingDecimalPlaces: 0);
						         nextPut: $% ] ]).
			        nil } ].
	self barRows: rows at: 0 @ y labelWidth: 180 barWidth: 420.
	^ self finish
]

{ #category : 'colors' }
PerfUMateCharts >> muted [

	^ self ink alpha: 0.55
]

{ #category : 'drawing' }
PerfUMateCharts >> newCanvas [

	canvas := RSCanvas new.
	canvas color: Smalltalk ui theme backgroundColor.
	^ canvas
]

{ #category : 'data' }
PerfUMateCharts >> objectCountOf: aGraph [

	^ [ (PerfUMateGraphWalker on: aGraph) objectCount ]
		  on: Error
		  do: [ :error | error return: 0 ]
]

{ #category : 'drawing' }
PerfUMateCharts >> popup: aString on: aShape [

	aShape model: aString.
	aShape @ (RSPopup text: [ :model | model ])
]

{ #category : 'drawing' }
PerfUMateCharts >> scatter: runs x: xBlock xName: aString at: top left: left width: width [
	"Log scale for time. Answers the y below the chart"

	| height bottom xs times minTime maxTime lowExponent highExponent maxX y records sample |
	height := 170.
	bottom := top + height.
	runs isEmpty ifTrue: [
		self text: 'no runs recorded' at: left @ (top + 20) size: 12 color: self muted.
		^ top + 40 ].
	times := runs collect: [ :run | run microseconds max: 1 ].
	minTime := times min.
	maxTime := times max.
	lowExponent := (minTime log: 10) floor.
	highExponent := (maxTime log: 10) ceiling max: lowExponent + 1.
	xs := runs collect: xBlock.
	maxX := xs max max: 1.
	y := [ :microseconds |
	     bottom - (((microseconds max: 1) log: 10) - lowExponent / (highExponent - lowExponent) * height) ].
	lowExponent to: highExponent do: [ :exponent |
		| lineY |
		lineY := bottom - (exponent - lowExponent / (highExponent - lowExponent) * height).
		self line: left @ lineY to: left + width @ lineY color: self grid.
		self textRight: (self timeString: (10 raisedTo: exponent)) at: left - 6 @ lineY size: 10 color: self muted ].
	self text: '0' at: left @ (bottom + 12) size: 10 color: self muted.
	self textRight: maxX printString , ' ' , aString at: left + width @ (bottom + 12) size: 10 color: self muted.
	"Thousands of runs: draw a sample of the ordinary ones, every record and failure"
	sample := runs size > 1200
		          ifTrue: [ runs size // 1200 ]
		          ifFalse: [ 1 ].
	runs doWithIndex: [ :run :index |
		(run isRecord or: [ run isError or: [ run isTimeout or: [ index \\ sample = 0 ] ] ]) ifTrue: [
			| dot |
			dot := RSEllipse new
				       size: (run isRecord
						        ifTrue: [ 7 ]
						        ifFalse: [ 4 ]);
				       color: (self colorOf: run);
				       position: left + ((xBlock value: run) / maxX * width) @ (y value: run microseconds);
				       yourself.
			self add: dot.
			self popup: (self describe: run) on: dot ] ].
	"Records joined in order: how the search climbed"
	records := (runs select: [ :run | run isRecord ]) asSortedCollection: [ :a :b | (xBlock value: a) <= (xBlock value: b) ].
	records size > 1 ifTrue: [
		self add: (RSPolyline new
				 controlPoints: (records asArray collect: [ :run |
						  left + ((xBlock value: run) / maxX * width) @ (y value: run microseconds) ]);
				 color: (self accent alpha: 0.45);
				 width: 1;
				 yourself) ].
	^ bottom + 24
]

{ #category : 'drawing' }
PerfUMateCharts >> colorOf: aRun [

	aRun isRecord ifTrue: [ ^ self accent ].
	(aRun isError or: [ aRun isTimeout ]) ifTrue: [ ^ self warning ].
	^ self ink alpha: 0.22
]

{ #category : 'formatting' }
PerfUMateCharts >> count: aNumber of: aNoun [

	^ aNumber printString , ' ' , aNoun , (aNumber = 1
		   ifTrue: [ '' ]
		   ifFalse: [ 's' ])
]

{ #category : 'drawing' }
PerfUMateCharts >> describe: aRun [

	^ String streamContents: [ :stream |
		  stream
			  nextPutAll: 'run ';
			  print: aRun index;
			  nextPutAll: ': ';
			  nextPutAll: (self timeString: aRun microseconds);
			  nextPutAll: ', ';
			  print: aRun objects;
			  nextPutAll: ' objects, ';
			  nextPutAll: aRun mutator.
		  aRun isRecord ifTrue: [ stream nextPutAll: ', record' ].
		  aRun errorClassName ifNotNil: [ :name | stream nextPutAll: ', ' , name ] ]
]

{ #category : 'drawing' }
PerfUMateCharts >> legendAt: aPoint [

	| x |
	x := aPoint x.
	{
		(self ink alpha: 0.22) -> 'run'.
		self accent -> 'record (new best for the guide)'.
		self warning -> 'error or timeout' } do: [ :each |
		self add: (RSEllipse new
				 size: 7;
				 color: each key;
				 position: x + 4 @ aPoint y;
				 yourself).
		x := x + 14 + (self text: each value at: x + 12 @ aPoint y size: 11 color: self muted) width + 18 ]
]

{ #category : 'drawing' }
PerfUMateCharts >> section: aString at: aPoint [
	"Answers the y where the section's content starts"

	self text: aString at: aPoint x @ (aPoint y + 10) size: 13 color: self ink.
	^ aPoint y + 36
]

{ #category : 'initialization' }
PerfUMateCharts >> setReport: aPerfUMateReport [

	report := aPerfUMateReport
]

{ #category : 'drawing' }
PerfUMateCharts >> text: aString at: aPoint size: aNumber color: aColor [
	"Left aligned on aPoint"

	| label |
	label := RSLabel new
		         text: aString asString;
		         fontSize: aNumber;
		         color: aColor;
		         yourself.
	label position: aPoint + ((label width / 2) @ 0).
	^ self add: label
]

{ #category : 'drawing' }
PerfUMateCharts >> textRight: aString at: aPoint size: aNumber color: aColor [
	"Right aligned on aPoint"

	| label |
	label := RSLabel new
		         text: aString asString;
		         fontSize: aNumber;
		         color: aColor;
		         yourself.
	label position: aPoint - ((label width / 2) @ 0).
	^ self add: label
]

{ #category : 'formatting' }
PerfUMateCharts >> timeString: microseconds [

	microseconds < 1000 ifTrue: [ ^ microseconds rounded printString , ' us' ].
	microseconds < 1000000 ifTrue: [ ^ (microseconds / 1000) rounded printString , ' ms' ].
	^ (microseconds / 1000000 printShowingDecimalPlaces: 1) , ' s'
]

{ #category : 'drawing' }
PerfUMateCharts >> title: aTitle subtitle: aSubtitle [

	| title |
	title := RSLabel new
		         text: aTitle;
		         fontSize: 20;
		         bold;
		         color: self ink;
		         yourself.
	title position: (title width / 2) @ 0.
	self add: title.
	self text: aSubtitle at: 0 @ 26 size: 12 color: self muted.
	^ 50
]

{ #category : 'colors' }
PerfUMateCharts >> track [

	^ self ink alpha: 0.16
]

{ #category : 'data' }
PerfUMateCharts >> visitsOf: aDeclaration [

	^ [ aDeclaration totalVisits ]
		  on: Error
		  do: [ :error | error return: 0 ]
]

{ #category : 'colors' }
PerfUMateCharts >> warning [

	^ Color fromHexString: 'e0912f'
]
