"
I ignore my input and generate a fresh graph from the grammar with the campaign's validity
(0.9 by default: one graph in ten breaks exactly one rule). Mate's MCTS learns from the rewards.
"
Class {
	#name : 'PerfUMateGenerateMutator',
	#superclass : 'PerfUMateMutator',
	#category : 'PerfUMate-Mutators',
	#package : 'PerfUMate',
	#tag : 'Mutators'
}

{ #category : 'mutating' }
PerfUMateGenerateMutator >> mutateInput: anInput [

	^ space inputFor: (space generateDerivation: space validity)
]

{ #category : 'printing' }
PerfUMateGenerateMutator >> label [

	^ 'new graph'
]
