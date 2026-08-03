# frozen_string_literal: true

module Publishing
  # A term is locale-specific: the Japanese and English terms for the same idea
  # are independent rows, which lets every assignment prove locale coherence
  # with a composite foreign key.
  #
  # parent_id and depth are structural columns owned by
  # Publishing::MoveTaxonomySubtree. Ordinary code must not assign
  # them directly; PostgreSQL rejects an inconsistent depth or a cycle.
  class TaxonomyTerm < PublishingRecord
    self.table_name = "publishing_taxonomy_terms"

    include PublicId

    MAX_DEPTH = 8

    belongs_to :vocabulary, class_name: "Publishing::Vocabulary", inverse_of: :terms
    belongs_to :parent, class_name: "Publishing::TaxonomyTerm", optional: true, inverse_of: :children
    has_many :children, class_name: "Publishing::TaxonomyTerm", foreign_key: :parent_id, inverse_of: :parent,
                        dependent: :restrict_with_exception

    validates :locale, presence: true
    validates :slug, format: { with: /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/ }
    validates :name, presence: true
    # depth and position are deliberately left to PostgreSQL: they are
    # structural columns owned by MoveTaxonomySubtree, and a model validation
    # here would only mask the constraint that actually governs them.

    scope :available, -> { where(archived_at: nil) }
    scope :roots, -> { where(parent_id: nil) }
    scope :ordered, -> { order(:position, :id) }

    def archived? = archived_at.present?

    def root? = parent_id.nil?

    # A term is unpublishable when it is archived or when any of its ancestors
    # is: a category whose breadcrumb passes through a retired parent cannot be
    # rendered coherently.
    def archived_in_path
      path.select(&:archived?)
    end

    # Siblings occupy distinct positions, enforced by
    # uidx_publishing_terms_sibling_position.
    def self.next_sibling_position(vocabulary_id:, locale:, parent_id:)
      (where(vocabulary_id:, locale:, parent_id:).maximum(:position) || -1) + 1
    end

    # Root-to-parent chain, outermost first.
    def ancestors
      chain = []
      node = parent
      while node
        chain.unshift(node)
        node = node.parent
      end
      chain
    end

    def path = ancestors + [self]

    def descendants
      self.class.where(<<~SQL.squish, id:)
        id IN (
          WITH RECURSIVE subtree(id) AS (
            SELECT id FROM publishing_taxonomy_terms WHERE parent_id = :id
            UNION ALL
            SELECT t.id FROM publishing_taxonomy_terms t JOIN subtree s ON t.parent_id = s.id
          )
          SELECT id FROM subtree
        )
      SQL
    end

    # Frozen into version snapshots at promotion so a later rename or move
    # cannot rewrite what an already-published version displayed.
    def breadcrumb
      path.map { |term| { "public_id" => term.public_id, "slug" => term.slug, "name" => term.name } }
    end
  end
end
