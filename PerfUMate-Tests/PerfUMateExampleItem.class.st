"
An order line of the example domain.
"
Class {
	#name : 'PerfUMateExampleItem',
	#superclass : 'Object',
	#instVars : [
		'name',
		'quantity',
		'price'
	],
	#category : 'PerfUMate-Tests-Example',
	#package : 'PerfUMate-Tests',
	#tag : 'Example'
}

{ #category : 'instance creation' }
PerfUMateExampleItem class >> name: aString quantity: aQuantity price: aPrice [

	^ self new
		  name: aString;
		  quantity: aQuantity;
		  price: aPrice;
		  yourself
]

{ #category : 'accessing' }
PerfUMateExampleItem >> name [

	^ name
]

{ #category : 'accessing' }
PerfUMateExampleItem >> name: aString [

	name := aString
]

{ #category : 'accessing' }
PerfUMateExampleItem >> price [

	^ price
]

{ #category : 'accessing' }
PerfUMateExampleItem >> price: anInteger [

	price := anInteger
]

{ #category : 'accessing' }
PerfUMateExampleItem >> quantity [

	^ quantity
]

{ #category : 'accessing' }
PerfUMateExampleItem >> quantity: anInteger [

	quantity := anInteger
]
