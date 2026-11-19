"
Superclass for running PerfUMate campaigns as SUnit tests, for CI. A test passes when the
campaign finds nothing:

	testCheckoutHasNoSlowInputs
		self assertNoFindings: (PerfUMate new
			examples: MyExamples orders;
			benchmark: [ :order | Checkout new process: order ];
			budget: 1 minute)

PERFUMATE_BUDGET (seconds) overrides the budget, and the report is saved into PERFUMATE_OUT
(default: perfumate-out) so the CI job can keep it as an artifact.
"
Class {
	#name : 'PerfUMateCampaignTest',
	#superclass : 'TestCase',
	#category : 'PerfUMate-Report',
	#package : 'PerfUMate',
	#tag : 'Report'
}

{ #category : 'testing' }
PerfUMateCampaignTest class >> isAbstract [

	^ self == PerfUMateCampaignTest
]

{ #category : 'asserting' }
PerfUMateCampaignTest >> assertNoFindings: aPerfUMate [

	| report |
	report := self runCampaign: aPerfUMate.
	self assert: report findings isEmpty description: [ report summary ].
	^ report
]

{ #category : 'running' }
PerfUMateCampaignTest >> outputDirectory [

	^ Smalltalk os environment at: 'PERFUMATE_OUT' ifAbsent: [ 'perfumate-out' ]
]

{ #category : 'running' }
PerfUMateCampaignTest >> runCampaign: aPerfUMate [

	| report |
	aPerfUMate budget: (PerfUMate budgetFromEnvironmentOr: aPerfUMate budget).
	self timeLimit: aPerfUMate budget * 2 + 1 minute.
	report := aPerfUMate run.
	report saveTo: self outputDirectory.
	^ report
]
