Extension { #name : 'MateDecl' }

{ #category : '*PerfUMate' }
MateDecl >> rewards [
	"Proposed for Mate: the reward of this declaration per derivation context ({ path. level })"

	^ rewards
]

{ #category : '*PerfUMate' }
MateDecl >> visits [
	"Proposed for Mate: how many times this declaration was derived, per derivation context"

	^ visits
]
