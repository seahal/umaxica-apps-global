# typed: false
# frozen_string_literal: true

# Manual database initialization for test environment.
# These values are often expected to exist by various tests.

require Rails.root.join("app/models/preference/generated_models").to_s

require Rails.root.join("app/models/operator").to_s

module TestReferenceDefaults
  module_function

  def ensure_defaults!
    return if ENV["SKIP_DB"] == "1"

    {
      "UserChronicleEvent" => -> { UserChronicleEvent },
      "UserChronicleLevel" => -> { UserChronicleLevel },
      "OperatorChronicleEvent" => -> { OperatorChronicleEvent },
      "AppPreferenceChronicleLevel" => -> { AppPreferenceChronicleLevel },
      "AppPreferenceChronicleEvent" => -> { AppPreferenceChronicleEvent },
      "ComPreferenceChronicleLevel" => -> { ComPreferenceChronicleLevel },
      "ComPreferenceChronicleEvent" => -> { ComPreferenceChronicleEvent },
      "OrgPreferenceChronicleLevel" => -> { OrgPreferenceChronicleLevel },
      "OrgPreferenceChronicleEvent" => -> { OrgPreferenceChronicleEvent },
    }.each do |constant_name, resolver|
      next unless Object.const_defined?(constant_name)

      resolver.call.ensure_defaults!
    end

    OperatorChronicleLevel.insert_missing_fixed_ids!([OperatorChronicleLevel::NOTHING]) if defined?(OperatorChronicleLevel)

    %w(
      AppPreferenceBindingMethod
      AppPreferenceCurrencyOption
      AppPreferenceDateFormatOption
      AppPreferenceTimeFormatOption
      AppPreferenceMotionOption
      AppPreferenceDensityOption
      AppPreferenceItemsPerPageOption
      UserPreferenceCurrencyOption
      UserPreferenceDateFormatOption
      UserPreferenceTimeFormatOption
      UserPreferenceMotionOption
      UserPreferenceDensityOption
      UserPreferenceItemsPerPageOption
      OrgPreferenceBindingMethod
      OrgPreferenceCurrencyOption
      OrgPreferenceDateFormatOption
      OrgPreferenceTimeFormatOption
      OrgPreferenceMotionOption
      OrgPreferenceDensityOption
      OrgPreferenceItemsPerPageOption
      OperatorPreferenceCurrencyOption
      OperatorPreferenceDateFormatOption
      OperatorPreferenceTimeFormatOption
      OperatorPreferenceMotionOption
      OperatorPreferenceDensityOption
      OperatorPreferenceItemsPerPageOption
      ComPreferenceBindingMethod
      ComPreferenceCurrencyOption
      ComPreferenceDateFormatOption
      ComPreferenceTimeFormatOption
      ComPreferenceMotionOption
      ComPreferenceDensityOption
      ComPreferenceItemsPerPageOption
      VisitorPreferenceCurrencyOption
      VisitorPreferenceDateFormatOption
      VisitorPreferenceTimeFormatOption
      VisitorPreferenceMotionOption
      VisitorPreferenceDensityOption
      VisitorPreferenceItemsPerPageOption
      UserStatus
      UserMultiFactor
      UserMultiFactorStatus
      UserVisibility
      OperatorIdentityStatus
      OperatorMultiFactor
      OperatorMultiFactorStatus
      OperatorVisibility
      VisitorStatus
      VisitorMultiFactor
      VisitorMultiFactorStatus
      VisitorClientStatus
      VisitorVisibility
      UserTokenStatus
      UserTokenKind
      OperatorTokenKind
      VisitorTokenKind
      UserTokenBindingMethod
      UserTokenDbscStatus
      UserTokenStatus
      OperatorTokenBindingMethod
      OperatorTokenDbscStatus
      OperatorTokenStatus
      VisitorTokenBindingMethod
      VisitorTokenDbscStatus
      VisitorTokenStatus
      UserEmailStatus
      UserTelephoneStatus
      UserOneTimePasswordStatus
      UserSocialGoogleStatus
      UserSocialAppleStatus
      UserPasskeyStatus
      UserSecretStatus
      OperatorEmailStatus
      OperatorTelephoneStatus
      VisitorEmailStatus
      VisitorTelephoneStatus
      VisitorPasskeyStatus
      VisitorSecretStatus
    ).each do |constant_name|
      next unless Object.const_defined?(constant_name)

      Object.const_get(constant_name).ensure_defaults!
    end
  end

  def ensure_after_fixtures!
    return if defined?(@_after_fixtures_initialized) &&
      @_after_fixtures_initialized &&
      reference_defaults_present?

    ensure_defaults!
    @_after_fixtures_initialized = true
  end

  def reference_defaults_present?
    return false if Object.const_defined?("AppPreferenceChronicleEvent") &&
      (AppPreferenceChronicleEvent::DEFAULTS - AppPreferenceChronicleEvent.pluck(:id)).any?
    return false if Object.const_defined?("OrgPreferenceChronicleEvent") &&
      (OrgPreferenceChronicleEvent::DEFAULTS - OrgPreferenceChronicleEvent.pluck(:id)).any?
    return false if Object.const_defined?("ComPreferenceChronicleEvent") &&
      (ComPreferenceChronicleEvent::DEFAULTS - ComPreferenceChronicleEvent.pluck(:id)).any?

    return true unless Object.const_defined?("UserPreferenceCurrencyOption")

    UserPreferenceCurrencyOption.exists?(id: UserPreferenceCurrencyOption::JPY) &&
      (!Object.const_defined?("OperatorTokenBindingMethod") ||
        OperatorTokenBindingMethod.exists?(id: OperatorTokenBindingMethod::NOTHING)) &&
      (!Object.const_defined?("AppPreferenceBindingMethod") ||
        AppPreferenceBindingMethod.exists?(id: AppPreferenceBindingMethod::NOTHING))
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
    false
  end
