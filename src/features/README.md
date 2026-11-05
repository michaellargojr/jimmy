# src/features: drafts behind flags

Everything in this folder is **not part of the shipped app** until its flag in
`flags.ts` is turned on. The code compiles, is type-checked and linted with the
rest of the repo, and can be tried on a device without a rebuild:

```js
// in the browser console, then reload
localStorage.setItem('jimmy.flags', JSON.stringify({ news: true, pose3d: true }))
```

Rules for a feature folder:

- One folder per feature, with a `README.md` that states purpose, status, what is
  real and what is placeholder, and the exact wiring points in the main app.
- The main app may import only the feature's `routes.tsx` (or a single tiny entry
  component) and must gate it on `FEATURES.<name>`. Everything heavy behind
  `React.lazy` so a flag that is off costs nothing in the main bundle.
- Feature CSS lives next to the feature and is imported by its lazy pages.
- No new runtime dependencies without a note in the feature README explaining the
  bundle cost (the whole app is ~380 KB of JS today).
- Placeholder data must be obviously placeholder. Never ship invented facts about
  real people.

Current drafts:

| Folder    | Flag     | What                                                     |
|-----------|----------|----------------------------------------------------------|
| `news/`   | `news`   | Bodybuilding news, Mr. Olympia top 10, athlete profiles with favourite exercises and videos |
| `pose3d/` | `pose3d` | Two-state (start / end) exercise animation on the exercise card |
