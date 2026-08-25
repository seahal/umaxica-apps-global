# frozen_string_literal: true

# The category and tag vocabularies exist in every environment: they are
# structural rows the taxonomy schema is built around, not sample content. Data
# every environment needs is owned by a migration, not by `db/seeds.rb`, so that
# a database rebuilt from migrations alone is complete and the test database
# never depends on seed data (test rows come from fixtures and test helpers).
#
# `public_id` is derived from the scope rather than generated randomly so that
# every environment agrees on the identifier for the same structural row. The
# column only has to be 21 characters and unique; it carries no other meaning.
class SeedPublishingVocabularies < ActiveRecord::Migration[8.2]
  AUDIENCES = %w(app com org).freeze
  SURFACES = %w(info docs news help).freeze
  DEFINITIONS = [
    ["category", "single_hierarchical", "Category"],
    ["tag", "multiple_ordered_flat", "Tag"],
  ].freeze

  # Rerunning inserts nothing: the scope index is the conflict target, so an
  # existing vocabulary is left exactly as it is. A row whose kind has diverged
  # is an operator decision to resolve, never something this migration rewrites.
  def up
    safety_assured do
      execute(<<~SQL.squish)
        INSERT INTO publishing_vocabularies
          (public_id, audience, surface, key, kind, internal_name, created_at, updated_at)
        VALUES #{value_rows}
        ON CONFLICT (audience, surface, key) DO NOTHING
      SQL
    end
  end

  # Deleting a vocabulary that terms already reference is blocked by the
  # restrict foreign key, which is the intended failure: rolling back structure
  # that content depends on has to be an explicit operator decision.
  def down
    safety_assured do
      execute(<<~SQL.squish)
        DELETE FROM publishing_vocabularies WHERE (audience, surface, key) IN (#{scope_tuples})
      SQL
    end
  end

  private

  def value_rows
    each_scope.map { |audience, surface, key, kind, internal_name|
      public_id = "substr(md5('publishing_vocabulary:#{audience}/#{surface}/#{key}'), 1, 21)"
      "(#{public_id}, '#{audience}', '#{surface}', '#{key}', '#{kind}', '#{internal_name}', now(), now())"
    }.join(", ")
  end

  def scope_tuples
    each_scope.map { |audience, surface, key, _kind, _internal_name|
      "('#{audience}', '#{surface}', '#{key}')"
    }.join(", ")
  end

  def each_scope
    AUDIENCES.flat_map do |audience|
      SURFACES.flat_map do |surface|
        DEFINITIONS.map { |key, kind, internal_name| [audience, surface, key, kind, internal_name] }
      end
    end
  end
end
