"
The three example orders the tests give to PerfUMate.
"
Class {
	#name : 'PerfUMateExamples',
	#superclass : 'Object',
	#category : 'PerfUMate-Tests-Example',
	#package : 'PerfUMate-Tests',
	#tag : 'Example'
}

{ #category : 'examples' }
PerfUMateExamples class >> orders [

	^ {
		  (PerfUMateExampleOrder coupon: 'VIP10' items: {
				   (PerfUMateExampleItem name: 'tea' quantity: 2 price: 4).
				   (PerfUMateExampleItem name: 'cake' quantity: 1 price: 6) }).
		  (PerfUMateExampleOrder coupon: 'SPRING' items: { (PerfUMateExampleItem name: 'coffee' quantity: 3 price: 3) }).
		  (PerfUMateExampleOrder coupon: 'WELCOME5' items: {
				   (PerfUMateExampleItem name: 'tea' quantity: 1 price: 4).
				   (PerfUMateExampleItem name: 'scone' quantity: 2 price: 3).
				   (PerfUMateExampleItem name: 'jam' quantity: 1 price: 5) }) }
]
