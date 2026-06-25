# typed: false
# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/config_values_origin_value").to_s
require Rails.root.join("lib/config_values_host_family_values").to_s

class ConfigValuesHostFamilyValuesTest < ActiveSupport::TestCase
  test "build in non-production mode applies localhost fallbacks for every family" do
    values = ConfigValues::HostFamilyValues.build(env: {}, production: false)

    assert_equal "https://acme.app.localhost", values.acme_service.to_s
    assert_equal "https://acme.com.localhost", values.acme_corporate.to_s
    assert_equal "https://acme.org.localhost", values.acme_staff.to_s

    assert_equal "https://sign.app.localhost", values.sign_service.to_s
    assert_equal "https://sign.com.localhost", values.sign_corporate.to_s
    assert_equal "https://sign.org.localhost", values.sign_staff.to_s

    assert_equal "https://jpx.umaxica.app", values.core_service.to_s
    assert_equal "https://jpx.umaxica.com", values.core_corporate.to_s
    assert_equal "https://jpx.umaxica.org", values.core_staff.to_s

    assert_equal "https://www-jp.umaxica.app", values.base_service.to_s
    assert_equal "https://www-jp.umaxica.com", values.base_corporate.to_s
    assert_equal "https://www-jp.umaxica.org", values.base_staff.to_s

    assert_equal "https://palm-jp.umaxica.app", values.palm_service.to_s
    assert_equal "https://palm-jp.umaxica.com", values.palm_corporate.to_s
    assert_equal "https://palm-jp.umaxica.org", values.palm_staff.to_s

    assert_equal "https://help.app.localhost", values.help_service.to_s
    assert_equal "https://help.com.localhost", values.help_corporate.to_s
    assert_equal "https://help.org.localhost", values.help_staff.to_s

    assert_equal "https://info.app.localhost", values.info_service.to_s
    assert_equal "https://info.com.localhost", values.info_corporate.to_s
    assert_equal "https://info.org.localhost", values.info_staff.to_s
  end

  test "origins helpers group each family into its three surfaces" do
    values = ConfigValues::HostFamilyValues.build(env: {}, production: false)

    assert_equal 3, values.acme_origins.size
    assert_equal [values.acme_service, values.acme_corporate, values.acme_staff], values.acme_origins

    assert_equal 3, values.sign_origins.size
    assert_equal [values.sign_service, values.sign_corporate, values.sign_staff], values.sign_origins

    assert_equal 3, values.core_origins.size
    assert_equal [values.core_service, values.core_corporate, values.core_staff], values.core_origins

    assert_equal 3, values.base_origins.size
    assert_equal [values.base_service, values.base_corporate, values.base_staff], values.base_origins

    assert_equal 3, values.palm_origins.size
    assert_equal [values.palm_service, values.palm_corporate, values.palm_staff], values.palm_origins

    assert_equal 3, values.info_origins.size
    assert_equal [values.info_service, values.info_corporate, values.info_staff], values.info_origins
  end

  test "build in production mode prefers ENV overrides over fallbacks" do
    env = {
      "ACME_SERVICE_URL" => "acme.example.test",
      "ACME_CORPORATE_URL" => "acme-com.example.test",
      "ACME_STAFF_URL" => "acme-org.example.test",
      "SIGN_SERVICE_URL" => "sign.example.test",
      "SIGN_CORPORATE_URL" => "sign-com.example.test",
      "SIGN_STAFF_URL" => "sign-org.example.test",
      "CORE_SERVICE_URL" => "jpx.example.test",
      "CORE_CORPORATE_URL" => "jpx-com.example.test",
      "CORE_STAFF_URL" => "jpx-org.example.test",
      "BASE_SERVICE_URL" => "base.example.test",
      "BASE_CORPORATE_URL" => "base-com.example.test",
      "BASE_STAFF_URL" => "base-org.example.test",
      "PALM_SERVICE_URL" => "palm.example.test",
      "PALM_CORPORATE_URL" => "palm-com.example.test",
      "PALM_STAFF_URL" => "palm-org.example.test",
      "HELP_SERVICE_URL" => "help.example.test",
      "HELP_CORPORATE_URL" => "help-com.example.test",
      "HELP_STAFF_URL" => "help-org.example.test",
      "INFO_SERVICE_URL" => "info.example.test",
      "INFO_CORPORATE_URL" => "info-com.example.test",
      "INFO_STAFF_URL" => "info-org.example.test",
    }
    values = ConfigValues::HostFamilyValues.build(env: env, production: true)

    assert_equal "https://acme.example.test", values.acme_service.to_s
    assert_equal "https://sign-org.example.test", values.sign_staff.to_s
    assert_equal "https://palm-com.example.test", values.palm_corporate.to_s
    assert_equal "https://info-org.example.test", values.info_staff.to_s
    assert_not values.acme_origins.any?(&:nil?)
  end

  test "build in production mode raises KeyError when a required ENV key is missing" do
    assert_raises(KeyError) do
      ConfigValues::HostFamilyValues.build(env: {}, production: true)
    end
  end

  test "origin adds an https scheme when the raw value lacks one" do
    env = {
      "ACME_SERVICE_URL" => "acme.example.test",
      "ACME_CORPORATE_URL" => "acme-com.example.test",
      "ACME_STAFF_URL" => "acme-org.example.test",
      "SIGN_SERVICE_URL" => "https://sign.example.test",
      "SIGN_CORPORATE_URL" => "sign-com.example.test",
      "SIGN_STAFF_URL" => "sign-org.example.test",
      "CORE_SERVICE_URL" => "jpx.example.test",
      "CORE_CORPORATE_URL" => "jpx-com.example.test",
      "CORE_STAFF_URL" => "jpx-org.example.test",
      "BASE_SERVICE_URL" => "base.example.test",
      "BASE_CORPORATE_URL" => "base-com.example.test",
      "BASE_STAFF_URL" => "base-org.example.test",
      "PALM_SERVICE_URL" => "palm.example.test",
      "PALM_CORPORATE_URL" => "palm-com.example.test",
      "PALM_STAFF_URL" => "palm-org.example.test",
      "HELP_SERVICE_URL" => "help.example.test",
      "HELP_CORPORATE_URL" => "help-com.example.test",
      "HELP_STAFF_URL" => "help-org.example.test",
      "INFO_SERVICE_URL" => "info.example.test",
      "INFO_CORPORATE_URL" => "info-com.example.test",
      "INFO_STAFF_URL" => "info-org.example.test",
    }
    values = ConfigValues::HostFamilyValues.build(env: env, production: true)

    assert_equal "https://acme.example.test", values.acme_service.to_s
    assert_equal "https://sign.example.test", values.sign_service.to_s
    assert_equal "https://help.example.test", values.help_service.to_s
    assert_equal "https://info.example.test", values.info_service.to_s
  end
end
