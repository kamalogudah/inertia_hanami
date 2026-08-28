# frozen_string_literal: true

require "cgi"
require "json"
require "hanami/view/html"

module InertiaHanami
  # View helper that renders the Inertia root element for the initial
  # full-page load. Include into a view/scope class, or call directly from
  # an ERB template/layout.
  module Helper
    module_function

    # Renders a `<script data-page="app" type="application/json">` tag
    # holding the page JSON, plus the empty `<div id="app">` mount point.
    # `@inertiajs/react|vue3|svelte`'s `createInertiaApp` (since Inertia
    # v3) only reads the initial page from that script tag - it no longer
    # falls back to a `data-page` attribute on the mount div - so this is
    # the only form current clients will actually pick up.
    def inertia_root(page:, id: nil)
      root_id = CGI.escapeHTML((id || Hanami.app["inertia.config"].root_dom_id).to_s)
      # Marked html_safe so Hanami::View's ERB engine doesn't re-escape the
      # tags themselves. A `<script>` element's content is raw text per the
      # HTML parsing spec - entities inside it are never decoded - so the
      # JSON must NOT be HTML-entity-escaped (that would corrupt it before
      # JSON.parse ever sees it); the only real risk is a literal
      # `</script` sequence prematurely closing the tag, guarded separately.
      <<~HTML.html_safe
        <script data-page="#{root_id}" type="application/json">#{escape_script_content(page.to_json)}</script>
        <div id="#{root_id}"></div>
      HTML
    end

    def escape_script_content(json)
      json.gsub("</", '<\/')
    end

    # Renders the `<head>` markup returned by the SSR server. Belongs inside
    # the layout's `<head>` tag.
    def inertia_ssr_head(head)
      head.to_s.html_safe
    end

    # Renders the `<body>` markup returned by the SSR server, in place of
    # the CSR `inertia_root` div.
    def inertia_ssr_body(body)
      body.to_s.html_safe
    end
  end
end
