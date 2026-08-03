# typed: false
# frozen_string_literal: true

module Publishing
  # Creates the initial category and tag vocabularies for every audience and
  # surface. Locale is a property of terms, not vocabularies, so one row per
  # audience/surface/key is all that is needed.
  #
  # Idempotent by design: rerunning creates nothing. A vocabulary that already
  # exists with a different kind is a conflict the operator must resolve, so
  # it fails loudly rather than rewriting live structure underneath assigned
  # content.
  class SeedVocabularies < ApplicationService
    class ConflictingVocabularyError < StandardError; end

    DEFINITIONS = [
      { key: "category", kind: TaxonomyKind::SINGLE_HIERARCHICAL, internal_name: "Category" },
      { key: "tag", kind: TaxonomyKind::MULTIPLE_ORDERED_FLAT, internal_name: "Tag" },
    ].freeze

    def call
      Edition::AUDIENCES.flat_map do |audience|
        Edition::SURFACES.flat_map do |surface|
          DEFINITIONS.map { |definition| ensure_vocabulary(audience:, surface:, **definition) }
        end
      end
    end

    private

    def ensure_vocabulary(audience:, surface:, key:, kind:, internal_name:)
      existing = Vocabulary.find_by(audience:, surface:, key:)
      return verify_kind!(existing, kind) if existing

      Vocabulary.create!(audience:, surface:, key:, kind:, internal_name:)
    end

    def verify_kind!(vocabulary, expected_kind)
      return vocabulary if vocabulary.kind == expected_kind

      raise(
        ConflictingVocabularyError,
        "vocabulary #{vocabulary.audience}/#{vocabulary.surface}/#{vocabulary.key} " \
        "exists with kind #{vocabulary.kind}, expected #{expected_kind}",
      )
    end
  end
end
