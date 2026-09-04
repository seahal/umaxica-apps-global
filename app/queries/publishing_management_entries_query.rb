# typed: false
# frozen_string_literal: true

# Staff CMS listing: every Entry whose Edition matches the management cell
# (audience + surface) across all locales. Does not pick a single Edition.
class PublishingManagementEntriesQuery
  def self.call(...)
    new(...).call
  end

  def initialize(audience:, surface:)
    @audience = audience
    @surface = surface
  end

  def call
    scoped.includes(:current_revision, :canonical_slug, :active_publication, :edition)
      .order(updated_at: :desc)
  end

  def find!(public_id:)
    scoped.includes(
      :canonical_slug,
      :active_publication,
      :edition,
      current_revision: %i(media_usages single_taxonomy_assignments multiple_taxonomy_assignments),
    ).find_by!(public_id: public_id)
  end

  private

  attr_reader :audience, :surface

  def scoped
    Publishing::Entry.joins(:edition).where(publishing_editions: { audience:, surface: })
  end
end
