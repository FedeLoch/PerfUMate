"
Grammars inferred from a few examples overfit them: ranges are the observed min..max, collections
the observed sizes. I widen an inferred Mate grammar in place:

- a numeric range grows by `factor` times its span on each side, without crossing zero when the
  examples never did (going below zero is the job of rule breaking);
- a collection accepts `minSize .. max(4 * maxSize, 16)` elements.

Enumerations, invariants and references are kept.
"
Class {
	#name : 'PerfUMateGrammarWidener',
	#superclass : 'Object',
	#instVars : [
		'factor'
	],
	#category : 'PerfUMate-Grammars',
	#package : 'PerfUMate',
	#tag : 'Grammars'
}

{ #category : 'accessing' }
PerfUMateGrammarWidener >> factor: aNumber [

	factor := aNumber
]

{ #category : 'initialization' }
PerfUMateGrammarWidener >> initialize [

	super initialize.
	factor := 10
]

{ #category : 'widening' }
PerfUMateGrammarWidener >> widen: aGrammar [

	aGrammar typeDeclarations do: [ :declaration |
		(declaration respondsTo: #instanceVariableDeclarations) ifTrue: [
			declaration instanceVariableDeclarations do: [ :variable | self widenVariable: variable ] ] ].
	^ aGrammar
]

{ #category : 'widening' }
PerfUMateGrammarWidener >> widenConstraint: aConstraint [

	| min max span newMin newMax |
	min := aConstraint min.
	max := aConstraint max.
	(min isNumber and: [ max isNumber ]) ifFalse: [ ^ aConstraint ].
	aConstraint hasOptions ifTrue: [ ^ aConstraint ].
	span := (max - min) abs max: 1.
	newMin := min - (span * factor).
	newMax := max + (span * factor).
	(min >= 0 and: [ newMin < 0 ]) ifTrue: [ newMin := min * 0 ].
	(max <= 0 and: [ newMax > 0 ]) ifTrue: [ newMax := max * 0 ].
	^ MateConstraint between: newMin and: newMax
]

{ #category : 'widening' }
PerfUMateGrammarWidener >> widenSizesOf: anArrayDeclaration [

	| max |
	max := anArrayDeclaration maxSize ifNil: [ ^ self ].
	anArrayDeclaration
		sizeBetween: (anArrayDeclaration minSize ifNil: [ 0 ])
		and: (max * 4 max: 16)
]

{ #category : 'widening' }
PerfUMateGrammarWidener >> widenVariable: aVariableDeclaration [

	(aVariableDeclaration isKindOf: MateInstArrayVarDecl) ifTrue: [
		^ self widenSizesOf: aVariableDeclaration ].
	(aVariableDeclaration respondsTo: #constraint) ifFalse: [ ^ self ].
	aVariableDeclaration constraint ifNotNil: [ :constraint |
		aVariableDeclaration constraint: (self widenConstraint: constraint) ]
]
