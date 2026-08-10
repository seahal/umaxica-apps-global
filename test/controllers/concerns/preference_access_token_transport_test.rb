# typed: false
# frozen_string_literal: true

require "test_helper"

# Regression coverage for the credential-invalidation gap identified during
# the Preference lifecycle hardening review: `load_access_token_preference_record!`
# previously resolved a presented access JWT's public_id with a bare
# `find_by`, which never checked whether the underlying row had since been
# retired (PreferenceSignOutRotation) or naturally expired. Because
# PREFERENCE_JWT_TTL is 7 days (see app/values/security_token_lifetimes.rb),
# an already-issued access JWT would keep resolving to a retired row for up
# to 7 days after sign-out -- the DB-side retirement existed but was not
# enforced at the verification layer. This test proves the fix: the lookup
# is scoped to `active.unconsumed`.
class PreferenceAccessTokenTransportTest < ActiveSupport::TestCase
  fixtures :app_preference_statuses, :app_preference_binding_methods, :app_preference_dbsc_statuses

  setup do
    @preference = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      binding_method_id: AppPreferenceBindingMethod::NOTHING,
      dbsc_status_id: AppPreferenceDbscStatus::NOTHING,
      discarded_at: 20.years.from_now,
      purged_at: 20.years.from_now,
      jti: "current-jti",
    )
  end

  test "an active, unconsumed row still resolves normally" do
    ctx = build_context(public_id: @preference.public_id, jti: "current-jti")

    result = ctx.send(:load_access_token_preference_record!)

    assert_equal @preference.id, result&.id
  end

  test "a retired row (used_at + discarded_at in the past) is rejected even with a matching jti" do
    @preference.update!(used_at: Time.current, discarded_at: Time.current)
    ctx = build_context(public_id: @preference.public_id, jti: "current-jti")

    result = ctx.send(:load_access_token_preference_record!)

    assert_nil result, "a retired preference row must not be resurrected by an old, still-unexpired access JWT"
  end

  test "an expired-only row (discarded_at in the past, used_at nil) is rejected" do
    @preference.update_column(:discarded_at, 1.minute.ago)
    ctx = build_context(public_id: @preference.public_id, jti: "current-jti")

    result = ctx.send(:load_access_token_preference_record!)

    assert_nil result
  end

  test "a consumed-only row (used_at set, not yet discarded) is rejected" do
    @preference.update!(used_at: Time.current)
    ctx = build_context(public_id: @preference.public_id, jti: "current-jti")

    result = ctx.send(:load_access_token_preference_record!)

    assert_nil result
  end

  private

  def build_context(public_id:, jti:)
    ctx = Object.new
    ctx.extend(PreferenceAccessTokenTransport)
    ctx.instance_variable_set(:@preference_payload, { "public_id" => public_id, "jti" => jti })
    ctx.instance_variable_set(:@preferences, nil)
    ctx.define_singleton_method(:preference_class) { AppPreference }
    ctx.define_singleton_method(:preference_associations_to_preload) { [] }
    ctx.define_singleton_method(:with_preference_connection) { |_role, &blk| blk.call }
    ctx.define_singleton_method(:secure_compare?) { |a, b| a == b }
    ctx.define_singleton_method(:access_token_cookie_name) { "preference_access" }
    ctx.define_singleton_method(:preference_cookie_deletion_options) { {} }
    ctx.define_singleton_method(:cookies) {
      Class.new {
        def delete(*)
        end
      }.new
    }
    ctx
  end
end
