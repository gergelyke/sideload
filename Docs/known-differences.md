# Known differences from real iOS

Sideload reproduces app behavior and layout, not Apple's exact pixels.
Every place we had to guess at undocumented behavior is recorded here, with
the value we chose and why.

| Behaviour | Sideload value | Reason | Verified against HIG? |
|---|---|---|---|
| Body text font | Inter (variable font, `wght` axis) | SF Pro is licensed for Apple platforms only; Inter is metrically similar and open (SIL OFL) | No |
| SF Symbols | Mapped subset of Lucide icons (`Resources/Symbols/sf-map.json`); unmapped names draw a labelled placeholder box | SF Symbols artwork is licensed for Apple platforms only | No |
