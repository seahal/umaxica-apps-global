# typed: false
# frozen_string_literal: true

require "test_helper"

class EnforcementIdentifierGateTest < ActiveSupport::TestCase
  class Harness
    include EnforcementIdentifierGate
  end

  setup do
    @previous_key = ENV.fetch("ENFORCEMENT_APP_IDENTIFIER_HMAC_KEY", nil)
    ENV["ENFORCEMENT_APP_IDENTIFIER_HMAC_KEY"] = "test-app-enforcement-key"
    @harness = Harness.new
  end

  teardown do
    ENV["ENFORCEMENT_APP_IDENTIFIER_HMAC_KEY"] = @previous_key
  end

  test "enforcement_blocks_email_registration? is false when no Identifier Effect is in force" do
    assert_not @harness.enforcement_blocks_email_registration?(
      effect_class: AppEnforcementIdentifierEffect, realm: "app", email: "person@example.com",
    )
  end

  test "enforcement_blocks_email_registration? is true when an in-force Identifier Effect blocks it" do
    client = clients(:one)
    operator = operators(:one)
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "visible",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    digest = EnforcementIdentifierDigest.for_email(realm: "app", value: "banned@example.com")
    the_case.identifier_effects.create!(**digest, registration_blocked: true, effective_at: Time.current)

    assert @harness.enforcement_blocks_email_registration?(
      effect_class: AppEnforcementIdentifierEffect, realm: "app", email: "Banned@Example.com",
    )
    assert_not @harness.enforcement_blocks_email_registration?(
      effect_class: AppEnforcementIdentifierEffect, realm: "app", email: "other@example.com",
    )
  end

  test "enforcement_blocks_email_attachment? and enforcement_blocks_email_recovery? check their own flags " \
       "independently" do
    client = clients(:one)
    operator = operators(:one)
    the_case = AppEnforcementCase.create!(
      kind: "cooldown",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "automatic",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    digest = EnforcementIdentifierDigest.for_email(realm: "app", value: "cooldown@example.com")
    the_case.identifier_effects.create!(**digest, attachment_blocked: true, effective_at: Time.current)

    assert @harness.enforcement_blocks_email_attachment?(
      effect_class: AppEnforcementIdentifierEffect, realm: "app", email: "cooldown@example.com",
    )
    assert_not @harness.enforcement_blocks_email_recovery?(
      effect_class: AppEnforcementIdentifierEffect, realm: "app", email: "cooldown@example.com",
    )
  end

  test "enforcement_blocks_telephone_attachment? and enforcement_blocks_telephone_recovery? check their own " \
       "flags independently" do
    client = clients(:one)
    operator = operators(:one)
    the_case = AppEnforcementCase.create!(
      kind: "cooldown",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "automatic",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    digest = EnforcementIdentifierDigest.for_telephone(realm: "app", value: "+15559876543")
    the_case.identifier_effects.create!(**digest, attachment_blocked: true, effective_at: Time.current)

    assert @harness.enforcement_blocks_telephone_attachment?(
      effect_class: AppEnforcementIdentifierEffect, realm: "app", telephone: "+15559876543",
    )
    assert_not @harness.enforcement_blocks_telephone_recovery?(
      effect_class: AppEnforcementIdentifierEffect, realm: "app", telephone: "+15559876543",
    )
  end

  test "an ended Identifier Effect no longer blocks" do
    client = clients(:one)
    operator = operators(:one)
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "visible",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    digest = EnforcementIdentifierDigest.for_email(realm: "app", value: "released@example.com")
    the_case.identifier_effects.create!(
      **digest, registration_blocked: true, effective_at: Time.current, ended_at: Time.current,
    )

    assert_not @harness.enforcement_blocks_email_registration?(
      effect_class: AppEnforcementIdentifierEffect, realm: "app", email: "released@example.com",
    )
  end
end
