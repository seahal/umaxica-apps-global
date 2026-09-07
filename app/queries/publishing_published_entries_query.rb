# typed: false
# frozen_string_literal: true

class PublishingPublishedEntriesQuery
  def self.call(...)
    new(...).call
  end

  DEFAULT_LIMIT = 20
  MIN_LIMIT = 1
  MAX_LIMIT = 100

  Page = Data.define(:entries, :next_cursor, :has_more)

  def self.clamp_limit(value)
    value.clamp(MIN_LIMIT, MAX_LIMIT)
  end

  def initialize(entry_class:, locale:, category: nil, tag: nil)
    @entry_class = entry_class
    @locale = locale
    @category = category.presence
    @tag = tag.presence
  end

  def call
    return entry_class.none if entry_class.nil? || locale.blank?

    scope = published_scope
    scope = filter_by(scope, key: "category", slug: category) if category
    scope = filter_by(scope, key: "tag", slug: tag) if tag
    scope
      .preload(
        :canonical_slug,
        active_publication: { entry_version: %i(single_taxonomy_assignments multiple_taxonomy_assignments) },
      )
      .strict_loading
      .order(Arel.sql(order_sql))
  end

  def page(limit: DEFAULT_LIMIT, cursor: nil)
    limit = self.class.clamp_limit(limit)
    scope = call
    scope = scope.where(Arel.sql(after_cursor_sql), cursor.effective_from, cursor.entry_public_id) if cursor

    rows = scope.limit(limit + 1).to_a
    has_more = rows.length > limit
    entries = rows.first(limit)

    Page.new(
      entries:,
      next_cursor: has_more ? PublishingEntriesCursor.encode(entries.last) : nil,
      has_more:,
    )
  end

  def find_published(public_id:)
    return if entry_class.nil? || locale.blank?

    entry =
      entry_class
        .where(locale:)
        .includes(
          :canonical_slug,
          active_publication: { entry_version: %i(single_taxonomy_assignments multiple_taxonomy_assignments) },
        )
        .find_by(public_id:)
    return unless entry
    return if entry.archived?
    return unless entry.active_publication

    entry
  end

  private

  attr_reader :entry_class, :locale, :category, :tag

  def entries_table = entry_class.table_name

  def publications_table = entry_class.reflect_on_association(:publications).klass.table_name

  def versions_table = entry_class.reflect_on_association(:versions).klass.table_name

  def order_sql
    "#{quote(publications_table)}.effective_from DESC, #{quote(entries_table)}.public_id DESC"
  end

  def after_cursor_sql
    "(#{quote(publications_table)}.effective_from, #{quote(entries_table)}.public_id) < (?, ?)"
  end

  def quote(name)
    entry_class.lease_connection.quote_table_name(name)
  end

  def published_scope
    publication_class = entry_class.reflect_on_association(:publications).klass
    entry_class
      .where(locale:, archived_at: nil)
      .joins(:publications)
      .merge(publication_class.active)
  end

  def filter_by(scope, key:, slug:)
    vocabulary = filterable_vocabularies[key]
    return scope.none unless vocabulary

    kind = vocabulary.structural_kind
    version_class = entry_class.reflect_on_association(:versions).klass
    publication_class = entry_class.reflect_on_association(:publications).klass
    association = kind.ordered? ? :multiple_taxonomy_assignments : :single_taxonomy_assignments
    assignment_class = version_class.reflect_on_association(association).klass

    scope.where(
      version_class
        .where(version_class.arel_table[:id].eq(publication_class.arel_table[:entry_version_id]))
        .joins(association)
        .merge(matching_snapshots(assignment_class, key:, slug:))
        .arel.exists,
    )
  end

  def filterable_vocabularies
    @filterable_vocabularies ||=
      vocabulary_class.available.order(:key).index_by(&:key)
  end

  def vocabulary_class
    entry_class.module_parent::Vocabulary
  end

  def matching_snapshots(assignment_class, key:, slug:)
    assignment_class.where(vocabulary_key_snapshot: key, term_slug_snapshot: slug, locale_snapshot: locale)
  end
end
