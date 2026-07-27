# frozen_string_literal: true

# adr/unified-enforcement.md: Enforcement Case, the policy SSOT for one com-realm
# principal's Identity BAN / Identity Freeze / Authentication Method Lock action.
# No foreign key to any principal row (Purge protection) -- principal_public_id
# and operator public ids are plain strings so a lapsed Case can never block a
# principal's deletion.
class CreateComEnforcementCases < ActiveRecord::Migration[8.2]
  def up
    create_table(:com_enforcement_cases) do |t|
      t.string(:public_id, limit: 21, null: false)
      t.string(:kind, null: false)
      t.string(:state, null: false, default: "draft")
      t.string(:duration_mode, null: false)
      t.string(:visibility, null: false, default: "visible")
      t.string(:release_mode, null: false)

      t.datetime(:effective_at, null: false)
      t.datetime(:expires_at)
      t.datetime(:ended_at)
      t.string(:end_reason)
      t.datetime(:review_due_at)

      t.string(:reason_code, null: false)
      t.text(:reason_note)
      t.string(:ticket_id)

      t.string(:principal_public_id, null: false)
      t.string(:applied_by_operator_public_id, null: false)
      t.string(:approved_by_operator_public_id)
      t.string(:ended_by_operator_public_id)

      t.boolean(:break_glass, null: false, default: false)
      t.string(:break_glass_approved_by_operator_public_id)

      t.datetime(:sessions_revoked_at)
      t.datetime(:audited_at)

      t.timestamps

      t.index(:public_id, unique: true)
      t.index(:principal_public_id)
      t.index(:kind)
      t.index(%i(state expires_at), name: "idx_com_enforcement_cases_state_expires_at")

      t.check_constraint(
        "kind IN ('security_lock', 'cooldown', 'temporary_freeze', 'permanent_ban', 'method_protection')",
        name: "chk_com_enforcement_cases_kind",
      )
      t.check_constraint(
        "state IN ('draft', 'pending_approval', 'active', 'ended', 'failed')",
        name: "chk_com_enforcement_cases_state",
      )
      t.check_constraint(
        "duration_mode IN ('timed', 'indefinite', 'permanent')",
        name: "chk_com_enforcement_cases_duration_mode",
      )
      t.check_constraint("visibility IN ('visible', 'hidden')", name: "chk_com_enforcement_cases_visibility")
      t.check_constraint(
        "release_mode IN ('automatic', 'operator', 'verification_required', 'break_glass_only')",
        name: "chk_com_enforcement_cases_release_mode",
      )
      t.check_constraint(
        "end_reason IS NULL OR end_reason IN (" \
        "'expired', 'revoked', 'superseded', 'corrected', 'appeal_approved', 'break_glass_released')",
        name: "chk_com_enforcement_cases_end_reason",
      )

      # D9 taxonomy: kind constrains duration_mode / expires_at / visibility / review_due_at.
      t.check_constraint(
        "kind != 'cooldown' OR (duration_mode = 'timed' AND expires_at IS NOT NULL " \
        "AND expires_at <= effective_at + INTERVAL '30 days')",
        name: "chk_com_enforcement_cases_cooldown_duration",
      )
      t.check_constraint(
        "kind != 'permanent_ban' OR (duration_mode = 'permanent' AND expires_at IS NULL)",
        name: "chk_com_enforcement_cases_permanent_ban_duration",
      )
      t.check_constraint(
        "kind != 'temporary_freeze' OR duration_mode IN ('timed', 'indefinite')",
        name: "chk_com_enforcement_cases_temp_freeze_duration_mode",
      )
      t.check_constraint(
        "kind != 'temporary_freeze' OR duration_mode != 'indefinite' OR " \
        "(review_due_at IS NOT NULL AND release_mode = 'operator')",
        name: "chk_com_enforcement_cases_indefinite_freeze_review",
      )
      t.check_constraint("visibility != 'hidden' OR kind = 'permanent_ban'", name: "chk_com_enforcement_cases_hidden")
      t.check_constraint(
        "kind != 'security_lock' OR release_mode = 'verification_required'",
        name: "chk_com_enforcement_cases_security_lock_release",
      )

      # D12: approval separation, operator self-action denial, break-glass approver required.
      t.check_constraint(
        "approved_by_operator_public_id IS NULL OR " \
        "approved_by_operator_public_id != applied_by_operator_public_id",
        name: "chk_com_enforcement_cases_approval_separation",
      )
      t.check_constraint(
        "principal_public_id != applied_by_operator_public_id",
        name: "chk_com_enforcement_cases_no_self_action",
      )
      t.check_constraint(
        "break_glass = false OR break_glass_approved_by_operator_public_id IS NOT NULL",
        name: "chk_com_enforcement_cases_break_glass_approver",
      )
    end
  end

  def down
    drop_table(:com_enforcement_cases)
  end
end
