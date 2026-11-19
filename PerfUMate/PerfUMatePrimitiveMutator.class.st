"
I change one string or one number inside the graph: truncate, cut, insert or replace a character,
empty or double a string; replace a number with a boundary value or a neighbour.

Mate regenerates whole values, so it rarely builds the almost valid inputs that break code
(a coupon 'VI' instead of 'VIP10', a quantity one past its bound). I am that small share of
byte-level mutation, scheduled by MOpt like the others.
"
Class {
	#name : 'PerfUMatePrimitiveMutator',
	#superclass : 'PerfUMateMutator',
	#category : 'PerfUMate-Mutators',
	#package : 'PerfUMate',
	#tag : 'Mutators'
}

{ #category : 'private' }
PerfUMatePrimitiveMutator >> interestingCharacters [

	^ { $'. $". $\. $<. $>. $%. $&. $/. $0. $-. Character space. Character cr. Character tab. Character null.
	  Character value: 255 }
]

{ #category : 'mutating' }
PerfUMatePrimitiveMutator >> mutateInput: anInput [

	| graph walker slots slot |
	graph := anInput graph veryDeepCopy.
	walker := PerfUMateGraphWalker on: graph.
	slots := walker stringSlots , walker numberSlots.
	slots ifEmpty: [ ^ anInput ].
	slot := slots atRandom.
	slot value: (slot value isString
			 ifTrue: [ self mutateString: slot value ]
			 ifFalse: [ self mutateNumber: slot value ]).
	^ space inputForGraph: graph
]

{ #category : 'mutating' }
PerfUMatePrimitiveMutator >> mutateNumber: aNumber [

	| candidates |
	aNumber isFloat ifTrue: [
		^ { 0.0. -0.0. 1.0. -1.0. aNumber negated. aNumber * 2. aNumber / 2. Float fmax. Float fminNormalized.
		  Float infinity. Float nan } atRandom ].
	candidates := { 0. 1. -1. aNumber + 1. aNumber - 1. aNumber negated. aNumber * 2. 255. 256. 65535. 65536.
	              (2 raisedTo: 31) - 1. 2 raisedTo: 31. SmallInteger maxVal. SmallInteger minVal }.
	^ candidates atRandom
]

{ #category : 'mutating' }
PerfUMatePrimitiveMutator >> mutateString: aString [

	| position |
	aString isEmpty ifTrue: [ ^ String with: self interestingCharacters atRandom ].
	position := (1 to: aString size) atRandom.
	^ { 
		  [ aString first: position - 1 ].
		  [ (aString first: position - 1) , (aString allButFirst: position) ].
		  [ (aString first: position - 1) , (String with: self interestingCharacters atRandom)
		  , (aString allButFirst: position - 1) ].
		  [ aString copy at: position put: self interestingCharacters atRandom; yourself ].
		  [ '' ].
		  [ aString , aString ] } atRandom value
]

{ #category : 'printing' }
PerfUMatePrimitiveMutator >> label [

	^ 'primitive values'
]
