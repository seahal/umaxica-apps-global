# typed: false
# frozen_string_literal: true

# Renders read-only entries from the central publishing DB. Audience and
# surface are host-derived, explicit per-controller constants -- never
# resolved dynamically from a class name or param. See
# adr/publishing-db-content-authority.md.
module PublishingContentRendering
  extend ActiveSupport::Concern

  private

  def render_publishing_entries_index
    render json: { entries: publishing_entries_json }
  end

  def render_publishing_entry_show
    entry = publishing_entries_query.find_by(slug: params.expect(:slug))
    return render(json: { error: "not_found" }, status: :not_found) unless entry

    render json: { entry: publishing_entry_json(entry) }
  end

  def publishing_entries_json
    publishing_entries_query.call.filter_map { |entry| publishing_entry_json(entry) }
  end

  # JSON contract preserved from the legacy ReadOnlyContentRendering: the
  # "namespace" field is the content surface (docs/news/help/info) and the
  # "surface" field is the audience (app/com/org).
  def publishing_entry_json(entry)
    PublishingEntrySerializer.call(entry:, namespace: self.class::PUBLISHING_SURFACE, surface: self.class::PUBLISHING_AUDIENCE)
  end

  def publishing_entries_query
    @publishing_entries_query ||= PublishingPublishedEntriesQuery.new(edition: publishing_edition)
  end

  def publishing_edition
    @publishing_edition ||=
      PublishingEditionResolver.call(
        audience: self.class::PUBLISHING_AUDIENCE, surface: self.class::PUBLISHING_SURFACE, locale: publishing_locale,
      )
  end

  def publishing_locale
    params[:locale].presence || locale_from_request_region(params[:ri]) || I18n.locale.to_s
  end

  def locale_from_request_region(region)
    return if region.blank?

    {
      "jp" => "ja",
      "us" => "en",
    }[region.to_s.downcase]
  end
end
