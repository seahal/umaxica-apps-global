# frozen_string_literal: true

module Publishing
  module TaxonomyKind
    # At most one term per vocabulary per revision or version, drawn from a tree.
    # Category is the initial vocabulary using this kind.
    class SingleHierarchical
      def key = TaxonomyKind::SINGLE_HIERARCHICAL

      def hierarchical? = true

      def ordered? = false

      # A single assignment serializes to one object or to null, never to a
      # list, and carries the frozen breadcrumb its version published.
      def serialize(assignments)
        assignment = assignments.first
        return nil unless assignment

        assignment.as_public_json.merge("path" => assignment.term_path_snapshot)
      end
    end
  end
end
