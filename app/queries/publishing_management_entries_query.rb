# typed: false
# frozen_string_literal: true

class PublishingManagementEntriesQuery
  def self.call(...)
    new(...).call
  end

  def initialize(entry_class:)
    @entry_class = entry_class
  end

  def call
    scoped.includes(:current_revision, :canonical_slug, :active_publication)
      .order(updated_at: :desc)
  end

  def find!(public_id:)
    scoped.includes(
      :canonical_slug,
      :active_publication,
      current_revision: %i(media_usages single_taxonomy_assignments multiple_taxonomy_assignments),
    ).find_by!(public_id: public_id)
  end

  private

  attr_reader :entry_class

  def scoped
    entry_class.all
  end
end
