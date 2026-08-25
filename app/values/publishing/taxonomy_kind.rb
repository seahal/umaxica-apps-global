# frozen_string_literal: true

module Publishing
  # The fixed structural kinds a vocabulary can have. Vocabularies themselves
  # are runtime rows -- adding "topic" or "audience_level" needs no code -- but
  # a new structural kind changes table shapes and constraints, so the set here
  # is closed and explicit.
  #
  # Registration is an explicit frozen map: no constantize, no const_get, no
  # naming-convention discovery, and no subclass scanning.
  module TaxonomyKind
    SINGLE_HIERARCHICAL = "single_hierarchical"
    MULTIPLE_ORDERED_FLAT = "multiple_ordered_flat"

    class UnknownKindError < StandardError; end

    module_function

    # Built per call rather than memoized: the providers are stateless value
    # objects, so allocating two of them costs less than caching them safely
    # across threads and across development reloads.
    def registry
      {
        SINGLE_HIERARCHICAL => SingleHierarchical.new,
        MULTIPLE_ORDERED_FLAT => MultipleOrderedFlat.new,
      }.freeze
    end

    def fetch(key)
      registry.fetch(key.to_s) { raise(UnknownKindError, "unknown publishing taxonomy kind: #{key.inspect}") }
    end

    def keys = registry.keys

    KEYS = [SINGLE_HIERARCHICAL, MULTIPLE_ORDERED_FLAT].freeze
  end
end
