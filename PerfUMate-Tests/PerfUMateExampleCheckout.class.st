"
The code under test of the example. It has two planted bugs:

- #loyaltyPointsFor: counts, for every item, the items with the same name: quadratic in the
  number of items, invisible with three items, slow with hundreds;
- #discountFor: reads the first three characters of the coupon, and fails on shorter coupons.
"
Class {
	#name : 'PerfUMateExampleCheckout',
	#superclass : 'Object',
	#category : 'PerfUMate-Tests-Example',
	#package : 'PerfUMate-Tests',
	#tag : 'Example'
}

{ #category : 'checkout' }
PerfUMateExampleCheckout >> discountFor: anOrder [

	^ (anOrder coupon first: 3) = 'VIP'
		  ifTrue: [ 10 ]
		  ifFalse: [ 0 ]
]

{ #category : 'checkout' }
PerfUMateExampleCheckout >> loyaltyPointsFor: anOrder [

	^ anOrder items inject: 0 into: [ :points :item |
		  points + (anOrder items count: [ :other | other name = item name ]) ]
]

{ #category : 'checkout' }
PerfUMateExampleCheckout >> process: anOrder [

	| total |
	total := anOrder items inject: 0 into: [ :sum :item | sum + (item quantity * item price) ].
	^ {
		  (total - (self discountFor: anOrder)).
		  (self loyaltyPointsFor: anOrder) }
]
