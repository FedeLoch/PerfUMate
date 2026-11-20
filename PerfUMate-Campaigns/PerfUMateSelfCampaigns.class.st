"
PerfUMate fuzzing itself: its graph walker, canonical description and shrinker get the generated
object graphs of the other campaigns, and must keep their invariants. Run nightly by
.github/workflows/fuzzing.yml with the other campaigns.

The campaigns do not instrument PerfUMate: the campaign machinery uses the same classes while it
runs. They are guided by errors.
"
Class {
	#name : 'PerfUMateSelfCampaigns',
	#superclass : 'Object',
	#category : 'PerfUMate-Campaigns',
	#package : 'PerfUMate-Campaigns'
}

{ #category : 'checks' }
PerfUMateSelfCampaigns class >> broken: aLabel [

	PerfUMateBrokenInvariant signal: aLabel
]

{ #category : 'campaigns' }
PerfUMateSelfCampaigns class >> canonical [
	"PerfUMateCanonical describes any graph, the same way twice, and the same way as a copy"

	<perfumate>
	^ PerfUMate new
		  name: 'self-canonical';
		  examples: PerfUMateGraphExamples boxes;
		  benchmark: [ :graph | PerfUMateSelfCampaigns checkCanonical: graph ];
		  lookFor: #errors;
		  maxElements: 64;
		  yourself
]

{ #category : 'checks' }
PerfUMateSelfCampaigns class >> checkCanonical: aGraph [

	| description |
	description := PerfUMateCanonical describe: aGraph.
	(PerfUMateCanonical describe: aGraph) = description ifFalse: [ self broken: 'describe: is not deterministic' ].
	(PerfUMateCanonical describe: aGraph veryDeepCopy) = description ifFalse: [
		self broken: 'a veryDeepCopy is described differently' ].
	^ description size
]

{ #category : 'checks' }
PerfUMateSelfCampaigns class >> checkShrinker: aGraph [
	"Minimizing while the first slot keeps its class: the result keeps it, the original is untouched"

	| before keep result |
	before := PerfUMateCanonical describe: aGraph.
	keep := [ :graph | graph first class == aGraph first class ].
	result := (PerfUMateGraphShrinker oracle: keep)
		          deadline: DateAndTime now + 200 milliSeconds;
		          shrink: aGraph.
	(keep value: result) ifFalse: [ self broken: 'the result does not satisfy the oracle' ].
	(PerfUMateCanonical describe: aGraph) = before ifFalse: [ self broken: 'shrink: changes its input' ].
	^ result
]

{ #category : 'checks' }
PerfUMateSelfCampaigns class >> checkWalker: aGraph [
	"Every slot the walker answers can be read and written back, and the graph does not change"

	| before walker |
	before := PerfUMateCanonical describe: aGraph.
	walker := PerfUMateGraphWalker on: aGraph.
	walker slots do: [ :slot | slot value: slot value ].
	(PerfUMateCanonical describe: aGraph) = before ifFalse: [ self broken: 'writing a slot back changes the graph' ].
	walker objectCount = walker objects size ifFalse: [ self broken: 'objectCount and objects disagree' ].
	(walker objects includes: aGraph) ifFalse: [ self broken: 'the root is not among the objects' ].
	^ walker slots size
]

{ #category : 'campaigns' }
PerfUMateSelfCampaigns class >> shrinker [
	"PerfUMateGraphShrinker keeps the oracle, and never changes the graph it is given"

	<perfumate>
	^ PerfUMate new
		  name: 'self-shrinker';
		  examples: PerfUMateGraphExamples boxes;
		  benchmark: [ :graph | PerfUMateSelfCampaigns checkShrinker: graph ];
		  lookFor: #errors;
		  maxElements: 64;
		  yourself
]

{ #category : 'campaigns' }
PerfUMateSelfCampaigns class >> walker [
	"PerfUMateGraphWalker answers slots that can be read and written, and counts objects consistently"

	<perfumate>
	^ PerfUMate new
		  name: 'self-walker';
		  examples: PerfUMateGraphExamples boxes;
		  benchmark: [ :graph | PerfUMateSelfCampaigns checkWalker: graph ];
		  lookFor: #errors;
		  maxElements: 64;
		  yourself
]
