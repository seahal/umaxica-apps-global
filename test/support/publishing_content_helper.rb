# frozen_string_literal: true

module PublishingContentHelper
  def assert_database_rejects(error_class = ActiveRecord::StatementInvalid, &)
    assert_raises(error_class) do
      PublishingRecord.transaction(requires_new: true, &)
    end
  end

  def publishing_entry_class(audience:, surface:)
    klass = Publishing::ContentFamilies.entry_class(surface:, audience:)
    raise ArgumentError, "unknown publishing cell #{surface}/#{audience}" unless klass

    klass
  end

  def publishing_vocabulary(audience:, surface:, key:, kind:)
    vocab_class = publishing_entry_class(audience:, surface:).module_parent::Vocabulary
    vocab_class.find_or_create_by!(key:) do |vocabulary|
      vocabulary.kind = kind
      vocabulary.internal_name = key.capitalize
    end
  end

  def publishing_category_vocabulary(audience:, surface:)
    publishing_vocabulary(audience:, surface:, key: "category", kind: Publishing::TaxonomyKind::SINGLE_HIERARCHICAL)
  end

  def publishing_tag_vocabulary(audience:, surface:)
    publishing_vocabulary(audience:, surface:, key: "tag", kind: Publishing::TaxonomyKind::MULTIPLE_ORDERED_FLAT)
  end

  def publishing_term(vocabulary:, locale:, slug:, name: nil, parent: nil)
    term_class = vocabulary.class.module_parent::TaxonomyTerm
    term_class.create!(
      vocabulary:, vocabulary_kind: vocabulary.kind, locale:, slug:, name: name || slug.titleize,
      parent:, depth: parent ? parent.depth + 1 : 0,
      position: term_class.next_sibling_position(
        vocabulary_id: vocabulary.id, locale:, parent_id: parent&.id,
      ),
    )
  end

  def publishing_draft(audience:, surface:, slug:, title:, locale: "ja", sequence: 1)
    entry_class = publishing_entry_class(audience:, surface:)
    entry = entry_class.create!(locale:)
    entry.slugs.create!(locale:, slug:, state: "canonical", canonicalized_at: Time.current)
    revision = publishing_revision(entry:, title:, locale:, sequence:)
    entry.update!(current_revision: revision)
    entry
  end

  def publishing_revision(entry:, title:, locale: nil, sequence: 1)
    locale ||= entry.locale
    entry.revisions.create!(
      locale:, title:, summary: "#{title} summary", body: { "text" => "#{title} body" },
      schema_version: 1, content_digest: Digest::SHA256.hexdigest("#{title}-#{sequence}"), sequence:,
    )
  end

  def publishing_publish(entry:, published_at: 1.hour.ago, effective_until: nil)
    version = Publishing::PromoteRevisionOperation.call(revision: entry.current_revision)
    entry.publications.create!(entry_version: version, effective_from: published_at, effective_until:)
    entry
  end

  def publishing_media_file(storage_key: nil)
    Publishing::MediaFile.create!(
      storage_key: storage_key || "test/#{SecureRandom.hex(12)}",
      content_type: "image/png",
      byte_size: 32,
      digest_algorithm: "sha256",
      digest: Digest::SHA256.hexdigest(SecureRandom.hex(8)),
      metadata: {},
    )
  end

  def publishing_revision_media_usage(
    revision:, media_file:, role: "body", position: 0, field_path: "body.blocks.0", block_path: "blocks.0",
    caption: nil, alt_text: nil, presentation_metadata: nil
  )
    revision.media_usages.create!(
      media_file:,
      role:,
      field_path:,
      block_path:,
      position:,
      caption:,
      alt_text:,
      presentation_metadata:,
    )
  end

  def create_single_assignment(entry_revision:, vocabulary:, taxonomy_term:, locale:, vocabulary_kind: nil)
    entry_revision.single_taxonomy_assignments.create!(
      vocabulary:, vocabulary_kind: vocabulary_kind || vocabulary.kind, taxonomy_term:, locale:,
    )
  end

  def create_multiple_assignment(entry_revision:, vocabulary:, taxonomy_term:, locale:, position:, vocabulary_kind: nil)
    entry_revision.multiple_taxonomy_assignments.create!(
      vocabulary:, vocabulary_kind: vocabulary_kind || vocabulary.kind, taxonomy_term:, locale:, position:,
    )
  end

  def publishing_query(audience:, surface:, locale: "ja", **filters)
    PublishingPublishedEntriesQuery.new(
      entry_class: publishing_entry_class(audience:, surface:),
      locale:,
      **filters,
    )
  end

  def publishing_published_entry(audience:, surface:, slug:, title:, locale: "ja", published_at: 1.hour.ago)
    entry = publishing_draft(audience:, surface:, slug:, title:, locale:)
    publishing_publish(entry:, published_at:)
  end
end
