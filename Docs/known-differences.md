# Known differences from real iOS

Sideload reproduces app behavior and layout, not Apple's exact pixels.
Every place we had to guess at undocumented behavior is recorded here, with
the value we chose and why.

| Behaviour | Sideload value | Reason | Verified against HIG? |
|---|---|---|---|
| Body text font | Inter (variable font, `wght` axis) | SF Pro is licensed for Apple platforms only; Inter is metrically similar and open (SIL OFL) | No |
| SF Symbols | Mapped subset of Lucide icons (`Resources/Symbols/sf-map.json`); unmapped names draw a labelled placeholder box | SF Symbols artwork is licensed for Apple platforms only | No |
| Device profile geometry (`phone-6.1`, `phone-6.1-island`, `phone-6.7-island`, `phone-4.7-se`) | Point size, scale and safe-area insets in `Resources/DeviceProfiles/*.json`, taken from published iPhone specs | No corner radius or Dynamic Island cutout modeled yet; numbers should be cross-checked against Apple's Human Interface Guidelines | No |
| `Font.body`/`.title`/`.largeTitle` point sizes | 17 / 28 / 34 pt | Apple's exact Dynamic Type table isn't public; these are the commonly cited defaults | No |
| Default `VStack`/`HStack` spacing | 8 pt | Commonly cited SwiftUI default; not from Apple documentation | No |
| Default `.padding()` amount | 16 pt per edge | Commonly cited SwiftUI default; not from Apple documentation | No |
| `Image.Scale` multiplier vs. font point size | small 0.8×, medium 1.0×, large 1.3× | No public formula; chosen to look proportionate at `.body` size | No |
| `VStack`/`HStack` alignment | Always centers on the cross axis; the `alignment:` parameter is accepted but not yet honored | MVP scope — only the fixture's centered layout is needed | No |
| Text layout | Single line, no wrapping, no Dynamic Type scaling | MVP scope | No |