end

ActiveSupport.on_load(:active_record) do
  next if ENV["SKIP_DB"] == "1" || defined?(@_test_reference_data_initialized)

  @_test_reference_data_initialized = true

  if defined?(Prosopite)
    Prosopite.pause { TestReferenceDefaults.ensure_defaults! }
  else
    TestReferenceDefaults.ensure_defaults!
  end
end

ActiveSupport.on_load(:active_record_fixtures) do
  set_fixture_class(
    staff_banners: "OperatorBanner",
    staff_chronicle_events: "OperatorChronicleEvent",
    staff_chronicle_levels: "OperatorChronicleLevel",
    staff_chronicles: "OperatorChronicle",
    staff_email_statuses: "OperatorEmailStatus",
    staff_emails: "OperatorEmail",
    staff_multi_factors: "OperatorMultiFactor",
    staff_multi_factor_statuses: "OperatorMultiFactorStatus",
    staff_occurrence_statuses: "OperatorOccurrenceStatus",
    staff_occurrences: "OperatorOccurrence",
    staff_org_preferences: "OperatorOrgPreference",
    staff_passkey_statuses: "OperatorPasskeyStatus",
    staff_passkeys: "OperatorPasskey",
    staff_preference_language_options: "OperatorPreferenceLanguageOption",
    staff_preference_languages: "OperatorPreferenceLanguage",
    staff_preference_region_options: "OperatorPreferenceRegionOption",
    staff_preference_regions: "OperatorPreferenceRegion",
    staff_preference_theme_options: "OperatorPreferenceThemeOption",
    staff_preference_themes: "OperatorPreferenceTheme",
    staff_preference_timezone_options: "OperatorPreferenceTimezoneOption",
    staff_preference_timezones: "OperatorPreferenceTimezone",
    staff_preferences: "OperatorPreference",
    staff_secret_kinds: "OperatorSecretKind",
    staff_secret_statuses: "OperatorSecretStatus",
    staff_secrets: "OperatorSecret",
    staff_statuses: "OperatorIdentityStatus",
    staff_telephone_statuses: "OperatorTelephoneStatus",
    staff_telephones: "OperatorTelephone",
    staff_token_binding_methods: "OperatorTokenBindingMethod",
    staff_token_dbsc_statuses: "OperatorTokenDbscStatus",
    staff_token_kinds: "OperatorTokenKind",
    staff_token_statuses: "OperatorTokenStatus",
    staff_tokens: "OperatorToken",
    staff_verifications: "OperatorVerification",
    staff_visibilities: "OperatorVisibility",
    staffs: "Operator",
    staff_bulletins: "OperatorBulletin",
    client_banners: "VisitorAccountBanner",
    client_statuses: "VisitorAccountStatus",
    clients: "VisitorAccount",
  )

  setup do
    TestReferenceDefaults.ensure_after_fixtures!
  end
end
