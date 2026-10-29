# Contributing

## Clean-room rules

Sideload reimplements publicly documented Apple APIs from
developer.apple.com. To keep the project on solid legal ground:

- Never add Apple headers, `.swiftinterface` files, Xcode templates, SDK
  stubs, or disassembled framework code to the repository, and don't use
  them as working references.
- Type and method names, signatures, and documented behavior come only from
  Apple's public documentation.
- Anyone who has studied Apple framework internals under NDA should not
  contribute to the areas those internals cover.
- Don't vendor Apple fonts (SF Pro) or SF Symbols artwork. Use the vendored
  open alternatives in `Resources/`.
- Undocumented behavior (exact spacing, default sizes, etc.) is a judgment
  call: pick a reasonable value, and record it with your reasoning in
  `Docs/known-differences.md`. Never guess silently.

## Sign your commits

Every commit must carry a Developer Certificate of Origin sign-off:

```
git commit -s
```

This adds a `Signed-off-by: Your Name <email>` trailer certifying you wrote
the patch or otherwise have the right to submit it under the project's
license.

## Module layout

- `Sources/SDK/*` — modules apps import. Names and public API must match
  Apple's documented surface exactly; nothing extra leaks into this
  namespace.
- `Sources/Sideload/*` — internal implementation modules (`Sideload*`
  prefix), never imported by application code.

## Tests

Parser and layout-engine changes need tests written before the implementation
where practical. Every bug fix should add a regression test.
