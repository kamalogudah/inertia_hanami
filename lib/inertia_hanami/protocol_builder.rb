# frozen_string_literal: true

module InertiaHanami
  # Decides which props actually go into an Inertia response: applies the
  # partial-reload algorithm (only/except/reset dot-paths), the AlwaysProp
  # bypass, the Optional/Defer exclusion-by-default rule, and Once-prop
  # caching, then collects the deferredProps/mergeProps/prependProps/
  # deepMergeProps/matchPropsOn/onceProps/scrollProps metadata the client
  # needs.
  #
  # Operates on the already-evaluated output of PropEvaluator (a Hash whose
  # leaves are plain values or Props::Base instances with resolved,
  # argument-free blocks) plus plain Ruby values for the partial-reload
  # headers, so it stays framework/header-parsing free.
  #
  # Ported from inertia-rails' props_resolver.rb algorithm (inertia-rage's
  # protocol_builder.rb, the originally intended porting source, isn't
  # available as a dependency here), adapted to this repo's Data-based Props
  # wrappers.
  # rubocop:disable Metrics/ClassLength -- one small dedicated transform_* method per prop type
  class ProtocolBuilder
    # Sentinel returned by #transform to signal a filtered-out prop, so a
    # Hash node can tell "excluded" apart from a legitimately nil value.
    DROP = Object.new.freeze
    private_constant :DROP

    # `partial` bundles the X-Inertia-Partial-* / X-Inertia-Reset /
    # X-Inertia-Except-Once-Props / X-Inertia-Infinite-Scroll-Merge-Intent
    # header values (already split into arrays by the caller, except
    # :scroll_intent which is a single raw value): :component, :only,
    # :except, :reset, :except_once, :scroll_intent.
    def initialize(component:, props:, partial: {})
      @component = component
      @props = props
      assign_partial(partial)
      @deferred_props = Hash.new { |hash, key| hash[key] = [] }
      @merge_props = []
      @prepend_props = []
      @deep_merge_props = []
      @match_props_on = []
      @once_props = {}
      @scroll_props = {}
    end

    def call
      {
        props: transform(@props, []),
        deferredProps: presence(@deferred_props.transform_values(&:sort)),
        mergeProps: presence(@merge_props),
        prependProps: presence(@prepend_props),
        deepMergeProps: presence(@deep_merge_props),
        matchPropsOn: presence(@match_props_on),
        onceProps: presence(@once_props),
        scrollProps: presence(@scroll_props)
      }.compact
    end

    private

    def assign_partial(partial)
      @partial = !partial[:component].nil? && partial[:component] == @component
      @only = partial[:only] || []
      @except = partial[:except] || []
      @reset = partial[:reset] || []
      @except_once = partial[:except_once] || []
      @scroll_intent = partial[:scroll_intent] || "append"
    end

    # Maps a node's class to the transform method that handles it, so
    # #transform stays a flat dispatch instead of an if/elsif chain.
    TRANSFORMERS = {
      Props::Once => :transform_once,
      Props::Scroll => :transform_scroll,
      Props::Merge => :transform_merge,
      Props::Defer => :transform_defer,
      Props::Optional => :transform_optional
    }.freeze
    private_constant :TRANSFORMERS

    def transform(node, path)
      return transform_hash(node, path) if node.is_a?(Hash)
      return node.resolve if node.is_a?(Props::Always)

      transformer = TRANSFORMERS[node.class]
      return send(transformer, node, path) if transformer

      transform_plain(node, path)
    end

    def transform_hash(node, path)
      node.each_with_object({}) do |(key, value), acc|
        resolved = transform(value, path + [key.to_s])
        acc[key] = resolved unless resolved == DROP
      end
    end

    def transform_plain(node, path)
      keep_prop?(path) ? node : DROP
    end

    def transform_optional(node, path)
      keep_default_excluded?(path) ? node.resolve : DROP
    end

    def transform_defer(node, path)
      return node.resolve if keep_default_excluded?(path)

      @deferred_props[node.group] << path.join(".")
      DROP
    end

    def transform_merge(node, path)
      return DROP unless keep_prop?(path)

      dot_path = path.join(".")
      (node.deep_merge ? @deep_merge_props : @merge_props) << dot_path
      @match_props_on << "#{dot_path}.#{node.match_on}" if node.match_on
      node.resolve
    end

    def transform_once(node, path)
      dot_path = path.join(".")
      key = node.key || dot_path
      return DROP if once_cache_hit?(node, dot_path, key)
      return DROP unless keep_prop?(path)

      @once_props[key] = { "prop" => dot_path, "expiresAt" => node.expires_at }.compact
      node.resolve
    end

    def once_cache_hit?(node, dot_path, key)
      reset_requested = @reset.include?(dot_path) || @reset.include?(key)
      already_cached = !node.fresh && (@except_once.include?(key) || @except_once.include?(dot_path))
      !reset_requested && already_cached
    end

    def transform_scroll(node, path)
      return DROP unless keep_prop?(path)

      dot_path = path.join(".")
      (@scroll_intent == "prepend" ? @prepend_props : @merge_props) << dot_path
      @match_props_on << "#{dot_path}.#{node.match_on}" if node.match_on
      @scroll_props[dot_path] = scroll_metadata(node, dot_path)
      node.resolve
    end

    def scroll_metadata(node, dot_path)
      {
        "pageName" => node.page_name,
        "previousPage" => node.previous_page,
        "nextPage" => node.next_page,
        "currentPage" => node.current_page,
        "reset" => @reset.include?(dot_path)
      }
    end

    # Optional/Defer: only included when a partial reload explicitly names
    # them via `only`, subject to `except` on top.
    def keep_default_excluded?(path)
      return false unless @partial
      return false if @only.empty? || !path_matches?(path, @only)

      !excluded_by_except?(path)
    end

    # Plain values/Merge/Once: excluded by `except`, or by a non-empty
    # `only` during a partial reload that doesn't match this path.
    def keep_prop?(path)
      return false if excluded_by_except?(path)
      return true unless @partial && !@only.empty?

      path_matches?(path, @only)
    end

    def excluded_by_except?(path)
      @partial && !@except.empty? && path_matches?(path, @except)
    end

    # A dot-path matches a set entry if it's equal to it, a descendant of it
    # (the entry names an ancestor group), or an ancestor of it (walking
    # through an intermediate node on the way to a deeper match).
    def path_matches?(path, set)
      dot_path = path.join(".")
      set.any? do |entry|
        entry == dot_path || dot_path.start_with?("#{entry}.") || entry.start_with?("#{dot_path}.")
      end
    end

    def presence(collection)
      collection.nil? || collection.empty? ? nil : collection
    end
  end
  # rubocop:enable Metrics/ClassLength
end
