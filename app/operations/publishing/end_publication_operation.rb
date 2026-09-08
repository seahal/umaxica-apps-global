# typed: false
# frozen_string_literal: true

module Publishing
  # Ends a publication window: the CMS "unpublish".
  #
  # The table models two different endings and the check constraints decide
  # which one is legal, not the caller's intent:
  #
  # - `chk_<cell>_pub_cancel` requires `cancelled_at < effective_from`, so a
  #   window that has not started yet is *cancelled* -- it never took effect.
  # - `chk_<cell>_pub_term` requires `terminated_at >= effective_from` and
  #   `effective_until = terminated_at`, so a window that is already in effect
  #   is *terminated* -- it took effect and then stopped.
  #
  # Both endings require a reason; the column is `NOT NULL` whenever its
  # timestamp is set, which is why the caller must supply one.
  class EndPublicationOperation < ApplicationService
    def initialize(publication:, reason:, operator_public_id:)
      super()
      @publication = publication
      @reason = reason
      @operator_public_id = operator_public_id
    end

    def call
      publication.entry.with_lock do
        publication.reload

        if publication.cancelled? || publication.terminated?
          next PublishingPublicationResult.failure(base: "publication has already ended")
        end

        end_window(Time.current)
        PublishingPublicationResult.success(publication)
      end
    end

    private

    attr_reader :publication, :reason, :operator_public_id

    def end_window(now)
      if publication.effective_from > now
        publication.update!(
          cancelled_at: now,
          cancellation_reason: reason,
          ended_by_operator_public_id: operator_public_id,
        )
      else
        publication.update!(
          effective_until: now,
          terminated_at: now,
          termination_reason: reason,
          ended_by_operator_public_id: operator_public_id,
        )
      end
    end
  end
end
