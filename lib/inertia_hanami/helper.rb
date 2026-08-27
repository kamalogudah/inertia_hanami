# frozen_string_literal: true

require "cgi"
require "json"
require "hanami/view/html"

module InertiaHanami
  # View helper that renders the Inertia root element for the initial
  # full-page load: `<div id="app" data-page="...">`. Include into a
  # view/scope class, or call directly from an ERB template/layout.
  module Helper
    module_function

    def inertia_root(page:, id: nil)
      root_id = id || Hanami.app["inertia.config"].root_dom_id
      # Marked html_safe so Hanami::View's ERB engine doesn't re-escape the
      # tag itself - the JSON inside data-page is already escaped below.
      %(<div id="#{CGI.escapeHTML(root_id.to_s)}" data-page="#{CGI.escapeHTML(page.to_json)}"></div>).html_safe
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
