# typed: false
# frozen_string_literal: true

require "json"

module AvatarBackfill
  class BackfillLegacyClientBindings < ApplicationService
    Result = Data.define(:summary, :details) do
      def to_h = { summary: summary, details: details }
      def to_json(*) = JSON.pretty_generate(to_h)
    end

    RESULT_BUCKETS = %w(
      created
      skipped_already_bound_consistent
      skipped_conflict
      skipped_deleted
      skipped_missing_subject
      skipped_unresolved
      skipped_multiple_legacy_avatars
      failed
    ).freeze

    def initialize(apply: false, output_path: nil)
      super()
      @apply = apply
      @output_path = output_path
    end

    def call
      audit = AuditLegacyClientBindings.call
      details = audit.details.map { |candidate| backfill_candidate(candidate) }
      result = Result.new(summary: build_summary(details), details: details)
      write_report(result) if output_path.present?
      result
    end

    private

    attr_reader :apply, :output_path

    def backfill_candidate(candidate)
      case candidate.fetch(:conflict_bucket)
      when "safe_to_backfill"
        create_binding(candidate)
      when "already_bound_consistent"
        detail(candidate, "skipped_already_bound_consistent", "binding already exists", "no change needed")
      when "deleted_avatar_skipped"
        detail(candidate, "skipped_deleted", "avatar is deleted or inaccessible", "no change")
      when "missing_client"
        detail(candidate, "skipped_missing_subject", "legacy client is missing", "manual review required")
      when "unresolved_subject", "ambiguous_subject"
        detail(candidate, "skipped_unresolved", candidate.fetch(:reason), "manual review required")
      when "multiple_legacy_avatars_for_subject"
        detail(candidate, "skipped_multiple_legacy_avatars", candidate.fetch(:reason), "manual review required")
      else
        detail(candidate, "skipped_conflict", candidate.fetch(:reason), "manual review required")
      end
    end

    def create_binding(candidate)
      return detail(candidate, "created", "dry-run candidate; no row created", "run with APPLY=1 to create binding") unless apply

      Avatar.transaction do
        avatar = Avatar.lock.find(candidate.fetch(:avatar_id))
        refreshed = AuditLegacyClientBindings.call.details.find { |row| row.fetch(:avatar_id) == avatar.id }
        unless refreshed&.fetch(:conflict_bucket) == "safe_to_backfill"
          return detail(candidate, "skipped_conflict", "candidate changed before apply", "rerun audit")
        end

        binding = AvatarPersonaBinding.create!(
          avatar: avatar,
          persona_id: candidate.fetch(:resolved_subject_id),
          assigned_at: avatar.created_at || Time.current,
        )

        detail(candidate.merge(existing_binding_type: binding.class.name, existing_binding_public_id: binding.public_id),
               "created", "created AvatarPersonaBinding", "no change needed")
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => error
      detail(candidate, "failed", "#{error.class}: #{error.message}", "manual review required")
    end

    def detail(candidate, bucket, reason, action)
      candidate.merge(backfill_bucket: bucket, reason: reason, recommended_next_action: action, applied: apply)
    end

    def build_summary(details)
      summary = { apply: apply, total_candidates_scanned: details.size }
      RESULT_BUCKETS.each { |bucket| summary[:"#{bucket}_count"] = details.count { |detail| detail[:backfill_bucket] == bucket } }
      summary
    end

    def write_report(result)
      path = Rails.root.join(output_path)
      FileUtils.mkdir_p(path.dirname)
      File.write(path, result.to_json)
    end
  end
end
