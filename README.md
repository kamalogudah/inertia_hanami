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
- `config.middleware.use InertiaHanami::Middleware::Version` / `::Redirects` in `config/app.rb`.
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

TODO: Write usage instructions here

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

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/inertia_hanami. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/inertia_hanami/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the InertiaHanami project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/inertia_hanami/blob/master/CODE_OF_CONDUCT.md).
