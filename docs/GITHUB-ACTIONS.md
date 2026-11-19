# Running PerfUMate in GitHub Actions

PerfUMate campaigns run as SUnit tests, so any CI that runs Pharo tests can run them. This guide
uses [smalltalkCI](https://github.com/hpi-swa/smalltalkCI) on GitHub Actions with three
triggers: a short campaign on every pull request, a long one every night, and a manual run with
the budget you choose.

How it fits together:

- a test class in your project subclasses `PerfUMateCampaignTest` and calls `assertNoFindings:`;
  the test fails when the campaign finds something;
- `PERFUMATE_BUDGET` (seconds) overrides the budget written in the test, so the same test runs
  for 1 minute on a pull request and 30 minutes at night;
- every campaign writes `<name>.md` (summary, minimized inputs) and `<name>-tests.st` (the
  generated SUnit methods) into `PERFUMATE_OUT`, which the workflow keeps as an artifact.

## 1. A campaign test in your project

Put campaigns in their own package, so the regular test job does not run them:

```smalltalk
PerfUMateCampaignTest << #CheckoutFuzzingTest
    package: 'MyShop-Fuzzing'.

CheckoutFuzzingTest >> testNoSlowCheckouts [
    self assertNoFindings: (PerfUMate new
        name: 'checkout-slow';
        examples: MyShopExamples orders;
        benchmark: [ :order | Checkout new process: order ];
        slowdown: 10;            "CI machines are noisy, be less strict than locally"
        budget: 1 minute)        "used when PERFUMATE_BUDGET is not set"
]

CheckoutFuzzingTest >> testNoCrashingCheckouts [
    self assertNoFindings: (PerfUMate new
        name: 'checkout-errors';
        examples: MyShopExamples orders;
        benchmark: [ :order | Checkout new process: order ];
        lookFor: #errors;
        instrument: { 'MyShop' };
        budget: 1 minute)
]
```

`assertNoFindings:` sets the test's time limit from the budget, runs the campaign, saves the
report and fails with the summary as message.

## 2. Load PerfUMate only for fuzzing

In your baseline, a group that adds PerfUMate and the fuzzing package:

```smalltalk
spec baseline: 'PerfUMate' with: [ spec repository: 'github://FedeLoch/PerfUMate:main' ].
spec package: 'MyShop-Fuzzing' with: [ spec requires: #( 'MyShop' 'PerfUMate' ) ].
spec group: 'fuzzing' with: #( 'MyShop-Fuzzing' ).
```

## 3. A smalltalkCI file for the fuzzing job

`.smalltalk.fuzz.ston`, next to your usual `.smalltalk.ston`:

```
SmalltalkCISpec {
  #preLoading : 'scripts/preLoading.st',
  #loading : [
    SCIMetacelloLoadSpec {
      #baseline : 'MyShop',
      #directory : 'src',
      #load : [ 'fuzzing' ],
      #onConflict : #useIncoming,
      #platforms : [ #pharo ]
    }
  ],
  #testing : {
    #packages : [ 'MyShop-Fuzzing' ]
  }
}
```

`scripts/preLoading.st` is needed while loading Mate's dependencies downloads files from GitHub
(Bloc's fonts): GitHub answers with header lines longer than Zinc accepts. Copy it from this
repository ([scripts/preLoading.st](../scripts/preLoading.st)):

```smalltalk
ZnConstants class
    compile: 'maximumLineLength
    ^ 65536'
    classified: 'accessing'.
```

## 4. The workflow

`.github/workflows/fuzzing.yml`:

```yaml
name: Fuzzing

on:
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 3 * * *'          # every night at 03:00 UTC
  workflow_dispatch:
    inputs:
      budget:
        description: 'Seconds per campaign'
        default: '600'

permissions:
  contents: read
  issues: write

jobs:
  fuzz:
    runs-on: ubuntu-latest
    timeout-minutes: 120
    env:
      PERFUMATE_OUT: ${{ github.workspace }}/perfumate-out
      PERFUMATE_BUDGET: ${{ github.event_name == 'pull_request' && '60' || github.event_name == 'schedule' && '1800' || inputs.budget }}
    steps:
      - uses: actions/checkout@v4

      - uses: hpi-swa/setup-smalltalkCI@v1
        with:
          smalltalk-image: Pharo64-13

      - name: Run campaigns
        run: smalltalkci -s Pharo64-13 .smalltalk.fuzz.ston
        timeout-minutes: 110

      - name: Keep the reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: perfumate-reports
          path: perfumate-out
          if-no-files-found: ignore

      - name: Open an issue for nightly findings
        if: failure() && github.event_name == 'schedule'
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          cat perfumate-out/*.md > findings.md
          gh issue create --title "PerfUMate findings $(date +%F)" --body-file findings.md
```

What each trigger does:

| Trigger | Budget per campaign | Purpose |
| --- | --- | --- |
| `pull_request` | 1 minute | catch regressions a change introduces, quickly |
| `schedule` | 30 minutes | longer searches, new seeds every night |
| `workflow_dispatch` | your input | a long run before a release, or to reproduce a finding |

Keep the budget times the number of campaigns under the job's `timeout-minutes`. Each campaign
also needs time to load (smalltalkCI builds the image once per job, about 5 to 10 minutes with
Mate's dependencies).

## 5. Turning a finding into a regression test

Download the `perfumate-reports` artifact. `<name>-tests.st` holds the generated test methods:
paste them into a `PerfUMateGeneratedTest` subclass in your regular test package (or run the
campaign locally and call `report generateTestsIn:package:`). The test fails until the problem is
fixed and then guards against it coming back, in the regular CI job, without fuzzing.

## Tips

- Timing on shared runners is noisy. Use a higher `slowdown:` in CI than locally, or count with
  `measure: #methodCalls` and `instrument:`, which does not depend on the machine.
- Pull request runs can use `seed:` so the same change always runs the same search; nightly runs
  should not, so each night explores something new.
- Several projects can share one nightly workflow with a matrix over repositories, each with its
  own `.smalltalk.fuzz.ston`.
- Running only on a schedule is fine too: drop the `pull_request` trigger.
