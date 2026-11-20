"Runs the campaigns a class declares, for the PerfUMate GitHub Action.
Environment:
	PERFUMATE_CAMPAIGNS  the class whose class-side <perfumate> methods answer the campaigns
	PERFUMATE_OUT        where to write the reports
	PERFUMATE_BUDGET     seconds per campaign (read by PerfUMate itself)
	PERFUMATE_THEME      the theme the charts are drawn with (DarkBlueTheme by default)"

| env out results |
env := Smalltalk os environment.
out := Stdio stdout.
(Smalltalk at: (env at: 'PERFUMATE_THEME' ifAbsent: [ 'DarkBlueTheme' ]) asSymbol ifAbsent: [ nil ])
	ifNotNil: [ :theme | theme beCurrent ].
[
	results := PerfUMate
		runCampaignsIn: (env at: 'PERFUMATE_CAMPAIGNS')
		into: (env at: 'PERFUMATE_OUT' ifAbsent: [ 'perfumate-out' ]).
	results do: [ :each | out nextPutAll: each key, ': ', each value printString; lf ].
	out flush ]
	on: Error
	do: [ :error |
		out nextPutAll: 'The campaigns could not run: ', error class name, ': ', error messageText asString; lf; flush.
		Smalltalk exit: 1 ].
