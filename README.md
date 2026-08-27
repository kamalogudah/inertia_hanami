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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/inertia_hanami. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/inertia_hanami/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the InertiaHanami project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/inertia_hanami/blob/master/CODE_OF_CONDUCT.md).
