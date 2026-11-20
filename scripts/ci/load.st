"Loads PerfUMate and the project to fuzz into the image, for the PerfUMate GitHub Action.
Environment:
	PERFUMATE_SOURCE      where to load PerfUMate from (github://FedeLoch/PerfUMate:main)
	PERFUMATE_BASELINE    the project's baseline name, without BaselineOf
	PERFUMATE_REPOSITORY  the project's repository (tonel://<checkout>/<directory>)
	PERFUMATE_GROUPS      the baseline groups to load, separated by commas"

| env out load |
env := Smalltalk os environment.
out := Stdio stdout.
"GitHub answers some downloads made while loading (Bloc's fonts) with header lines longer than
Zinc accepts"
ZnConstants class compile: 'maximumLineLength
	^ 65536' classified: 'accessing'.
load := [ :baseline :repository :groups |
	out nextPutAll: 'Loading ', baseline, ' from ', repository; lf; flush.
	Metacello new
		baseline: baseline;
		repository: repository;
		onConflictUseIncoming;
		onWarning: [ :warning | warning resume ];
		load: groups ].
[
	load value: 'PerfUMate' value: (env at: 'PERFUMATE_SOURCE' ifAbsent: [ 'github://FedeLoch/PerfUMate:main' ]) value: #( 'core' ).
	load
		value: (env at: 'PERFUMATE_BASELINE')
		value: (env at: 'PERFUMATE_REPOSITORY')
		value: ((env at: 'PERFUMATE_GROUPS' ifAbsent: [ 'default' ]) substrings: ', ') asArray.
	out nextPutAll: 'Loaded'; lf; flush ]
	on: Error
	do: [ :error |
		out nextPutAll: 'Loading failed: ', error class name, ': ', error messageText asString; lf.
		(error signalerContext stack first: 15) do: [ :context | out nextPutAll: '  ', context printString; lf ].
		out flush.
		Smalltalk exit: 1 ].
