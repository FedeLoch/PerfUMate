Extension { #name : 'UmeRunner' }

{ #category : '*PerfUMate' }
UmeRunner >> guidedBy: aFeedbackGuide [
	"Proposed for Ume: guide the campaign with any UmeFeedbackGuide (a custom one, or a combination
	such as coverage and errors). Execution time is profiled, as for #guidedByScore"

	evaluator profilingByExecutionTime.
	feedbackEvaluator guide: aFeedbackGuide
]
