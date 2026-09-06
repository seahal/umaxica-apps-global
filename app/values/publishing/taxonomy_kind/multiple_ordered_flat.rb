# frozen_string_literal: true

module Publishing
  module TaxonomyKind
    # Any number of terms per vocabulary, in an author-controlled order, drawn
    # from a flat list. Tag is the initial vocabulary using this kind.
    class MultipleOrderedFlat
      def key = TaxonomyKind::MULTIPLE_ORDERED_FLAT

      def hierarchical? = false

      def ordered? = true

      # A multiple assignment always serializes to a list, empty when
      # unassigned, ordered by the position frozen at promotion.
      def serialize(assignments)
        assignments.sort_by(&:position_snapshot).map(&:as_public_json)
      end
    end
  end
end
