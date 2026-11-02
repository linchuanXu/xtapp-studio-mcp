# Chinese Chess Review Setup

Repository files provide the mechanical Chinese chess workflow, PR checklist, scope policy, and Bugbot review guidance. Bugbot itself is not a GitHub Action: automatic review is supplied by the Cursor GitHub App.

An organization or repository administrator must complete this setup manually:

1. Install the Cursor GitHub App and grant it access to this repository.
2. Enable the repository in Cursor Automations and enable automatic Bugbot review.
3. In the protected-branch ruleset, require the `Cursor Bugbot` check and keep that required check restricted to the app as its expected source.
4. Enable fail-on-unresolved-issues where that Cursor setting is available. Without it, a neutral Bugbot conclusion can otherwise pass the check while review findings remain unresolved.
5. Require conversation resolution and at least one human approval.
6. Require the repository workflow checks. The exact required check contexts are `Web quality gate` and `Chinese chess quality gate`; their parent workflows are informationally named Verify and Chinese Chess Review.

Branch protection and rulesets cannot be configured by repository files; an administrator must apply and audit these settings in GitHub and Cursor after installation.

The mechanical CI remains independent of Bugbot availability. The scope checker, Chinese chess tests, benchmark gate, lint, and build continue to run on pull requests if the Cursor GitHub App is unavailable or its review is delayed.
