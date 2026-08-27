## [Unreleased]

- Add encrypted history support: `Configuration#encrypt_history` global default, class-level
  `encrypt_history` macro (inherited down subclasses), and instance-level `encrypt_history`/
  `clear_history` overrides for `Action#inertia_render`'s `encryptHistory`/`clearHistory`
  envelope flags.

## [0.1.0] - 2026-08-20

- Initial release
