"
Signal me from a benchmark when a property does not hold:

	benchmark: [ :graph |
		(STON fromString: (STON toString: graph)) = graph
			ifFalse: [ PerfUMateBrokenInvariant signal: 'round trip' ] ]

My message is part of the finding's signature, so different broken properties are reported as
different findings even when they are signaled from the same method.
"
Class {
	#name : 'PerfUMateBrokenInvariant',
	#superclass : 'Error',
	#category : 'PerfUMate-Core',
	#package : 'PerfUMate',
	#tag : 'Core'
}
