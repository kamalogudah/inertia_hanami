# frozen_string_literal: true

require "json"

module InertiaHanami
  # Builds the Inertia page envelope and decides whether to answer an
  # Inertia XHR request directly (JSON body) or to hand the page off to
  # Hanami's normal rendering pipeline for the initial full-page load
  # (HTML, via the layout's `inertia_root(page:)` helper).
  #
  # Expects `props` to already be evaluated (see PropEvaluator) - this class
  # only applies the partial-reload/prop-filtering algorithm (via
  # ProtocolBuilder) and shapes the resulting envelope.
  class Renderer
    def initialize(request:, response:, component:, props: {}, url: nil, version: nil,
                    encrypt_history: false, clear_history: false)
      @request = request
      @response = response
      @component = component
      @props = props
      @url = url || request.fullpath
      @version = version
      @encrypt_history = encrypt_history
      @clear_history = clear_history
      @request_context = RequestContext.new(request.env)
    end

    def render
      request_context.inertia? ? render_inertia_response : render_initial_load
    end

    private

    attr_reader :request_context

    def render_inertia_response
      @response.headers["X-Inertia"] = "true"
      @response.format = :json
      @response.body = page.to_json
    end

    def render_initial_load
      if ssr_enabled?
        result = SSRRenderer.instance.call(page)
        if result
          @response[:ssr_head] = result.head
          @response[:ssr_body] = result.body
          return
        end
      end

      @response[:page] = page
    end

    def ssr_enabled?
      Hanami.app["inertia.config"].ssr.enabled
    end

    def page
      @page ||= build_page
    end

    def build_page
      resolved = ProtocolBuilder.new(
        component: @component,
        props: @props,
        partial: request_context.partial_params
      ).call

      {
        "component" => @component,
        "props" => resolved[:props],
        "url" => @url,
        "version" => @version,
        "encryptHistory" => @encrypt_history,
        "clearHistory" => @clear_history
      }.merge(metadata(resolved))
    end

    def metadata(resolved)
      {
        "deferredProps" => resolved[:deferredProps],
        "mergeProps" => resolved[:mergeProps],
        "prependProps" => resolved[:prependProps],
        "deepMergeProps" => resolved[:deepMergeProps],
        "matchPropsOn" => resolved[:matchPropsOn],
        "onceProps" => resolved[:onceProps],
        "scrollProps" => resolved[:scrollProps]
      }.compact
    end
  end
end
