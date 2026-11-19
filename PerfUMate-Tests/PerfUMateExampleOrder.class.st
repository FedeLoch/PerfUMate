"
An order of the example domain: items and a coupon code.
"
Class {
	#name : 'PerfUMateExampleOrder',
	#superclass : 'Object',
	#instVars : [
		'items',
		'coupon'
	],
	#category : 'PerfUMate-Tests-Example',
	#package : 'PerfUMate-Tests',
	#tag : 'Example'
}

{ #category : 'instance creation' }
PerfUMateExampleOrder class >> coupon: aString items: someItems [

	^ self new
		  coupon: aString;
		  items: someItems asOrderedCollection;
		  yourself
]

{ #category : 'accessing' }
PerfUMateExampleOrder >> coupon [

	^ coupon
]

{ #category : 'accessing' }
PerfUMateExampleOrder >> coupon: aString [

	coupon := aString
]

{ #category : 'accessing' }
PerfUMateExampleOrder >> items [

	^ items
]

{ #category : 'accessing' }
PerfUMateExampleOrder >> items: aCollection [

	items := aCollection
]
