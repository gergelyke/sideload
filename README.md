# Sideload

Sideload is an open-source, source-compatible iOS SDK for Linux. Point it at
your own Xcode or Swift Package Manager project; it compiles your code with
the official Linux Swift toolchain against clean-room SwiftUI/UIKit
frameworks, and runs the result as a native Linux process in a phone-shaped
window.

Because Sideload only runs apps built from your own source, there is no
Mach-O loader, no XNU kernel emulation, no CPU translation, no FairPlay, and
no Apple firmware involved. No Apple software is copied, shipped, or run.

## Status

MVP: a single-screen SwiftUI app builds from an unmodified Xcode project and
renders in a window or a headless screenshot. See `Docs/known-differences.md`
for behavior that intentionally differs from real iOS, and the project plan
doc for the full roadmap.

## Quick start

```
Tools/hello.sh
```

builds the dev container, builds the `Fixtures/HelloWorld` sample app, runs
it headless, and writes `hello.png` to the repo root. `Tools/hello.sh
--window` runs the app in a real window on your desktop (requires a local
Swift toolchain).

## Building from source

```
swift build
swift test
```

System dependencies: `libcairo2-dev`, `libsdl2-dev`, `pkg-config`,
`libharfbuzz-dev`, `libfreetype-dev` (see `Tools/docker/Dockerfile`).

## License

Apache-2.0 with the Swift Runtime Library Exception — see `LICENSE`. Apps
that link against the SDK carry no obligations from that license.
