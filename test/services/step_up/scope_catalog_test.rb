# typed: false
# frozen_string_literal: true

require "test_helper"

class StepUp::ScopeCatalogTest < ActiveSupport::TestCase
  test "configuration mfa uses the mfa challenge path on every surface" do
    path = "/configuration/mfa/challenge"

    assert_match StepUp::ScopeCatalog::APP.fetch("configuration_mfa"), path
    assert_match StepUp::ScopeCatalog::COM.fetch("configuration_mfa"), path
    assert_match StepUp::ScopeCatalog::ORG.fetch("configuration_mfa"), path
  end

  test "later step up scopes remain registered" do
    assert StepUp::ScopeCatalog::APP.key?("social_link")
    assert StepUp::ScopeCatalog::APP.key?("configuration_connection")
    assert StepUp::ScopeCatalog::COM.key?("configuration_connection")
    assert StepUp::ScopeCatalog::ORG.key?("configuration_connection")
    assert StepUp::ScopeCatalog::ORG.key?("operator_lifecycle")
  end

  test "social link scope is offered on app and org and matches social configuration pages" do
    app_pattern = StepUp::ScopeCatalog::APP.fetch("social_link")

    assert_match app_pattern, "/configuration/google"
    assert_match app_pattern, "/configuration/apple?ri=jp"
    assert_no_match app_pattern, "/social/auth/google_app/continue"
    assert_no_match app_pattern, "/configuration/emails"

    # Org links Google only (no Apple); com offers no social linking.
    org_pattern = StepUp::ScopeCatalog::ORG.fetch("social_link")

    assert_match org_pattern, "/configuration/google"
    assert_match org_pattern, "/configuration/google?ri=jp"
    assert_no_match org_pattern, "/configuration/apple"
    assert_no_match org_pattern, "/social/auth/google_org/continue"
    assert_not StepUp::ScopeCatalog::COM.key?("social_link")
  end

  test "configuration birthdate scope only matches the birthdate path" do
    app_pattern = StepUp::ScopeCatalog::APP.fetch("configuration_birthdate")
    com_pattern = StepUp::ScopeCatalog::COM.fetch("configuration_birthdate")
    org_pattern = StepUp::ScopeCatalog::ORG.fetch("configuration_birthdate")

    [app_pattern, com_pattern, org_pattern].each do |pattern|
      assert_match pattern, "/configuration/birthdate"
      assert_match pattern, "/configuration/birthdate?ri=jp"
      assert_no_match pattern, "/configuration/birthdate_extra"
      assert_no_match pattern, "/configuration/birthdate/extra"
    end
  end
end
