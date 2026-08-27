# frozen_string_literal: true

require "net/http"
require "uri"
require "digest"
require "json"

module InertiaHanami
  # POSTs the Inertia page envelope to a separately-run Node SSR server and
  # splices the returned markup into the layout in place of the CSR div
  # (see Helper#inertia_ssr_head / #inertia_ssr_body).
  #
  # Responses are memoized in-process, keyed by a SHA256 digest of the page
  # JSON, so repeat renders of an unchanged page skip the HTTP round-trip.
  # The cache is a plain in-memory Hash - it is per-process and unbounded,
  # not shared across app instances.
  #
  # On any failure (connection error, non-2xx response, malformed JSON),
  # #call returns nil so the caller can fall back to CSR, unless
  # `ssr.raise_on_error` is enabled, in which case the error propagates.
  class SSRRenderer
    Result = Struct.new(:head, :body)

    def self.instance
      @instance ||= new
    end

    def initialize(config: Hanami.app["inertia.config"])
      @config = config
      @cache = {}
      @mutex = Mutex.new
    end

    def call(page)
      json = page.to_json
      digest = Digest::SHA256.hexdigest(json)

      @mutex.synchronize { @cache[digest] } || fetch(json, digest)
    end

    private

    def fetch(json, digest)
      result = Result.new(*parse(post(json)).values_at("head", "body"))
      result.head = Array(result.head).join("\n") if result.head.is_a?(Array)
      @mutex.synchronize { @cache[digest] = result }
      result
    rescue StandardError => e
      raise e if @config.ssr.raise_on_error

      nil
    end

    def post(json)
      uri = URI.join(@config.ssr.url, "/render")
      response = Net::HTTP.post(uri, json, "Content-Type" => "application/json")
      raise "SSR server responded with #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end

    def parse(body)
      JSON.parse(body)
    end
  end
end
