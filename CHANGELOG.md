## [Unreleased]

- Add encrypted history support: `Configuration#encrypt_history` global default, class-level
  `encrypt_history` macro (inherited down subclasses), and instance-level `encrypt_history`/
  `clear_history` overrides for `Action#inertia_render`'s `encryptHistory`/`clearHistory`
  envelope flags.
- Fix `Props::Once` support end-to-end: `RequestContext` now parses the
  `X-Inertia-Except-Once-Props` header and feeds it into `ProtocolBuilder`, and the `onceProps`
  envelope entries now include the `prop` dot-path the client's caching logic requires (was
  previously omitted, so the once-cache could never engage). `fresh: true` now correctly forces
  re-resolution even when the client reports the prop as cached.
- Add `Props::Scroll` for the client's infinite-scroll feature: merges (appended or prepended,
  per the `X-Inertia-Infinite-Scroll-Merge-Intent` header) instead of replacing the existing
  prop, and reports pagination metadata via the response's `scrollProps` map.

## [0.1.0] - 2026-08-20

- Initial release
