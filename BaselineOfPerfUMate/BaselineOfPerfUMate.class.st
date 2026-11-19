Class {
	#name : 'BaselineOfPerfUMate',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfPerfUMate',
	#package : 'BaselineOfPerfUMate'
}

{ #category : 'baselines' }
BaselineOfPerfUMate >> baseline: spec [

	<baseline>
	spec for: #common do: [
		"Ume's own baseline loads Mate and Shin from main too, so the three agree"
		spec baseline: 'Ume' with: [ spec repository: 'github://FedeLoch/Ume:main' ].
		spec baseline: 'Mate' with: [ spec repository: 'github://FedeLoch/Mate:main' ].
		spec baseline: 'Shin' with: [ spec repository: 'github://FedeLoch/Shin:main' ].

		spec package: 'PerfUMate' with: [ spec requires: #( 'Ume' 'Mate' 'Shin' ) ].
		spec package: 'PerfUMate-Tests' with: [ spec requires: #( 'PerfUMate' ) ].
		spec package: 'PerfUMate-Campaigns' with: [ spec requires: #( 'PerfUMate' ) ].

		spec group: 'core' with: #( 'PerfUMate' ).
		spec group: 'campaigns' with: #( 'PerfUMate-Campaigns' ).
		spec group: 'default' with: #( 'PerfUMate' 'PerfUMate-Tests' ) ]
]
