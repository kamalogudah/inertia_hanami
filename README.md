# InertiaHanami

Server-side adapter implementing the [Inertia.js protocol](https://inertiajs.com/) for the
[Hanami](https://hanamirb.org) web framework.

## Installation

Add the gem to your Hanami app's Gemfile in **both** the default and `:cli` groups. The `:cli`
group is required for the `hanami generate inertia:install` command below to be available -
Bundler's `Hanami::CLI::Bundler.require(:cli)` is what loads it before `hanami` dispatches
commands:

```ruby
gem "inertia_hanami", groups: [:default, :cli]
```

Then run:

```bash
bundle install
bundle exec hanami generate inertia:install
```

This scaffolds:

- `config/providers/inertia.rb` - registers the gem's configuration with the app container.
- `config.middleware.use InertiaHanami::Middleware::Version` / `::Redirects` / `::Csrf` in
  `config/app.rb`.
- `app/templates/layouts/app.html.erb` - the initial full-page-load layout, rendering
  `<%= inertia_root(page: page) %>`.
- `app/views/helpers.rb` - includes `InertiaHanami::Helper` so `inertia_root` is callable
  unqualified from templates.
- A sample page (`app/actions/inertia_example/show.rb`, `app/views/inertia_example/show.rb`,
  `app/templates/inertia_example/show.html.erb`) plus a matching route in `config/routes.rb`.
- `@inertiajs/*` frontend packages merged into `package.json` (or printed as `npm install`
  guidance if no `package.json` exists yet).

Pass `--framework=vue` or `--framework=svelte` to target a different Inertia client adapter
(defaults to `react`), and `--force` to overwrite files it previously generated. Run
`bundle exec hanami generate inertia:install --help` for details.

Finally, run `npm install` (or yarn/pnpm) to install the frontend packages. Wiring up the JS
entrypoint (Vite/`hanami-assets` config) is outside this gem's scope - it only manages the
Ruby/server side of the Inertia protocol.

## Usage

Include `InertiaHanami::Action` in an action to speak the Inertia protocol from it. This skips
Hanami's automatic view rendering for Inertia XHR requests, renders the Inertia page envelope for
both XHR and full-page-load requests, and gives you `inertia_render`, `inertia_share`,
`inertia_location`, and friends:

```ruby
module MyApp
  module Actions
    module Dashboard
      class Show < MyApp::Action
        include InertiaHanami::Action

        def handle(req, res)
          inertia_render "Dashboard/Show", props: { name: "Ada" }
        end
      end
    end
  end
end
```

`inertia_render` accepts `component:` (implicit, first positional arg), `props:`, `url:` (defaults
to the current request URL), `version:` (defaults to the configured asset version), and
`encrypt_history:` / `clear_history:` (see below). It's usually cleanest to include
`InertiaHanami::Action` once in a shared base action class rather than in every action.

### Sharing props across actions

`inertia_share` (class-level) declares props merged into every `inertia_render` call from that
action class and its subclasses - handy on a base action for data every page needs:

```ruby
class ApplicationAction < MyApp::Action
  include InertiaHanami::Action

  inertia_share app_name: "My App"

  # Block form is instance_exec'd at render time, so it can call other
  # action instance methods (current_user, session, etc.).
  inertia_share do
    { current_user: current_user&.to_h }
  end
end
```

Call `inertia_share` again (with or without a block) from inside `#handle` to add props scoped to
that single request instance only, without affecting other instances of the action:

```ruby
def handle(req, res)
  inertia_share breadcrumbs: build_breadcrumbs(req)
  inertia_render "Posts/Show"
end
```

Both class- and instance-level shared props are merged in before the `props:` you pass directly to
`inertia_render`, so a per-render prop always wins over a shared one with the same key.

### Errors and flash

Two props are auto-shared on every `inertia_render` call (only when the app has sessions enabled):

- `flash` - the current request's flash messages, when there are any.
- `errors` - validation errors stashed via `share_inertia_errors`, delivered once and then cleared
  from the session. Mirrors inertia-rails' `redirect_to ..., inertia: { errors: ... }`:

```ruby
def handle(req, res)
  form = PostForm.new(req.params)
  return inertia_render("Posts/New") if req.get?

  if form.invalid?
    share_inertia_errors(form.errors)
    res.redirect_to(routes.path(:new_post))
    return
  end

  # ...
end
```

Set `config.always_include_errors_hash = true` (see Configuration below) to always send an
`errors: {}` prop even when nothing was stashed, instead of omitting the key entirely.

### External redirects

Inertia's XHR-driven visits can't follow a redirect to a different origin. `inertia_location(url)`
handles this: on an Inertia request it sets `X-Inertia-Location` and responds `409` so the client
performs a full browser visit; on a non-Inertia request it's a normal redirect:

```ruby
def handle(req, res)
  inertia_location("https://example.com/checkout")
end
```

### Encrypted history

When enabled, the client encrypts its Inertia history state (useful for pages with sensitive data
you don't want recoverable via the browser's back button after logout). Set the default globally
via `config.encrypt_history` (see Configuration below), override it per action class with
`encrypt_history`, or per instance/request by calling the instance method inside `#handle`:

```ruby
class Settings::Show < MyApp::Action
  include InertiaHanami::Action

  encrypt_history # defaults to true; pass value: false to opt an action out
end
```

`clear_history` marks the *next* `inertia_render` call's response as `clearHistory: true`, telling
the client to wipe any encrypted history it has stored - call it before redirecting on logout:

```ruby
def handle(req, res)
  clear_history
  res.redirect_to(routes.path(:root))
end
```

### Configuration

Configured in `config/providers/inertia.rb` (scaffolded by the install generator):

```ruby
Hanami.app.register_provider(:inertia, namespace: true) do
  start do
    configure do |config|
      config.version = nil                              # default: digest of assets.json, if present
      config.root_view = "app"                           # default
      config.root_dom_id = "app"                         # default
      config.component_path_resolver = ->(component) { component } # default: identity
      config.always_include_errors_hash = false           # default
      config.encrypt_history = false                      # default
    end
  end
end
```

- `version` - the asset version string sent to the client and checked against
  `X-Inertia-Version` by `InertiaHanami::Middleware::Version` (a mismatch triggers a full reload
  so the client picks up new assets). Defaults to a SHA256 digest of hanami-assets'
  `assets.json` manifest when present, or `nil` otherwise.
- `root_view` - the view rendered for the initial full-page (non-Inertia) load.
- `root_dom_id` - the `id` of the div `inertia_root` renders, matching the client's mount point.
- `component_path_resolver` - a callable mapping the string passed to `inertia_render` to the
  actual client-side component path, if you want the two to differ.
- `always_include_errors_hash` - see Errors and flash above.
- `encrypt_history` - see Encrypted history above.
- `ssr.*` - see Server-side rendering (SSR) below.

### Props

Wrap a value in one of `InertiaHanami::Props`' wrapper classes to control how it's resolved and
included in the response. There's no factory-method DSL - construct them directly with `.new`:

```ruby
def handle(req, res)
  inertia_render "Users/Index", props: {
    # Only sent when explicitly requested via a partial reload (`only:`).
    stats: InertiaHanami::Props::Optional.new(block: -> { expensive_stats }),

    # Always sent, even during a partial reload that would otherwise exclude it.
    permissions: InertiaHanami::Props::Always.new(block: -> { current_user.permissions }),

    # Loaded in a follow-up request after the initial page load. Props sharing the same
    # `group:` (default `"default"`) are batched into one follow-up request.
    notifications: InertiaHanami::Props::Defer.new(group: "sidebar", block: -> { fetch_notifications }),

    # Resolved once and cached client-side; the client tells the server what it already has
    # via X-Inertia-Except-Once-Props, so the block isn't re-run on subsequent visits.
    locale_options: InertiaHanami::Props::Once.new(block: -> { available_locales }),

    # Merged into the existing client-side prop instead of replacing it.
    comments: InertiaHanami::Props::Merge.new(match_on: "id", block: -> { Comment.recent })
  }
end
```

- `Once#key:` - the cache key reported in `onceProps`; defaults to the prop's dot-path.
- `Once#fresh:` - when `true`, always re-resolves and re-sends the prop even if the client
  reports it as cached (bypasses `X-Inertia-Except-Once-Props`). Defaults to `false`.
- `Once#expires_in:` - a number of seconds after which the client should treat its cached copy
  as stale and ask for it again. Defaults to `nil` (never expires).
- `Merge#deep_merge:` - deep-merges Hashes instead of the default shallow/array-append merge.
- `Merge#match_on:` - a dot-path (relative to the prop) identifying items by key during a merge,
  so updates replace existing items instead of duplicating them (e.g. `"id"` for an array of
  records).

#### Infinite scroll

`InertiaHanami::Props::Scroll` drives the client's infinite-scroll feature: it merges into the
existing client-side prop (appending on `fetchNext`, prepending on `fetchPrevious`, per the
`X-Inertia-Infinite-Scroll-Merge-Intent` request header the client sends) and reports pagination
metadata via the response's `scrollProps` map, which the client reads to know whether there's a
next/previous page to fetch:

```ruby
def handle(req, res)
  page = req.params[:page].to_i.nonzero? || 1
  paginated = Post.page(page)

  inertia_render "Posts/Index", props: {
    posts: InertiaHanami::Props::Scroll.new(
      match_on: "id",
      current_page: paginated.current_page,
      previous_page: paginated.prev_page,
      next_page: paginated.next_page,
      block: -> { paginated.to_a }
    )
  }
end
```

- `page_name:` - the request param name the client increments as it scrolls (defaults to
  `"page"`; must match the param your action reads, `req.params[:page]` above).
- `previous_page:` / `next_page:` - the page identifier to request next in each direction, or
  `nil` when there's nothing more to load in that direction (the client stops fetching once
  `nil`).
- `current_page:` - the page identifier just loaded, echoed back to the client.
- `match_on:` - same de-duping semantics as `Merge#match_on:` above; near-essential for infinite
  scroll so re-fetched items replace rather than duplicate existing ones.

### CSRF protection

CSRF is handled automatically once `config.actions.sessions` is configured and
`InertiaHanami::Middleware::Csrf` is registered (both done for you by
`hanami generate inertia:install`) - no app code required.

Hanami's own `Hanami::Action::CSRFProtection` (auto-included on every action when sessions are
enabled) stores its challenge token in the session and checks for it via an `X-CSRF-Token`
header. Inertia's client, on the other hand, automatically reads an `XSRF-TOKEN` cookie and
echoes it back as `X-XSRF-TOKEN` on every request - it never sends `X-CSRF-Token`. Neither side
needs to change to talk to the other; `InertiaHanami::Middleware::Csrf` just translates between
them: it mirrors the session's CSRF token into a readable `XSRF-TOKEN` cookie on responses, and
copies an incoming `X-XSRF-TOKEN` header into `X-CSRF-Token` before the request reaches the
action, so Hanami's own verification passes without either the client or the action needing to
know about the other's naming convention.

