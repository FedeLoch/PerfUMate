"
The campaigns of the example checkout, declared for PerfUMate class >> #runCampaignsIn:into:
(what the GitHub Action runs).
"
Class {
	#name : 'PerfUMateExampleCampaigns',
	#superclass : 'Object',
	#category : 'PerfUMate-Tests-Example',
	#package : 'PerfUMate-Tests',
	#tag : 'Example'
}

{ #category : 'campaigns' }
PerfUMateExampleCampaigns class >> checkout [

	<perfumate>
	^ PerfUMate new
		  examples: PerfUMateExamples orders;
		  benchmark: [ :order | PerfUMateExampleCheckout new process: order ];
		  budget: 10 seconds;
		  seed: 7;
		  yourself
]

{ #category : 'campaigns' }
PerfUMateExampleCampaigns class >> notACampaign [
	"No pragma: not run"

	^ self error: 'not a campaign'
]
