# typed: false
# frozen_string_literal: true

require "test_helper"

class AccountStandingTest < ActiveSupport::TestCase
  FakePrincipalEffect = Struct.new(:access_blocking, keyword_init: true)
  FakeMethodEffect = Struct.new(:effect, keyword_init: true)
  FakeCase =
    Struct.new(
      :public_id, :kind, :reason_code, :release_mode, :effective_at, :expires_at, :principal_effect,
      :authentication_method_effects, :in_force, :visibility,
      keyword_init: true,
    ) do
      def in_force? = in_force
    end

  test "returns good when no visible case is in force" do
    standing = AccountStanding.from_cases([])

    assert_equal :good, standing.level
    assert_empty standing.decisions
  end

  test "returns notice for a visible case with no active restriction" do
    standing = AccountStanding.from_cases(
      [
        FakeCase.new(
          public_id: "case-notice", kind: "security_lock", reason_code: "security_incident", release_mode: "verification_required",
          effective_at: Time.current, expires_at: nil, principal_effect: nil,
          authentication_method_effects: [], in_force: true, visibility: "visible",
        ),
      ],
    )

    assert_equal :notice, standing.level
    assert_equal "case-notice", standing.decisions.fetch(0).fetch(:public_id)
  end

  test "returns limited for an active authentication method restriction" do
    standing = AccountStanding.from_cases(
      [
        FakeCase.new(
          public_id: "case-limited", kind: "method_protection", reason_code: "security_incident", release_mode: "operator",
          effective_at: Time.current, expires_at: nil, principal_effect: nil,
          authentication_method_effects: [FakeMethodEffect.new(effect: "unusable")], in_force: true,
          visibility: "visible",
        ),
      ],
    )

    assert_equal :limited, standing.level
  end

  test "returns locked for an active access-blocking principal effect" do
    standing = AccountStanding.from_cases(
      [
        FakeCase.new(
          public_id: "case-locked", kind: "temporary_freeze", reason_code: "terms_violation", release_mode: "operator",
          effective_at: Time.current, expires_at: nil,
          principal_effect: FakePrincipalEffect.new(access_blocking: true),
          authentication_method_effects: [], in_force: true, visibility: "visible",
        ),
      ],
    )

    assert_equal :locked, standing.level
  end

  test "does not expose hidden or ended cases" do
    standing = AccountStanding.from_cases(
      [
        FakeCase.new(
          public_id: "hidden-case", kind: "permanent_ban", reason_code: "abuse", release_mode: "break_glass_only",
          effective_at: Time.current, expires_at: nil,
          principal_effect: FakePrincipalEffect.new(access_blocking: true),
          authentication_method_effects: [], in_force: true, visibility: "hidden",
        ),
        FakeCase.new(
          public_id: "ended-case", kind: "cooldown", reason_code: "abuse", release_mode: "automatic",
          effective_at: Time.current, expires_at: nil, principal_effect: nil,
          authentication_method_effects: [], in_force: false, visibility: "visible",
        ),
      ],
    )

    assert_equal :good, standing.level
    assert_empty standing.decisions
  end
end
