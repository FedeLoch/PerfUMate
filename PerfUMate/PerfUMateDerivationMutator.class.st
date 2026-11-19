"
I regenerate one node of the input's Mate derivation, like Ume's UmeOGGrammarDerivationMutator,
but on the derivation kept with the input instead of re-parsing the graph.

Strategies:
- leastRewarded: the node with the lowest reward (ties broken at random);
- random: any node;
- breakingRule: make the graph break exactly one rule (Mate's violation injector).
"
Class {
	#name : 'PerfUMateDerivationMutator',
	#superclass : 'PerfUMateMutator',
	#instVars : [
		'strategy'
	],
	#category : 'PerfUMate-Mutators',
	#package : 'PerfUMate',
	#tag : 'Mutators'
}

{ #category : 'strategies' }
PerfUMateDerivationMutator >> breakingRule [

	strategy := #breakingRule
]

{ #category : 'initialization' }
PerfUMateDerivationMutator >> initialize [

	super initialize.
	strategy := #leastRewarded
]

{ #category : 'strategies' }
PerfUMateDerivationMutator >> leastRewarded [

	strategy := #leastRewarded
]

{ #category : 'private' }
PerfUMateDerivationMutator >> leastRewardedNodeOf: aDerivation [

	| worstReward worst |
	worstReward := nil.
	worst := OrderedCollection new.
	aDerivation allNodes do: [ :node |
		| reward |
		reward := node currentReward.
		(worstReward isNil or: [ reward < worstReward ]) ifTrue: [
			worstReward := reward.
			worst := OrderedCollection new ].
		reward = worstReward ifTrue: [ worst add: node ] ].
	^ worst atRandom
]

{ #category : 'mutating' }
PerfUMateDerivationMutator >> mutateInput: anInput [

	| derivation |
	derivation := space takeDerivationFor: anInput.
	derivation ifNil: [ ^ anInput ].
	strategy = #breakingRule ifTrue: [
		(space breakOneRuleIn: derivation) ifNotNil: [ :broken | ^ space inputFor: broken ] ].
	^ space inputFor: (self
			   replace: (strategy = #leastRewarded
					    ifTrue: [ self leastRewardedNodeOf: derivation ]
					    ifFalse: [ derivation allNodes atRandom ])
			   in: derivation)
]

{ #category : 'printing' }
PerfUMateDerivationMutator >> printOn: aStream [

	super printOn: aStream.
	aStream nextPutAll: ' ' , strategy
]

{ #category : 'strategies' }
PerfUMateDerivationMutator >> random [

	strategy := #random
]

{ #category : 'private' }
PerfUMateDerivationMutator >> replace: aNode in: aDerivation [

	| variant |
	variant := space grammar genVariant: aNode.
	aNode == aDerivation ifTrue: [ ^ variant ].
	space grammar replace: aNode by: variant.
	^ aDerivation
]

{ #category : 'printing' }
PerfUMateDerivationMutator >> label [

	strategy = #leastRewarded ifTrue: [ ^ 'least rewarded node' ].
	strategy = #random ifTrue: [ ^ 'random node' ].
	^ 'break one rule'
]
