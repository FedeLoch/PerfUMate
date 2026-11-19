"GitHub answers some downloads made while loading the dependencies (Alexandrie fetches its
fonts, through Mate -> BlocBenchs -> Bloc) with header lines longer than Zinc's 4096 limit,
which makes the load fail with ZnLineTooLong. Raise the limit before loading."
ZnConstants class
	compile: 'maximumLineLength
	^ 65536'
	classified: 'accessing'.
