Extension { #name : 'UmeFeedbackEvaluator' }

{ #category : '*PerfUMate' }
UmeFeedbackEvaluator >> guide: aFeedbackGuide [
	"Proposed for Ume: guide the evaluation with any UmeFeedbackGuide, not only the predefined ones
	(#feedbackByExecutionTime, #feedbackByCoverage...)"

	aFeedbackGuide evaluator: self.
	guide := aFeedbackGuide
]
