# frozen_string_literal: true

module Publishing
  # A controlled, assignable vocabulary scoped to one audience and surface.
  # Adding a vocabulary is a row, not a table or a class; adding a structural
  # kind is a deliberate schema and code change. See
  # adr/publishing-taxonomy-architecture.md.
  class Vocabulary < PublishingRecord
    self.table_name = "publishing_vocabularies"

    include PublicId

    KINDS = TaxonomyKind::KEYS

    has_many :terms, class_name: "Publishing::TaxonomyTerm", inverse_of: :vocabulary, dependent: :restrict_with_exception

    validates :audience, inclusion: { in: Edition::AUDIENCES }
    validates :surface, inclusion: { in: Edition::SURFACES }
    validates :kind, inclusion: { in: KINDS }
    validates :key, format: { with: /\A[a-z][a-z0-9_]*\z/ }
    validates :internal_name, presence: true

    scope :available, -> { where(archived_at: nil) }
    scope :for_scope, ->(audience:, surface:) { where(audience:, surface:) }

    def archived? = archived_at.present?

    def structural_kind = TaxonomyKind.fetch(kind)

    def root_terms
      terms.where(parent_id: nil)
    end
  end
end
