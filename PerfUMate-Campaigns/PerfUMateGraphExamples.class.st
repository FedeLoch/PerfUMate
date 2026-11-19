"
Example object graphs for the campaigns: the kinds of values the Termo hunt built from recipes
(collections inside collections, identity collections, bags of associations, points with signed
zeros, intervals, NaN, large integers, fractions, symbols, byte arrays), here as real objects.
"
Class {
	#name : 'PerfUMateGraphExamples',
	#superclass : 'Object',
	#category : 'PerfUMate-Campaigns',
	#package : 'PerfUMate-Campaigns'
}

{ #category : 'examples' }
PerfUMateGraphExamples class >> boxes [

	^ {
		  (PerfUMateGraphBox
			   first: (Set withAll: {
						    (Set withAll: #( 1 2 3 )).
						    (OrderedCollection withAll: #( 4 5 )) })
			   second: (IdentitySet withAll: {
						    'k' copy.
						    #s.
						    3 })
			   third: (Bag withAll: {
						    (1 -> 2).
						    (1 -> 2).
						    (#a -> 'b') })).
		  (PerfUMateGraphBox first: 1 @ -0.5 second: (1 to: 3) third: #( 1 2 3 )).
		  (PerfUMateGraphBox
			   first: #+ -> 4
			   second: (OrderedCollection withAll: {
						    1.5.
						    Float nan.
						    -0.0 })
			   third: (Set withAll: #( 1 2 ))).
		  (PerfUMateGraphBox first: #[ 1 2 255 ] second: 'abc' third: (IdentitySet withAll: #( 1 2 ))).
		  (PerfUMateGraphBox
			   first: {
					   (2 raisedTo: 64).
					   (1 / 3).
					   0.1 }
			   second: #sym
			   third: (Bag withAll: #( 1 1 2 ))).
		  (PerfUMateGraphBox
			   first: (OrderedCollection with: (Set with: 1) with: (Bag with: 2))
			   second: 3 @ 4
			   third: 1.0e-310) }
]

{ #category : 'examples' }
PerfUMateGraphExamples class >> keyBatches [
	"Inputs of the hashing campaign: integer keys put in hashed collections"

	^ {
		  (PerfUMateKeyBatch keys: ((1 to: 8) collect: [ :i | PerfUMateKey value: i ]) asOrderedCollection).
		  (PerfUMateKeyBatch keys: (#( 10 20 30 40 ) collect: [ :i | PerfUMateKey value: i ]) asOrderedCollection).
		  (PerfUMateKeyBatch keys: (#( 7 1024 65536 3 ) collect: [ :i | PerfUMateKey value: i ]) asOrderedCollection) }
]
