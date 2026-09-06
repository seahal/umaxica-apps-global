# typed: false
# frozen_string_literal: true

module Publishing
  # Creates the three rows a new CMS entry needs: the entry, its canonical
  # slug, and revision 1. Nothing else in the application created an entry --
  # only `db/seeds.rb` did -- so a staff operator could edit content but never
  # start any.
  #
  # All three rows commit together. A slug is what a published URL resolves
  # on, so an entry that reached the database without one would be reachable
  # from the CMS index and from nowhere else.
  class CreateEntryOperation < ApplicationService
    # The content schema an entry starts on. Revisions carry the version
    # forward (`ReviseEntryOperation` copies `current.schema_version`), so
    # this constant is read exactly once per entry, at creation.
    INITIAL_SCHEMA_VERSION = 1

    # The slug is unique per locale within the cell. A collision on that index
    # is a name the operator can change; a collision on any other unique index
    # of the same insert -- a minted public id -- is not, and must not be
    # reported as a taken slug.
    def self.slug_index_name(entry_class)
      "uidx_#{entry_class::SURFACE}_#{entry_class::AUDIENCE}_slug_locale"
    end

    def initialize(entry_class:, locale:, slug:, title:, summary:, body:, operator_public_id:)
      super()
      @entry_class = entry_class
      @locale = locale
      @slug = slug
      @title = title
      @summary = summary
      @body = body
      @operator_public_id = operator_public_id
    end

    def call
      entry = nil

      entry_class.transaction do
        entry = entry_class.create!(locale:)
        entry.slugs.create!(locale:, slug:, state: "canonical", canonicalized_at: Time.current)
        revision = create_revision(entry)
        entry.update!(current_revision: revision)
      end

      PublishingCreateEntryResult.success(entry)
    rescue ActiveRecord::RecordNotUnique => e
      raise unless e.message.include?(self.class.slug_index_name(entry_class))

      PublishingCreateEntryResult.failure(slug: "is already used by another entry in this locale")
    end

    private

    attr_reader :entry_class, :locale, :slug, :title, :summary, :body, :operator_public_id

    def create_revision(entry)
      entry.revisions.create!(
        locale:,
        title:,
        summary:,
        body:,
        schema_version: INITIAL_SCHEMA_VERSION,
        content_digest: PublishingRevisionContentDigest.call(
          schema_version: INITIAL_SCHEMA_VERSION,
          locale:,
          title:,
          summary:,
          body:,
        ),
        created_by_operator_public_id: operator_public_id,
        sequence: 1,
      )
    end
  end
end
