# frozen_string_literal: true

module PublishingTaxonomyTermRecord
  extend ActiveSupport::Concern

  MAX_DEPTH = 8

  included do
    include PublicId

    family = name.deconstantize
    belongs_to :vocabulary, class_name: "#{family}::Vocabulary", inverse_of: :terms
    belongs_to :parent, class_name: "#{family}::TaxonomyTerm", optional: true, inverse_of: :children
    has_many :children, class_name: "#{family}::TaxonomyTerm", foreign_key: :parent_id, inverse_of: :parent,
                        dependent: :restrict_with_exception

    validates :locale, presence: true
    validates :slug, format: { with: /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/ }
    validates :name, presence: true

    scope :available, -> { where(archived_at: nil) }
    scope :roots, -> { where(parent_id: nil) }
    scope :ordered, -> { order(:position, :id) }
  end

  def archived? = archived_at.present?

  def root? = parent_id.nil?

  def archived_in_path
    path.select(&:archived?)
  end

  class_methods do
    def next_sibling_position(vocabulary_id:, locale:, parent_id:)
      (where(vocabulary_id:, locale:, parent_id:).maximum(:position) || -1) + 1
    end
  end

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
    quoted_table = self.class.lease_connection.quote_table_name(self.class.table_name)
    self.class.where(<<~SQL.squish, id:)
      id IN (
        WITH RECURSIVE subtree(id) AS (
          SELECT id FROM #{quoted_table} WHERE parent_id = :id
          UNION ALL
          SELECT t.id FROM #{quoted_table} t JOIN subtree s ON t.parent_id = s.id
        )
        SELECT id FROM subtree
      )
    SQL
  end

  def breadcrumb
    path.map { |term| { "public_id" => term.public_id, "slug" => term.slug, "name" => term.name } }
  end
end
