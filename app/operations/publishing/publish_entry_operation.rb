# typed: false
# frozen_string_literal: true

module Publishing
  # Publishes an entry: promotes its current revision to an immutable version
  # and opens a publication window on that version.
  #
  # These are two rows in two tables and neither is useful alone -- a version
  # nothing points at is invisible, and a publication needs a version to point
  # at -- so both commit inside the entry's lock.
  #
  # Superseding is part of publishing, not a separate step. The publications
  # table carries `excl_<cell>_pub_windows`, a GiST exclusion constraint that
  # refuses two overlapping windows for one entry, so the live publication is
  # terminated at the exact instant the new one becomes effective. `[)` bounds
  # make those two rows adjacent rather than overlapping.
  #
  # `effective_from` in the future schedules the change instead of applying it
  # now: the live publication is then set to end at that same future instant.
  class PublishEntryOperation < ApplicationService
    # The exclusion constraint that decides whether a requested window is free.
    # A violation is a scheduling conflict the operator can resolve, so it is
    # answered with a failed Result; any other constraint violation raises.
    def self.window_constraint_name(entry_class)
      "excl_#{entry_class::SURFACE}_#{entry_class::AUDIENCE}_pub_windows"
    end

    def initialize(entry:, operator_public_id:, effective_from: nil)
      super()
      @entry = entry
      @operator_public_id = operator_public_id
      @effective_from = effective_from
    end

    def call
      entry.with_lock { publish }
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.message.include?(self.class.window_constraint_name(entry.class))

      PublishingPublicationResult.failure(
        effective_from: "overlaps a publication window that is already scheduled",
      )
    end

    private

    attr_reader :entry, :operator_public_id, :effective_from

    def publish
      return PublishingPublicationResult.failure(base: "an archived entry cannot be published") if entry.archived?

      revision = entry.current_revision
      if revision.blank?
        return PublishingPublicationResult.failure(base: "entry has no current revision to publish")
      end

      version = PromoteRevisionOperation.call(revision:, operator_public_id:)
      open_window(version)
    end

    def open_window(version)
      starts_at = effective_from || Time.current
      live = entry.publications.active.take

      if live
        return PublishingPublicationResult.success(live) if already_published?(live, version)

        # Terminating the live window is only expressible when the new one
        # starts strictly after the live one did: `chk_<cell>_pub_window`
        # requires `effective_until > effective_from`. An earlier start would
        # be a rewrite of history, which this operation does not do.
        if starts_at <= live.effective_from
          return PublishingPublicationResult.failure(
            effective_from: "must be after the current publication became effective",
          )
        end

        live.update!(
          effective_until: starts_at,
          terminated_at: starts_at,
          termination_reason: "superseded by a newer version",
          ended_by_operator_public_id: operator_public_id,
        )
      end

      PublishingPublicationResult.success(create_publication(version, starts_at))
    end

    # Re-publishing an unchanged entry is a no-op rather than a second window
    # on the same version. An explicit `effective_from` is never a no-op: the
    # operator asked for a different window, even on the same version.
    def already_published?(live, version)
      live.entry_version_id == version.id && effective_from.nil?
    end

    def create_publication(version, starts_at)
      entry.publications.create!(
        entry_version: version,
        effective_from: starts_at,
        created_by_operator_public_id: operator_public_id,
      )
    end
  end
end