### Server-side rendering (SSR)

By default, the initial page load is client-side rendered: the layout emits an empty
`<div id="app" data-page="...">` and the JS app hydrates it in the browser. Enabling SSR renders
that markup up front, on the server, by delegating to a separately-run Node process.

Configure it in `config/providers/inertia.rb`:

```ruby
Hanami.app.register_provider(:inertia, namespace: true) do
  # ...
  configure do |config|
    config.ssr.enabled = true
    config.ssr.url = "http://localhost:13714"   # default
    config.ssr.raise_on_error = false            # default: fall back to CSR on SSR failure
  end
end
```

- `ssr.enabled` - turn SSR on for full-page (non-`X-Inertia`) requests. Disabled by default.
- `ssr.url` - base URL of the Node SSR server. `InertiaHanami::SSRRenderer` POSTs the Inertia
  page JSON to `#{ssr.url}/render`.
- `ssr.raise_on_error` - when the SSR server is unreachable or errors, `false` (default) silently
  falls back to CSR for that request; `true` re-raises so the failure surfaces instead of being
  masked.

Responses are cached in-process by a digest of the page JSON, so re-rendering an unchanged page
within the same process skips the HTTP round-trip.

**Running the Node SSR server.** This gem does not run or supervise the Node process for you -
unlike inertia-rails' bundled Puma plugin, there is no process-management integration here. Run it
as an independent process, exposing a `POST /render` endpoint that accepts the Inertia page JSON
and returns `{"head": "...", "body": "..."}` (an array of strings for `head` is also accepted). See
[inertia-rails' SSR server setup](https://inertia-rails.dev/guide/server-side-rendering) for the
JS-side implementation - the wire protocol is the same. For example, with a `package.json` script:

```bash
node ssr/server.js   # listens on the port configured via ssr.url, e.g. 13714
```

Start it alongside your Hanami app (a `Procfile` entry, systemd unit, or `foreman start` are all
reasonable choices) before enabling `ssr.enabled` in production.

## Testing

Require the RSpec matchers in your `spec/spec_helper.rb`:

```ruby
require "inertia_hanami/testing/rspec"
```

Then, in a request spec that `include`s `Rack::Test::Methods`:

```ruby
RSpec.describe "GET /" do
  include Rack::Test::Methods

  def app = MyApp::App

  it "renders the dashboard" do
    get "/", {}, { "HTTP_X_INERTIA" => "true" }

    expect(inertia).to be_inertia_response
    expect(inertia).to render_component("Dashboard/Show")
    expect(inertia).to have_props(name: "Ada")
    expect(inertia).to have_exact_props(name: "Ada", role: "admin")
    expect(inertia).to have_no_prop(:secret)
  end
end
```

`inertia_reload_only(*props)`, `inertia_reload_except(*props)`, and
`inertia_load_deferred_props(group = nil)` re-issue a GET against the last request's path
with the appropriate `X-Inertia-Partial-*` headers, so you can assert on the result of a
partial reload:

```ruby
get "/", {}, { "HTTP_X_INERTIA" => "true" }
inertia_reload_only("name")
expect(inertia).to have_exact_props(name: "Ada")
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kamalogudah/inertia_hanami. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/kamalogudah/inertia_hanami/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the InertiaHanami project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/kamalogudah/inertia_hanami/blob/main/CODE_OF_CONDUCT.md).
