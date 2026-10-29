# MVP retrospective

Written after M7 landed and `Tools/hello.sh` printed `E2E OK`.

## What was harder than expected

- **Swift concurrency checking on internal protocols.** Every internal
  helper protocol in the SwiftUI module (`_ResolvableView`,
  `_ChildrenProviding`, `_SceneContentProviding`) needed its requirements
  individually marked `@MainActor`, even though every conforming type is
  already `@MainActor` by inference from `View`/`Scene`. The compiler
  doesn't propagate isolation through a second, unrelated protocol
  conformance — only through the one that actually declares the
  isolation. This cost a few rebuild cycles per file the first time it
  came up; once recognized it was mechanical.
- **Vendoring a single variable Inter font instead of four static
  weights.** Neither `google/fonts` nor `rsms/inter` commits static
  instances to their repos anymore (both ship a variable font and expect
  consumers to instance it). FreeType's `FT_Get_MM_Var`/
  `FT_Set_Var_Design_Coordinates` needed `FT_MULTIPLE_MASTERS_H`, which
  the initial `CFreeType` shim didn't include.
- **Reconciling SwiftUI's `ViewBuilder` parameter-pack overload with
  Swift's actual pack-iteration syntax.** `repeat each` inside an
  expression works for building a tuple; turning that tuple back into
  `[any View]` needed the statement form (`repeat result.append(each
  value)`), which isn't documented side-by-side with the expression form
  in many places.
- **SVG numbers without separators.** Lucide's exported SVGs concatenate
  adjacent decimals like `.53.53` (two numbers, one dot each) with no
  space between them. A naive "consume digits and dots" scanner reads
  that as one malformed number; the fix was tracking whether the current
  number has already seen a decimal point.
- **`xvfb-run`'s SIGUSR1 readiness handshake doesn't fire inside this
  sandbox's nested container.** Starting `Xvfb` directly and sleeping a
  couple of seconds before setting `DISPLAY` sidesteps it. `Tools/e2e.sh`
  does this explicitly; if a future CI runner has the same limitation,
  prefer this over `xvfb-run -a`.

## What Phase 1 should change

- **Alignment is centered-only.** `VStack`/`HStack` accept an
  `alignment:` parameter but ignore it. Phase 1's layout work should
  implement leading/trailing/top/bottom alignment properly — the
  propose-then-place `LayoutNode` protocol already has the right shape
  for it.
- **Text never wraps.** Every `Text` lays out as one line regardless of
  the proposed width. Multi-line layout needs HarfBuzz's own line
  breaking (or a simple greedy word-wrap) before Phase 1 can support
  anything beyond single-line labels.
- **The Objective-C interop spike and the `os(iOS)` decision are still
  open**, exactly as Phase 0 planned — they weren't needed to get
  SwiftUI's subset working, but they gate whether Phase 3 (UIKit) can
  start before or needs to wait on Phase 1 finishing. Worth doing early
  in whichever phase comes next, since the project plan calls out that
  they can reorder the roadmap.
- **The generated package's diagnostic rewriting is a plain substring
  replace** on whole lines. It works today because the generated target
  has one source directory and the fixture has no filename collisions,
  but it will need real range-aware rewriting once multiple targets or
  SwiftPM dependencies enter the picture.
- **Device profiles have no corner radius or notch/island cutout
  geometry** — the JSON schema has an optional `cornerRadius` field that
  nothing reads yet. Worth filling in once the shell actually draws a
  device frame.
