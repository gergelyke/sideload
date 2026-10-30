# Vendored asset versions

| Asset | Source | Pinned at | License |
|---|---|---|---|
| `Fonts/Inter/Inter-Variable.ttf` | https://github.com/google/fonts, `ofl/inter/Inter[opsz,wght].ttf` | commit `9862abc066c9b83bf84c3e8ed1fc2d8d48f9bbf0` | SIL OFL 1.1 (`Fonts/Inter/OFL.txt`) |
| `Symbols/lucide/*.svg` | https://github.com/lucide-icons/lucide, `icons/` | commit `be09619c1c1124ad09c19fc3e87ee3b939409bbd` | ISC (`Symbols/lucide/LICENSE`) |

Inter is vendored as a single variable font (weight axis `wght`) rather than
four static instances: FreeType/HarfBuzz can select any weight along the
axis at shaping time, so one file covers Regular/Medium/SemiBold/Bold
without extra vendored binaries. See `Docs/known-differences.md`.
