# typed: false
# frozen_string_literal: true

# Renders a Publishing::Entry's currently published version as public JSON,
# compatible with the legacy ReadOnlyContentEntry#as_public_json shape.
class PublishingEntrySerializer < ApplicationService
  def initialize(entry:, namespace:, surface:)
    super()
    @entry = entry
    @namespace = namespace
    @surface = surface
  end

  def call
    version = published_version
    return nil unless version

    {
      namespace: namespace.to_s,
      surface: surface.to_s,
      slug: canonical_slug,
      locale: version.locale,
      title: version.title,
      summary: version.summary,
      body: version.body["text"] || version.body,
      published_at: current_publication&.effective_from&.iso8601,
    }
  end

  private

  attr_reader :entry, :namespace, :surface

  def published_version
    current_publication&.entry_version
  end

  def current_publication
    @current_publication ||= entry.publications.merge(Publishing::Publication.active).order(effective_from: :desc).first
  end

  def canonical_slug
    entry.slugs.canonical.first&.slug
  end
end
