# typed: false
# frozen_string_literal: true

require "json"

# Compares the legacy lean-table read path against the new publishing DB read
# path for a single audience/surface, without switching PUBLISHING_READ_SURFACES.
# Used to verify parity before Phase 6 cutover. Read-only; writes nothing.
class PublishingShadowReadComparison < ApplicationService
  Result =
    Data.define(:summary, :details) do
      def to_h = { summary: summary, details: details }

      def to_json(*) = JSON.pretty_generate(to_h)
    end

  LEAN_MODELS = {
    %w(docs app) => DocsAppContentEntry,
    %w(docs com) => DocsComContentEntry,
    %w(docs org) => DocsOrgContentEntry,
    %w(news app) => NewsAppContentEntry,
    %w(news com) => NewsComContentEntry,
    %w(news org) => NewsOrgContentEntry,
    %w(help app) => HelpAppContentEntry,
    %w(help com) => HelpComContentEntry,
    %w(help org) => HelpOrgContentEntry,
  }.freeze
  COMPARED_FIELDS = %w(slug locale title summary body published_at).freeze

  def initialize(audience:, surface:, locale: "ja")
    super()
    @audience = audience.to_s
    @surface = surface.to_s
    @locale = locale.to_s
  end

  def call
    legacy_entries = legacy_published_entries
    edition = PublishingEditionResolver.call(audience:, surface:, locale:)
    publishing_entries = edition ? PublishingPublishedEntriesQuery.call(edition:).to_a : []

    details = {
      legacy_count: legacy_entries.size,
      publishing_count: publishing_entries.size,
      count_matches: legacy_entries.size == publishing_entries.size,
      slug_diffs: compare_slugs(legacy_entries, publishing_entries, edition),
      field_diffs: compare_fields(legacy_entries, edition),
    }
    Result.new(summary: build_summary(details), details: details)
  end

  private

  attr_reader :audience, :surface, :locale

  def legacy_model
    LEAN_MODELS.fetch([surface, audience]) { raise ArgumentError, "unknown surface/audience: #{surface}/#{audience}" }
  end

  def legacy_published_entries
    legacy_model.published.for_locale(locale).recent_first.to_a
  end

  def compare_slugs(legacy_entries, publishing_entries, edition)
    legacy_slugs = legacy_entries.map(&:slug).to_set
    publishing_slugs =
      if edition
        edition.entry_slugs.canonical.where(entry_id: publishing_entries.map(&:id)).pluck(:slug).to_set
      else
        Set.new
      end

    { only_in_legacy: (legacy_slugs - publishing_slugs).to_a, only_in_publishing: (publishing_slugs - legacy_slugs).to_a }
  end

  def compare_fields(legacy_entries, edition)
    return [] unless edition

    legacy_entries.filter_map { |legacy_entry|
      publishing_entry = PublishingPublishedEntriesQuery.new(edition:).find_by(slug: legacy_entry.slug)
      next { slug: legacy_entry.slug, status: "missing_in_publishing" } unless publishing_entry

      publishing_json = PublishingEntrySerializer.call(entry: publishing_entry, namespace: audience, surface:)
      mismatches = COMPARED_FIELDS.filter_map { |field| field_mismatch(legacy_entry, publishing_json, field) }
      next nil if mismatches.empty?

      { slug: legacy_entry.slug, mismatches: mismatches }
    }
  end

  def field_mismatch(legacy_entry, publishing_json, field)
    legacy_value = (field == "published_at") ? legacy_entry.published_at&.iso8601 : legacy_entry.public_send(field)
    publishing_value = publishing_json&.fetch(field.to_sym, nil)
    return nil if legacy_value == publishing_value

    { field: field, legacy: legacy_value, publishing: publishing_value }
  end

  def build_summary(details)
    {
      audience: audience,
      surface: surface,
      locale: locale,
      compared_at: Time.current.iso8601,
      counts_match: details[:count_matches],
      slug_only_in_legacy: details[:slug_diffs][:only_in_legacy].size,
      slug_only_in_publishing: details[:slug_diffs][:only_in_publishing].size,
      entries_with_field_diffs: details[:field_diffs].size,
      parity: details[:count_matches] && details[:slug_diffs][:only_in_legacy].empty? &&
        details[:slug_diffs][:only_in_publishing].empty? && details[:field_diffs].empty?,
    }
  end
end
