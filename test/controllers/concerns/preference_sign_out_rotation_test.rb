# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceSignOutRotationTest < ActiveSupport::TestCase
  fixtures :app_preferences, :app_preference_statuses, :app_preference_binding_methods, :app_preference_dbsc_statuses,
           :app_preference_language_options, :app_preference_theme_options

  setup do
    @old_preference = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      binding_method_id: AppPreferenceBindingMethod::NOTHING,
      dbsc_status_id: AppPreferenceDbscStatus::NOTHING,
      discarded_at: 20.years.from_now,
      purged_at: 20.years.from_now,
    )
    AppPreferenceLanguageOption.ensure_defaults!
    AppPreferenceThemeOption.ensure_defaults!
    AppPreferenceLanguage.create!(preference: @old_preference, option_id: AppPreferenceLanguageOption::EN)
    AppPreferenceTheme.create!(preference: @old_preference, option_id: AppPreferenceThemeOption::DARK)
  end

  test "rotate_preference_after_sign_out! retires the old row and seeds a fresh guest row with safe values only" do
    ctx = build_context(@old_preference)

    new_preference = nil
    assert_difference "AppPreference.count", 1 do
      ctx.send(:rotate_preference_after_sign_out!)
      new_preference = ctx.instance_variable_get(:@preferences)
    end

    assert_not_equal @old_preference.id, new_preference.id
    assert_equal AppPreferenceLanguageOption::EN, new_preference.app_preference_language.option_id
    assert_equal AppPreferenceThemeOption::DARK, new_preference.app_preference_theme.option_id
    assert_not new_preference.explicit_field?(:language),
               "safe-copied sign-out seed must not be marked explicit for the new guest identity"
    assert_not new_preference.explicit_field?(:theme)
  end

  test "rotate_preference_after_sign_out! retires the old preference row so it can no longer be presented" do
    ctx = build_context(@old_preference)

    ctx.send(:rotate_preference_after_sign_out!)

    @old_preference.reload

    assert_predicate @old_preference, :replay?, "old row must be consumed (used_at set)"
    assert_operator @old_preference.discarded_at, :<=, Time.current,
                    "old row must fall out of the active scope immediately"
  end

  test "rotate_preference_after_sign_out! never raises when @preferences is blank" do
    ctx = build_context(nil)

    assert_nothing_raised { ctx.send(:rotate_preference_after_sign_out!) }
  end

  # --- failure injection: each stage must fail safely, be observable, and
  # never leave the old credential in an inconsistent (silently-untouched
  # but reported-as-successful) state. ---

  test "failure before the new guest row is created: old row is untouched, logged at error, auth logout unaffected" do
    ctx = build_context(@old_preference)
    ctx.define_singleton_method(:create_new_preference_record!) do |**_kwargs|
      raise ActiveRecord::RecordInvalid, AppPreference.new
    end

    logged = capture_structured_logs(:error) { ctx.send(:rotate_preference_after_sign_out!) }

    assert_equal 1, logged.size
    assert_equal "preference.sign_out.retirement_failed", logged.first[:event]
    assert_equal "new_identity_creation", logged.first[:data][:stage]
    assert_equal 1, AppPreference.where(id: @old_preference.id).count
    assert_old_row_still_valid!
  end

  test "failure after new guest creation but before old retirement: transaction rolls back, no orphan guest row" do
    ctx = build_context(@old_preference)
    ctx.define_singleton_method(:seed_guest_preference_from_sign_out!) { |*_args| raise StandardError, "seed boom" }

    logged = nil
    assert_no_difference "AppPreference.count" do
      logged = capture_structured_logs(:error) { ctx.send(:rotate_preference_after_sign_out!) }
    end

    assert_equal 1, logged.size
    assert_equal "preference.sign_out.retirement_failed", logged.first[:event]
    assert_equal "safe_value_seed", logged.first[:data][:stage]
    assert_old_row_still_valid!
  end

  test "failure during old row retirement: transaction rolls back, no orphan guest row, old row still valid" do
    ctx = build_context(@old_preference)
    ctx.define_singleton_method(:retire_preference_after_sign_out!) { |_pref| raise StandardError, "retire boom" }

    logged = nil
    assert_no_difference "AppPreference.count" do
      logged = capture_structured_logs(:error) { ctx.send(:rotate_preference_after_sign_out!) }
    end

    assert_equal 1, logged.size
    assert_equal "preference.sign_out.retirement_failed", logged.first[:event]
    assert_equal "old_credential_retirement", logged.first[:data][:stage]
    assert_old_row_still_valid!
  end

  test "failure while issuing the new cookie: DB rotation already committed, distinct warn-level event, no raise" do
    ctx = build_context(@old_preference)
    ctx.define_singleton_method(:issue_access_token_from) { |_pref| raise StandardError, "cookie boom" }

    logged =
      capture_structured_logs(:warn) do
        assert_nothing_raised { ctx.send(:rotate_preference_after_sign_out!) }
      end

    assert_equal 1, logged.size
    assert_equal "preference.sign_out.cookie_issuance_failed", logged.first[:event]
    # The DB-side rotation already succeeded (this failure is purely in
    # cookie issuance), so the old row IS retired here -- unlike the DB-stage
    # failures above, which roll back and leave it valid.
    assert_predicate @old_preference.reload, :replay?
  end

  test "retrying rotate_preference_after_sign_out! after the old row is already retired does not raise" do
    ctx = build_context(@old_preference)
    ctx.send(:rotate_preference_after_sign_out!)
    first_new_preference = ctx.instance_variable_get(:@preferences)

    assert_nothing_raised { ctx.send(:rotate_preference_after_sign_out!) }

    second_new_preference = ctx.instance_variable_get(:@preferences)

    assert_not_equal first_new_preference.id, second_new_preference.id,
                     "a second rotation call creates its own new guest row rather than reusing the first"
  end

  test "failure logs never include the raw refresh token, digest, or cookie value" do
    ctx = build_context(@old_preference)
    ctx.define_singleton_method(:create_new_preference_record!) do |**_kwargs|
      raise StandardError, "boom"
    end

    logged = capture_structured_logs(:error) { ctx.send(:rotate_preference_after_sign_out!) }

    serialized = logged.to_s

    assert_not_includes serialized.downcase, "bearer "
    assert_not_includes serialized, @old_preference.token_digest.to_s if @old_preference.token_digest.present?
  end

  private

  def capture_structured_logs(severity)
    logged = []
    Rails.logger.stub(severity, ->(message) { logged << JSON.parse(message, symbolize_names: true) }) { yield }
    logged
  end

  def assert_old_row_still_valid!
    @old_preference.reload

    assert_not @old_preference.replay?, "old row must remain unconsumed when rotation failed and rolled back"
    assert_operator @old_preference.discarded_at, :>, Time.current,
                    "old row must remain in the active scope when rotation failed and rolled back"
  end

  def build_context(preference)
    ctx = Object.new
    ctx.extend(PreferenceSignOutRotation)
    ctx.instance_variable_set(:@preferences, preference)
    ctx.define_singleton_method(:preference_class) { AppPreference }
    ctx.define_singleton_method(:preference_connection_class) { |_record| AppSettingRecord }
    ctx.define_singleton_method(:issue_access_token_from) { |_pref| nil }
    ctx.define_singleton_method(:create_new_preference_record!) do |params_hash: nil|
      _ = params_hash
      AppPreference.create!(
        status_id: AppPreferenceStatus::NOTHING,
        binding_method_id: AppPreferenceBindingMethod::NOTHING,
        dbsc_status_id: AppPreferenceDbscStatus::NOTHING,
        discarded_at: 20.years.from_now,
        purged_at: 20.years.from_now,
        jti: JitSecurityJwtJtiGenerator.generate,
      ).tap { |pref| PreferenceSignOutRotationTestSupport.create_default_children!(pref) }
    end
    ctx
  end
end

module PreferenceSignOutRotationTestSupport
  def self.create_default_children!(preference)
    AppPreferenceLanguageOption.ensure_defaults!
    AppPreferenceThemeOption.ensure_defaults!
    AppPreferenceLanguage.create!(preference: preference, option_id: AppPreferenceLanguageOption::JA)
    AppPreferenceTheme.create!(preference: preference, option_id: AppPreferenceThemeOption::SYSTEM)
  end
end
