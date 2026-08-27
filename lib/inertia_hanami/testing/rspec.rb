# frozen_string_literal: true

require "json"
require "cgi"

module InertiaHanami
  # RSpec support for testing Inertia responses: matchers (`have_props`,
  # `have_exact_props`, `have_no_prop`, `be_inertia_response`,
  # `render_component`) plus partial-reload request helpers
  # (`inertia_reload_only`, `inertia_reload_except`,
  # `inertia_load_deferred_props`). Requires the host example group to
  # `include Rack::Test::Methods` (or otherwise provide `last_response`,
  # `last_request`, and `get`) - not auto-included, since a plain Rack env
  # is all this needs.
  #
  # Ported from inertia-rails' `inertia_rails/{testing,rspec}.rb`, adapted
  # to this gem's lack of a swappable renderer factory (there is nothing to
  # monkeypatch to intercept the page hash, so `TestResponse` parses
  # `last_response` directly instead) and its lack of ActiveSupport.
  module Testing
    def self.deep_symbolize_keys(value)
      case value
      when Hash
        value.each_with_object({}) { |(k, v), acc| acc[k.to_sym] = deep_symbolize_keys(v) }
      when Array
        value.map { |v| deep_symbolize_keys(v) }
      else
        value
      end
    end

    # Wraps a Rack::Test response, extracting the Inertia page envelope
    # either from the JSON body (X-Inertia XHR response) or from the
    # `data-page` attribute rendered into the initial HTML load.
    class TestResponse
      DATA_PAGE_REGEXP = /data-page="([^"]*)"/

      def initialize(response)
        @response = response
        @page = extract_page
      end

      def inertia_response?
        !@page.nil?
      end

      def component
        @page && @page["component"]
      end

      def url
        @page && @page["url"]
      end

      def version
        @page && @page["version"]
      end

      def encrypt_history
        @page && @page["encryptHistory"]
      end

      def clear_history
        @page && @page["clearHistory"]
      end

      def props
        @props ||= Testing.deep_symbolize_keys((@page && @page["props"]) || {})
      end

      def once_props
        @once_props ||= Testing.deep_symbolize_keys((@page && @page["onceProps"]) || {})
      end

      def merge_props
        (@page && @page["mergeProps"]) || []
      end

      def deep_merge_props
        (@page && @page["deepMergeProps"]) || []
      end

      def match_props_on
        (@page && @page["matchPropsOn"]) || []
      end

      def deferred_props
        @deferred_props ||= ((@page && @page["deferredProps"]) || {}).each_with_object({}) do |(group, paths), acc|
          acc[group.to_sym] = paths
        end
      end

      private

      def extract_page
        return JSON.parse(@response.body) if @response.headers["X-Inertia"] == "true"

        match = @response.body.match(DATA_PAGE_REGEXP)
        return nil unless match

        JSON.parse(CGI.unescapeHTML(match[1]))
      rescue JSON::ParserError
        nil
      end
    end

    # Pure, framework-agnostic validators backing the RSpec matchers. Each
    # returns a `{passed:, message:, negated_message:}` hash.
    module Assertions
      module_function

      def validate_with_block(inertia, field, &block)
        actual = inertia.public_send(field)
        negated_message = "expected #{field} block to return false"

        if block.call(actual)
          { passed: true, negated_message: negated_message }
        else
          { passed: false, message: "#{field} block validation failed", negated_message: negated_message }
        end
      end

      def validate_partial_match(inertia, field, expected)
        actual = inertia.public_send(field)
        expected = Testing.deep_symbolize_keys(expected)
        negated = "expected #{field} not to include #{expected.inspect}"
        return { passed: true, negated_message: negated } if expected.all? { |key, value| actual[key] == value }

        message = "expected #{field} to include #{expected.inspect}\ngot: #{actual.inspect}"
        { passed: false, message: message, negated_message: negated }
      end

      def validate_exact_match(inertia, field, expected)
        actual = inertia.public_send(field)
        expected = Testing.deep_symbolize_keys(expected)
        negated = "expected #{field} not to equal #{expected.inspect}"
        return { passed: true, negated_message: negated } if actual == expected

        message = "expected #{field} to equal #{expected.inspect}, got #{actual.inspect}"
        { passed: false, message: message, negated_message: negated }
      end

      def validate_key_absent(inertia, field, key)
        actual = inertia.public_send(field)
        key = key.to_sym
        negated = "expected #{field} to have key #{key.inspect}"
        return { passed: true, negated_message: negated } unless actual.key?(key)

        { passed: false, message: "expected #{field} not to have key #{key.inspect}", negated_message: negated }
      end

      def validate_component(inertia, expected)
        actual = inertia.component
        negated = "expected component not to be #{expected.inspect}"
        return { passed: true, negated_message: negated } if actual == expected

        got = actual.nil? ? "nothing" : actual.inspect
        { passed: false, message: "expected component to be #{expected.inspect}, got #{got}", negated_message: negated }
      end

      def validate_inertia_response(inertia)
        negated = "expected response not to be an Inertia response"
        unless inertia.is_a?(TestResponse)
          message = "expected the `inertia` helper, got #{inertia.class}"
          return { passed: false, message: message, negated_message: negated }
        end
        return { passed: true, negated_message: negated } if inertia.inertia_response?

        { passed: false, message: "expected an Inertia response", negated_message: negated }
      end
    end

    # Builds the RSpec matchers on top of Assertions' pure validators.
    module MatcherFactory
      def self.define_inertia_matcher(name, &validation_block)
        ::RSpec::Matchers.define(name) do |*matcher_args|
          match do |actual|
            @result = instance_exec(actual, *matcher_args, &validation_block)
            @result[:passed]
          end

          failure_message { @result[:message] }
          failure_message_when_negated { @result[:negated_message] }
        end
      end

      def self.partial_match_result(inertia, field, expected, block_arg, name)
        return Assertions.validate_with_block(inertia, field, &block_arg) if block_arg
        raise ArgumentError, "#{name} requires either an expected hash or a block" if expected.nil?

        Assertions.validate_partial_match(inertia, field, expected)
      end

      def self.define_partial_matcher(name, field)
        ::RSpec::Matchers.define(name) do |expected = nil|
          match do |inertia|
            @result = MatcherFactory.partial_match_result(inertia, field, expected, block_arg, name)
            @result[:passed]
          end

          failure_message { @result[:message] }
          failure_message_when_negated { @result[:negated_message] }
        end
      end

      def self.define_exact_matcher(name, field)
        define_inertia_matcher(name) { |inertia, expected| Assertions.validate_exact_match(inertia, field, expected) }
      end

      def self.define_key_absent_matcher(name, field)
        define_inertia_matcher(name) { |inertia, key| Assertions.validate_key_absent(inertia, field, key) }
      end
    end

    # Request-spec helpers for reading the current Inertia response and
    # re-issuing partial-reload requests. Mixed into RSpec example groups
    # below; assumes the host group already provides `last_response`,
    # `last_request`, and `get` (e.g. via `include Rack::Test::Methods`).
    module RequestHelpers
      def inertia
        TestResponse.new(last_response)
      end

      def inertia_reload_only(*props)
        get last_request.fullpath, {}, partial_reload_headers.merge("HTTP_X_INERTIA_PARTIAL_DATA" => props.join(","))
      end

      def inertia_reload_except(*props)
        get last_request.fullpath, {}, partial_reload_headers.merge("HTTP_X_INERTIA_PARTIAL_EXCEPT" => props.join(","))
      end

      def inertia_load_deferred_props(group = nil)
        deferred = inertia.deferred_props
        keys = group ? Array(deferred[group.to_sym]) : deferred.values.flatten
        return if keys.empty?

        inertia_reload_only(*keys)
      end

      private

      def partial_reload_headers
        headers = { "HTTP_X_INERTIA" => "true", "HTTP_X_INERTIA_PARTIAL_COMPONENT" => inertia.component }
        headers["HTTP_X_INERTIA_VERSION"] = inertia.version if inertia.version
        headers
      end
    end
  end
end

RSpec.configure do |config|
  config.include InertiaHanami::Testing::RequestHelpers
end

InertiaHanami::Testing::MatcherFactory.define_partial_matcher(:have_props, :props)
InertiaHanami::Testing::MatcherFactory.define_exact_matcher(:have_exact_props, :props)
InertiaHanami::Testing::MatcherFactory.define_key_absent_matcher(:have_no_prop, :props)

InertiaHanami::Testing::MatcherFactory.define_inertia_matcher(:be_inertia_response) do |inertia|
  InertiaHanami::Testing::Assertions.validate_inertia_response(inertia)
end

InertiaHanami::Testing::MatcherFactory.define_inertia_matcher(:render_component) do |inertia, expected|
  InertiaHanami::Testing::Assertions.validate_component(inertia, expected)
end
