# typed: false
# frozen_string_literal: true

require "test_helper"

class StepUpScopeCatalogTest < ActiveSupport::TestCase
  test "settings mfa uses the mfa challenge path on every surface" do
    path = "/settings/mfa/challenge"

    assert_match StepUpScopeCatalog::APP.fetch("settings_mfa"), path
    assert_match StepUpScopeCatalog::COM.fetch("settings_mfa"), path
    assert_match StepUpScopeCatalog::ORG.fetch("settings_mfa"), path
  end

  test "later step up scopes remain registered" do
    assert StepUpScopeCatalog::APP.key?("social_link")
    assert StepUpScopeCatalog::APP.key?("settings_connection")
    assert StepUpScopeCatalog::COM.key?("settings_connection")
    assert StepUpScopeCatalog::ORG.key?("settings_connection")
    assert StepUpScopeCatalog::ORG.key?("operator_lifecycle")
  end

  test "social link scope is offered on app and org and matches social settings pages" do
    app_pattern = StepUpScopeCatalog::APP.fetch("social_link")

    assert_match app_pattern, "/settings/google"
    assert_match app_pattern, "/settings/apple?ri=jp"
    assert_no_match app_pattern, "/social/auth/google_app/continue"
    assert_no_match app_pattern, "/settings/emails"

    # Org links Google only (no Apple); com offers no social linking.
    org_pattern = StepUpScopeCatalog::ORG.fetch("social_link")

    assert_match org_pattern, "/settings/google"
    assert_match org_pattern, "/settings/google?ri=jp"
    assert_no_match org_pattern, "/settings/apple"
    assert_no_match org_pattern, "/social/auth/google_#{"org"}/continue"
    assert_not StepUpScopeCatalog::COM.key?("social_link")
  end

  test "settings birthdate scope only matches the birthdate path" do
    app_pattern = StepUpScopeCatalog::APP.fetch("settings_birthdate")
    com_pattern = StepUpScopeCatalog::COM.fetch("settings_birthdate")
    org_pattern = StepUpScopeCatalog::ORG.fetch("settings_birthdate")

    [app_pattern, com_pattern, org_pattern].each do |pattern|
      assert_match pattern, "/settings/birthdate"
      assert_match pattern, "/settings/birthdate?ri=jp"
      assert_no_match pattern, "/settings/birthdate_extra"
      assert_no_match pattern, "/settings/birthdate/extra"
    end
  end
end
