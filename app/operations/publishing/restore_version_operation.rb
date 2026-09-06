# typed: false
# frozen_string_literal: true

module Publishing
  class RestoreVersionOperation < ApplicationService
    def initialize(version:, operator_public_id: nil)
      super()
      @version = version
      @operator_public_id = operator_public_id
    end

    def call
      entry = version.entry

      entry.with_lock do
        revision = create_revision(entry)
        copy_taxonomy_assignments(revision)
        copy_media_usages(revision)
        entry.update!(current_revision: revision)
        revision
      end
    end

    private

    attr_reader :version, :operator_public_id

    def create_revision(entry)
      entry.revisions.create!(
        locale: version.locale,
        title: version.title,
        summary: version.summary,
        body: version.body,
        schema_version: version.schema_version,
        content_digest: version.content_digest,
        created_by_operator_public_id: operator_public_id,
        restored_from_version_id: version.id,
        sequence: next_sequence(entry),
      )
    end

    def next_sequence(entry)
      (entry.revisions.maximum(:sequence) || 0) + 1
    end

    def copy_taxonomy_assignments(revision)
      version.single_taxonomy_assignments.each do |assignment|
        revision.single_taxonomy_assignments.create!(
          vocabulary_id: assignment.vocabulary_id,
          vocabulary_kind: assignment.vocabulary_kind,
          taxonomy_term_id: assignment.taxonomy_term_id,
          locale: assignment.locale,
        )
      end

      version.multiple_taxonomy_assignments.ordered.each do |assignment|
        revision.multiple_taxonomy_assignments.create!(
          vocabulary_id: assignment.vocabulary_id,
          vocabulary_kind: assignment.vocabulary_kind,
          taxonomy_term_id: assignment.taxonomy_term_id,
          locale: assignment.locale,
          position: assignment.position,
        )
      end
    end

    def copy_media_usages(revision)
      version.media_usages.find_each do |usage|
        revision.media_usages.create!(
          media_file_id: usage.media_file_id,
          role: usage.role,
          field_path: usage.field_path,
          block_path: usage.block_path,
          position: usage.position,
          alt_text: usage.alt_text,
          caption: usage.caption,
          presentation_metadata: usage.presentation_metadata,
        )
      end
    end
  end
end
