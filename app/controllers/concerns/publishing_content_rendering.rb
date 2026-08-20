# typed: false
# frozen_string_literal: true

# Renders read-only entries from the central publishing DB. Audience and
# surface are host-derived, explicit per-controller constants -- never
# resolved dynamically from a class name or param. See
# adr/publishing-db-content-authority.md.
module PublishingContentRendering
  extend ActiveSupport::Concern

  include ProblemDetailsRendering
  include ApiContentNegotiation

  # Published content is public and identical for every caller on a given host, so it is shared-
  # cacheable. The window is short because a publication is expected to become visible promptly;
  # conditional requests, not a long TTL, are what remove the repeated transfer.
  PUBLISHING_CACHE_MAX_AGE = 60

  private

  # The validator is computed over the rendered payload rather than over row timestamps. It therefore
  # cannot drift from what is actually sent -- a taxonomy rename or a vocabulary change alters the
  # payload and the validator together. This saves transfer, not query work; the rows are still read.
  def render_publishing_entries_index
    entries = publishing_entries_json
    expires_in(PUBLISHING_CACHE_MAX_AGE.seconds, public: true)
    return unless stale?(etag: entries, last_modified: publishing_entries_last_modified(entries), public: true)

    render json: { entries: entries }
  end

  def render_publishing_entry_show
    entry = publishing_entries_query.find_by(slug: params.expect(:slug))
    return render_problem(:not_found) unless entry

    payload = publishing_entry_json(entry)
    expires_in(PUBLISHING_CACHE_MAX_AGE.seconds, public: true)
    return unless stale?(etag: payload, last_modified: publishing_timestamp(payload[:published_at]), public: true)

    render json: { entry: payload }
  end

  # `published_at` is the only instant in the contract, so the newest one is the collection's
  # last-modified. Nil when nothing is published: `stale?` then relies on the ETag alone rather than
  # inventing a timestamp.
  def publishing_entries_last_modified(entries)
    entries.filter_map { |entry| publishing_timestamp(entry[:published_at]) }.max
  end

  def publishing_timestamp(value)
    Time.zone.parse(value.to_s) if value.present?
  end

  # Transitional: these endpoints live under `/api/v0` and are read by edge applications outside this
  # repository, so the previous `{"error": "not_found"}` body is repeated inside the problem document
  # until those consumers migrate. Remove together with ApiV0LegacyErrorMember; see
  # adr/api-error-format-problem-details.md.
  def problem_document(problem, detail:, errors:)
    super.merge(error: problem.slug.to_s)
  end

  def publishing_entries_json
    publishing_entries_query.call.filter_map { |entry| publishing_entry_json(entry) }
  end

  # JSON contract preserved from the legacy ReadOnlyContentRendering: the
  # "namespace" field is the content surface (docs/news/help/info) and the
  # "surface" field is the audience (app/com/org).
  def publishing_entry_json(entry)
    PublishingEntrySerializer.call(
      entry:, namespace: self.class::PUBLISHING_SURFACE, surface: self.class::PUBLISHING_AUDIENCE,
      vocabularies: publishing_vocabularies,
    )
  end

  # Loaded once per request: the taxonomy keys are a property of the surface,
  # not of an individual entry, so an index of N entries still costs one query.
  def publishing_vocabularies
    @publishing_vocabularies ||=
      Publishing::Vocabulary
        .available
        .for_scope(audience: self.class::PUBLISHING_AUDIENCE, surface: self.class::PUBLISHING_SURFACE)
        .order(:key)
        .to_a
  end

  def publishing_entries_query
    @publishing_entries_query ||=
      PublishingPublishedEntriesQuery.new(
        edition: publishing_edition, category: params[:category], tag: params[:tag],
      )
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
