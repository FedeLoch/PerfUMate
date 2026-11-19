"
A UmeRunner whose result skips Ume's bug localization. UmeResult class >> #resultFrom:... localizes
bugs as soon as it is built, comparing the coverage of consecutive cases; a case that failed before
its coverage was collected has none, and the whole campaign is lost. PerfUMate does not use that
localization (it confirms, locates and minimizes findings itself), so it is left out. Proposed
upstream: build the localization lazily, and skip cases without coverage.
"
Class {
	#name : 'PerfUMateRunner',
	#superclass : 'UmeRunner',
	#category : 'PerfUMate-Core',
	#package : 'PerfUMate',
	#tag : 'Core'
}

{ #category : 'reporting' }
PerfUMateRunner >> genReport: tests since: time withCoverage: totalCoverageResult [

	^ self genReport: tests since: time withCoverage: totalCoverageResult with: tests size
]

{ #category : 'reporting' }
PerfUMateRunner >> genReport: tests since: time withCoverage: totalCoverageResult with: aNumberOfTests [

	| totalTime |
	totalTime := Duration milliSeconds: (Time millisecondsSince: time).
	^ UmeResult new
		  tests: tests;
		  totalTime: totalTime;
		  totalCoverage: totalCoverageResult;
		  topCases: self feedbackEvaluator topCases;
		  runner: self;
		  feedbackEvaluator: self feedbackEvaluator;
		  performanceResult: (PerformanceResult from: tests withTime: totalTime);
		  numberOfGeneratedTests: aNumberOfTests;
		  yourself
]
