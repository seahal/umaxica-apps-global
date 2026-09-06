# frozen_string_literal: true

require_relative "../migration_support/publishing_schema"

class SeedPublishingVocabularies < ActiveRecord::Migration[8.2]
  DEFINITIONS = [
    ["category", "single_hierarchical", "Category"],
    ["tag", "multiple_ordered_flat", "Tag"],
  ].freeze

  def up
    safety_assured do
      PublishingSchema::FAMILIES.each do |surface, audience|
        table = "publishing_#{surface}_#{audience}_vocabularies"
        DEFINITIONS.each do |key, kind, internal_name|
          public_id = "substr(md5('publishing_vocabulary:#{surface}/#{audience}/#{key}'), 1, 21)"
          execute(<<~SQL.squish)
            INSERT INTO #{table} (public_id, key, kind, internal_name, created_at, updated_at)
            VALUES (#{public_id}, '#{key}', '#{kind}', '#{internal_name}', now(), now())
            ON CONFLICT (key) DO NOTHING
          SQL
        end
      end
    end
  end

  def down
    safety_assured do
      PublishingSchema::FAMILIES.each do |surface, audience|
        table = "publishing_#{surface}_#{audience}_vocabularies"
        execute("DELETE FROM #{table} WHERE key IN ('category', 'tag')")
      end
    end
  end
end
