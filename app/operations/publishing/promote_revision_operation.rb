# typed: false
# frozen_string_literal: true

module Publishing
  class PromoteRevisionOperation < ApplicationService
    class RevisionMismatchError < StandardError; end

    class IncompleteVersionError < StandardError; end

    # The single unique index that makes promotion idempotent: at most one version per
    # revision. A collision on it means another promotion won the race and its version can be
    # handed back. A collision on any other unique index of the same table -- the per-entry
    # sequence, the public id -- is a genuine failure and must not be swallowed as a lost race,
    # so the rescue below matches this name rather than any `RecordNotUnique`.
    def self.idempotency_index_name(entry_class)
      "uidx_#{entry_class::SURFACE}_#{entry_class::AUDIENCE}_ver_on_revision"
    end

    def initialize(revision:, operator_public_id: nil)
      super()
      @revision = revision
      @operator_public_id = operator_public_id
    end

    def call
      entry = revision.entry
      raise(RevisionMismatchError, "revision #{revision.id} has no entry") unless entry

      entry.with_lock do
        existing = entry.versions.find_by(entry_revision_id: revision.id)
        next verify_complete!(existing) if existing

        lock_taxonomy!
        reject_archived_assignments!
        create_version(entry)
      end
    end

    private

    attr_reader :revision, :operator_public_id

    def create_version(entry)
      version =
        entry.versions.create!(
          entry_revision: revision,
          locale: revision.locale,
          title: revision.title,
          summary: revision.summary,
          body: revision.body,
          schema_version: revision.schema_version,
          content_digest: revision.content_digest,
          created_by_operator_public_id: operator_public_id || revision.created_by_operator_public_id,
          sequence: next_sequence(entry),
        )
      copy_taxonomy_assignments(version)
      copy_media_usages(version)
      version
    rescue ActiveRecord::RecordNotUnique => e
      raise unless idempotency_violation?(e, self.class.idempotency_index_name(entry.class))

      verify_complete!(entry.versions.find_by!(entry_revision_id: revision.id))
    end

    # Only a collision on the revision idempotency index means another promotion
    # won the race. A duplicate sequence, public id, or any other unique
    # violation is a genuine failure and must propagate unswallowed.
    #
    # PostgreSQL reports the violated index in PG_DIAG_CONSTRAINT_NAME, which is
    # an exact identifier rather than prose, so an index whose name merely
    # contains another's cannot be confused for it. When that field is absent
    # (a non-pg adapter, or an error carrying no PG::Result) fall back to
    # searching the message for the index name. That fallback deliberately does
    # NOT parse the "unique constraint \"...\"" phrasing: PostgreSQL translates
    # that prose under a non-English lc_messages, while the index name itself is
    # always embedded verbatim.
    def idempotency_violation?(error, index_name)
      reported = violated_constraint(error)
      return reported == index_name if reported

      error.message.include?(index_name)
    end

    def violated_constraint(error)
      cause = error.cause
      return nil unless cause.respond_to?(:result)

      result = cause.result
      return nil if result.nil?

      result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME).presence
    end

    def lock_taxonomy!
      vocabulary_ids =
        (revision.single_taxonomy_assignments.pluck(:vocabulary_id) +
          revision.multiple_taxonomy_assignments.pluck(:vocabulary_id)).uniq
      vocabulary_ids.sort!
      return if vocabulary_ids.empty?

      vocab_class = revision.single_taxonomy_assignments.klass.reflect_on_association(:vocabulary).klass
      vocab_class.where(id: vocabulary_ids).order(:id).lock("FOR SHARE").load
    end

    def next_sequence(entry)
      (entry.versions.maximum(:sequence) || 0) + 1
    end

    def copy_taxonomy_assignments(version)
      revision.single_taxonomy_assignments.includes(:vocabulary, :taxonomy_term).find_each do |assignment|
        version.single_taxonomy_assignments
          .new(
            vocabulary_id: assignment.vocabulary_id,
            vocabulary_kind: assignment.vocabulary_kind,
            taxonomy_term_id: assignment.taxonomy_term_id,
            locale: assignment.locale,
          )
          .apply_snapshot(vocabulary: assignment.vocabulary, term: assignment.taxonomy_term)
          .save!
      end

      revision.multiple_taxonomy_assignments.includes(:vocabulary, :taxonomy_term).find_each do |assignment|
        version.multiple_taxonomy_assignments
          .new(
            vocabulary_id: assignment.vocabulary_id,
            vocabulary_kind: assignment.vocabulary_kind,
            taxonomy_term_id: assignment.taxonomy_term_id,
            locale: assignment.locale,
            position: assignment.position,
          )
          .apply_snapshot(vocabulary: assignment.vocabulary, term: assignment.taxonomy_term)
          .save!
      end
    end

    def copy_media_usages(version)
      revision.media_usages.find_each do |usage|
        version.media_usages.create!(
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

    def reject_archived_assignments!
      archived = revision.archived_taxonomy_assignments
      return if archived.empty?

      details =
        archived.flat_map do |assignment|
          obsolete = assignment.taxonomy_term.archived_in_path
          obsolete = [assignment.taxonomy_term] if obsolete.empty?
          obsolete.map do |term|
            ArchivedTaxonomyAssignmentError::Detail.new(
              vocabulary_key: assignment.vocabulary.key,
              term_public_id: term.public_id,
              term_slug: term.slug,
              revision_public_id: revision.public_id,
              assigned_term_public_id: assignment.taxonomy_term.public_id,
              vocabulary_archived: assignment.vocabulary.archived?,
            )
          end
        end
      raise(ArchivedTaxonomyAssignmentError, details)
    end

    def verify_complete!(version)
      unless version.entry_revision_id == revision.id
        raise(RevisionMismatchError, "version #{version.id} does not belong to revision #{revision.id}")
      end

      expected_single = revision.single_taxonomy_assignments.count
      expected_multiple = revision.multiple_taxonomy_assignments.count
      expected_media = revision.media_usages.count
      actual_single = version.single_taxonomy_assignments.count
      actual_multiple = version.multiple_taxonomy_assignments.count
      actual_media = version.media_usages.count

      unless expected_single == actual_single && expected_multiple == actual_multiple && expected_media == actual_media
        raise(
          IncompleteVersionError,
          "version #{version.id} holds #{actual_single}/#{actual_multiple} taxonomy snapshots " \
          "and #{actual_media} media usages, expected #{expected_single}/#{expected_multiple} " \
          "and #{expected_media}",
        )
      end

      version
    end
  end
end
