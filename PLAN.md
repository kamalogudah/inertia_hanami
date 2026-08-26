# inertia_hanami — Implementation Plan

Server-side adapter implementing the [Inertia.js protocol](https://inertiajs.com/docs/v2/installation/community-adapters)
for [Hanami](https://hanakai.org/hanami) (targeting **Hanami 3.0+**, Ruby 3.3+).

No prior Hanami/Inertia integration exists (verified via GitHub/forum search) — this is greenfield.
Design is synthesized from two existing Ruby adapters:

- **[inertia-rails](https://github.com/inertiajs/inertia-rails)** — the reference implementation. Full protocol
  coverage (deferred/merge/once props, SSR, encrypted history, testing helpers). Deeply coupled to Rails/ActiveSupport
  (`ActionController::Renderers`, `deep_merge!`, `HashWithIndifferentAccess`, Rails middleware stack, engine/railtie).
- **[inertia-rage](https://github.com/rage-rb/inertia-rage)** — proves the protocol is portable to a non-Rails,
  non-ActiveSupport Ruby framework. Zero dependency on `inertia_rails`; clean-room reimplementation. Structurally the
  closer template for us, since Rage (like Hanami) is Rack-based with its own controller/config/plugin conventions
  and no ActiveSupport. It's missing SSR support and only ships RSpec helpers — gaps we should not blindly copy.

## What to take from each, concretely

| Concern | Take from | Why |
|---|---|---|
| Protocol envelope shape, header names, prop-type taxonomy | inertia-rails | It's the canonical spec; inertia-rage's prop set is a subset |
| Partial-reload resolution algorithm (only/except/reset/dot-paths) | inertia-rails (`props_resolver.rb`), cross-checked against inertia-rage's `protocol_builder.rb` | Same algorithm, inertia-rage's version is already ActiveSupport-free and shorter — better starting point to port |
| Prop wrapper classes (`Optional`, `Defer`, `Merge`, `Always`, `Once`) | inertia-rage's `Data`-based implementation | Ruby's builtin `Data` class needs no ActiveSupport; inertia-rails uses plain classes + mixins, functionally equivalent but rage's is more idiomatic modern Ruby |
| Controller/action integration pattern | Neither directly — Hanami's own `#auto_render?` + module `include` idiom | Hanami actions favor composition (`include Inertia::Action`) over subclassing a framework base class the way both Rails (`ActionController::Base`) and Rage (`RageController::Inertia`) do |
| Middleware (version-mismatch 409, redirect-to-303 rewrite) | inertia-rails logic, inertia-rage's leaner Rack-only style | Same responsibilities, but implement as plain Rack middleware with no framework hooks, registered via `config.middleware.use` |
| CSRF handling | **Neither** — reuse Hanami/Rack's own CSRF middleware | inertia-rails uses Rails' token CSRF; inertia-rage hand-rolls `Sec-Fetch-Site` checks. Hanami ships its own session/CSRF story via `hanami-controller` — bridge to that instead of reimplementing either |
| Configuration mechanism | Hanami's own `register_provider` / container DI | Neither Rails initializers nor Rage's `Rage::Extension` apply; Hanami's provider system is the idiomatic equivalent |
| Asset versioning | Concept from both (`ssr_bundle`/manifest hash, Vite manifest) | Adapted to `hanami-assets`' `assets.json` manifest instead of Vite's `manifest.json` |
| SSR | inertia-rails only (inertia-rage has none) | Defer to a later phase; inertia-rails' `SSRRenderer` (POST page JSON to a Node process, cache by content hash) is the pattern to port |
| Testing helpers | inertia-rails' RSpec matcher set (broader than inertia-rage's) | Port `have_props`, `have_exact_props`, `render_component`, `be_inertia_response`, etc. |

## Target Hanami integration points (from architecture research)

- `Hanami::Action#handle(request, response)` is the Rack entrypoint. `response.format=`, `response.body=`,
  `response.headers`, `response[:key]=` (exposures) are all directly settable — no forced rendering step.
- `#auto_render?(response)` returning `false` is the exact bypass point for JSON-only Inertia XHR responses (avoids
  Hanami auto-invoking the paired `Views::*` class for `X-Inertia: true` requests).
- Layouts (`config.layout = "app"`, `app/views/layouts/app.html.erb` convention) are the analog of Rails'
  `application.html.erb` — used only for the **initial full-page load**, rendering `<div id="app" data-page="...">`.
- `config/providers/*.rb` + `Hanami.app.register_provider` is where gem-level configuration
  (`version`, `ssr_url`, `component_path_resolver`, etc.) gets registered as a container component
  (`"inertia.config"`), consumed via `include Deps["inertia.config"]` — the Hanami equivalent of
  `InertiaRails.configure`.
  - Verified against the installed `hanami` (3.0.2) / `dry-system` (1.2.5) / `dry-configurable` (1.4.0)
    gem source (Hanami's own built-in providers, e.g. `Hanami::Providers::DB`, `Hanami::Providers::I18n`,
    follow the same pattern):
    - **Namespacing is not automatic.** `register("config", obj)` inside a provider named `:inertia`
      only resolves to container key `"inertia.config"` when the provider is registered with
      `namespace: true` (`Hanami.app.register_provider(:inertia, namespace: true, source: InertiaHanami::Provider)`).
      Without it, the key would just be `"config"`.
    - **dry-configurable 1.4 does not delegate setting names onto the including instance.** A class that
      `include Dry::Configurable` and defines `setting :version` does *not* get an instance method
      `#version` — settings are only reachable via `#config` (e.g. `instance.config.version`). Confirmed
      empirically (`instance.respond_to?(:version) # => false`) and in every built-in Hanami provider,
      which reads its own settings as `config.foo`, never `self.foo`.
    - Consequence for this doc's literal usage below (`Hanami.app["inertia.config"].version`) to hold with
      no extra `.config.` hop: the provider must register the `Dry::Configurable::Config` object itself —
      `register("config", InertiaHanami::Configuration.new.config)` — not the `Configuration` instance.
- `config.middleware.use` in `config/app.rb` registers Rack middleware app-wide; per-route middleware is also
  supported via `use` inside route `scope` blocks.
- `hanami-assets` compiles to `public/assets/` with a manifest `assets.json` (source → hashed filename) — this
  supplies the Inertia asset **version** string (hash of `assets.json`), same role Vite's `manifest.json` plays for
  inertia-rage.
- Action testing is DI-based (`Action.new(deps...).call(params)`, no HTTP roundtrip needed) — good fit for unit
  testing the prop-resolution engine directly; `rack-test` (bundled) covers full-stack request specs.

## Gem architecture

```
lib/inertia_hanami.rb                       # entrypoint, requires + configure block
lib/inertia_hanami/version.rb
lib/inertia_hanami/configuration.rb          # `include Dry::Configurable`; settings (version, ssr, root_view,
                                              #   component_path_resolver, root_dom_id...) read via #config, dry-configurable 1.4 style
lib/inertia_hanami/provider.rb               # Hanami::Provider::Source; registers Configuration.new.config as "config" under
                                              #   `register_provider(:inertia, namespace: true, ...)` -> resolves to "inertia.config"
lib/inertia_hanami/props.rb                  # Optional/Defer/Merge/Always/Once wrappers, Ruby Data-based (port from inertia-rage)
lib/inertia_hanami/prop_evaluator.rb         # resolves Proc/BaseProp props against action instance
lib/inertia_hanami/protocol_builder.rb       # partial-reload resolution: only/except/reset/dot-paths (port+adapt from inertia-rage)
lib/inertia_hanami/request_context.rb        # parses X-Inertia-Partial-* / X-Inertia-Version headers off Rack env
lib/inertia_hanami/renderer.rb               # builds the page envelope hash, decides JSON vs HTML branch
lib/inertia_hanami/action.rb                 # `Inertia::Action` module: include-able into Hanami::Action subclasses
                                              #   - #auto_render?(response) => false when request.inertia?
                                              #   - #inertia_render(component, props: {}, **opts)
                                              #   - #inertia_share(**props) class + instance macro
                                              #   - #inertia_location(url) for external redirects
lib/inertia_hanami/middleware/version.rb     # 409 + X-Inertia-Location on version mismatch (GET only)
lib/inertia_hanami/middleware/redirects.rb   # rewrite 301/302 -> 303 for PUT/PATCH/DELETE inertia requests
lib/inertia_hanami/ssr_renderer.rb           # (phase 3) POST page JSON to Node SSR server, cache by digest
lib/inertia_hanami/helper.rb                 # view helper: inertia_root(page) -> data-page div/script tag
lib/inertia_hanami/errors.rb
lib/inertia_hanami/testing/rspec.rb          # matchers: have_props, have_exact_props, be_inertia_response, render_component...

app/views/layouts/app.html.erb (generator template) -> renders <%= inertia_root(page: page) %>
lib/generators/inertia_hanami/install_generator.rb  # (phase 2) scaffolds provider, layout, npm deps, example page
```

## Protocol mechanics (ported from inertia-rails spec, verified against inertia-rage's leaner implementation)

- **Detection**: `request.env['HTTP_X_INERTIA'] == 'true'` (mirrors `ActionDispatch::Request#inertia?`).
- **Response envelope**: `{component, props, url, version, encryptHistory, clearHistory}` (+ `deferredProps`,
  `mergeProps`, `deepMergeProps`, `matchPropsOn` metadata when relevant props are present).
- **On Inertia request** (`X-Inertia: true` header present): set `X-Inertia: true` response header,
  `response.format = :json`, `response.body = [page.to_json]`. Skip Hanami's auto view rendering via `#auto_render? => false`.
- **On initial load** (no `X-Inertia` header): render the layout with `inertia_root(page:)` embedding
  `<div id="app" data-page="#{page.to_json}"></div>`.
- **Version mismatch**: `Middleware::Version` compares `X-Inertia-Version` request header against
  `Hanami.app["inertia.config"].version` on GET only; mismatch → `409` + `X-Inertia-Location` (empty body), so the
  client does a full browser visit and picks up new assets.
- **Redirects**: rewrite `301/302` → `303` when the original method was PUT/PATCH/DELETE, so the browser doesn't
  resubmit the body on the client-side follow-up GET. External-origin redirects on an Inertia request become
  `409 + X-Inertia-Location` instead of a normal redirect (SPA can't follow cross-origin redirects via XHR).
- **Partial reloads**: `X-Inertia-Partial-Component` must match the component about to render, else partial mode is
  ignored. `X-Inertia-Partial-Data` (only) / `X-Inertia-Partial-Except` (except) are comma-separated dot-paths.
  `AlwaysProp` bypasses filtering; `Optional`/`Defer` props are excluded unless explicitly requested; `Once` props
  are excluded once already sent (tracked via `X-Inertia-Reset` / an except-once header) — port inertia-rage's
  `ProtocolBuilder` (~180 lines, already ActiveSupport-free) rather than inertia-rails' more Rails-idiomatic version.
- **Shared props**: `inertia_share(**hash, &block)` macro accumulates into an instance-level hash, block form
  `instance_exec`'d against the action at render time, merged (shallow, no need to reimplement `deep_merge!` unless
  a real use case demands it — start simple).

## Phased roadmap

**Phase 0 — scaffolding & spec baseline**
- Fill in gemspec (summary, homepage, dependencies: none required at runtime besides Ruby stdlib `json`; dev deps:
  `hanami`, `hanami-controller`, `hanami-view`, `rack-test`, `rspec`).
- Set up a `spec/dummy_app` (minimal Hanami 3 app) for integration specs, matching how inertia-rails/inertia-rage
  test against real dummy apps rather than mocks.

**Phase 1 — MVP protocol (no SSR, no generators)**
- `Configuration` + provider registration.
- `Props` wrappers + `PropEvaluator` + `ProtocolBuilder` (ported from inertia-rage, adapted naming).
- `RequestContext` header parsing.
- `Renderer` + `Action` module (`inertia_render`, `inertia_share`, `#auto_render?` override).
- `Middleware::Version`, `Middleware::Redirects`.
- `Helper#inertia_root` + example layout template.
- Manual end-to-end test: dummy app renders a component, partial reload works, version-mismatch 409 works.

**Phase 2 — DX & polish**
- Install generator (scaffolds provider file, layout, adds `@inertiajs/*` guidance to package.json, sample page).
- Asset-version integration: derive `Configuration#version` automatically from `hanami-assets`' `assets.json` digest
  when not explicitly set.
- RSpec testing helpers (`have_props`, `have_exact_props`, `have_no_prop`, `be_inertia_response`,
  `render_component`, partial-reload request helpers).
- `flash`/`errors` prop wiring (Hanami session integration) analogous to inertia-rails' `always_include_errors_hash`.

**Phase 3 — SSR (optional, follow inertia-rails' design)**
- `SSRRenderer`: POST `page.to_json` to a configurable `ssr_url` (Node process), expects `{head:, body:}` JSON,
  render into the layout in place of the CSR div, cache by content digest, fall back to CSR on error
  (`ssr_raise_on_error` config toggle). No process-supervision plugin needed initially (unlike inertia-rails' Puma
  plugin) — document running the Node SSR server as a separate process.

**Phase 4 — protocol completeness / parity audit**
- Encrypted history (`encryptHistory`/`clearHistory` session flags).
- `Once`/scroll/infinite-scroll props if there's demand.
- CSRF: confirm Hanami/Rack session middleware already covers the `X-XSRF-TOKEN` ↔ cookie handshake Inertia's
  client expects; add a thin bridge only if a gap is found — don't hand-roll CSRF from scratch like inertia-rage did.

## Open questions to resolve empirically against a real Hanami 3.0 app (docs were incomplete on these)

1. Exact default layout file path/naming convention in Hanami 3.0 (`app/views/layouts/app.html.erb` assumed,
   needs confirming against a generated app).
2. Whether a provider can push onto `config.middleware` at boot time, or whether middleware registration must live
   in `config/app.rb` directly (affects whether the gem can self-register middleware via an install generator vs.
   requiring a manual `config.middleware.use InertiaHanami::Middleware::Version` line).
3. Per-route middleware/`use` block scoping semantics — needed if we want an opt-in per-route Inertia mode rather
   than app-wide.
