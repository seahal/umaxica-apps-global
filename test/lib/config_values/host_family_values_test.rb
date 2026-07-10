# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require Rails.root.join("lib/config_values_origin_value").to_s
require Rails.root.join("lib/config_values_host_family_values").to_s

class ConfigValuesHostFamilyValuesTest < ActiveSupport::TestCase
  test "build in non-production mode applies localhost fallbacks for every family" do
    values = ConfigValues::HostFamilyValues.build(env: {}, production: false)

    assert_equal "https://base.app.localhost", values.acme_service.to_s
    assert_equal "https://base.com.localhost", values.acme_corporate.to_s
    assert_equal "https://base.org.localhost", values.acme_staff.to_s

    assert_equal "https://sign.app.localhost", values.sign_service.to_s
    assert_equal "https://sign.com.localhost", values.sign_corporate.to_s
    assert_equal "https://sign.org.localhost", values.sign_staff.to_s

    assert_equal "https://jpx.umaxica.app", values.core_service.to_s
    assert_equal "https://jpx.umaxica.com", values.core_corporate.to_s
    assert_equal "https://jpx.umaxica.org", values.core_staff.to_s

    assert_equal "https://www-jp.umaxica.app", values.base_service.to_s
    assert_equal "https://www-jp.umaxica.com", values.base_corporate.to_s
    assert_equal "https://www-jp.umaxica.org", values.base_staff.to_s

    assert_equal "https://side-jp.umaxica.app", values.side_service.to_s
    assert_equal "https://side-jp.umaxica.com", values.side_corporate.to_s
    assert_equal "https://side-jp.umaxica.org", values.side_staff.to_s

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

    assert_equal 3, values.side_origins.size
    assert_equal [values.side_service, values.side_corporate, values.side_staff], values.side_origins

    assert_equal 3, values.palm_origins.size
    assert_equal [values.palm_service, values.palm_corporate, values.palm_staff], values.palm_origins

    assert_equal 3, values.info_origins.size
    assert_equal [values.info_service, values.info_corporate, values.info_staff], values.info_origins

    assert_equal values.sign_service, values.auth_service
    assert_equal values.sign_corporate, values.auth_corporate
    assert_equal values.sign_staff, values.auth_staff
    assert_equal [values.auth_service, values.auth_corporate, values.auth_staff], values.auth_origins
  end

  test "build in production mode prefers ENV overrides over fallbacks" do
    env = {
      "AUTH_SERVICE_URL" => "sign.example.test",
      "AUTH_CORPORATE_URL" => "sign-com.example.test",
      "AUTH_STAFF_URL" => "sign-org.example.test",
      "CORE_SERVICE_URL" => "jpx.example.test",
      "CORE_CORPORATE_URL" => "jpx-com.example.test",
      "CORE_STAFF_URL" => "jpx-org.example.test",
      "BASE_SERVICE_URL" => "base.example.test",
      "BASE_CORPORATE_URL" => "base-com.example.test",
      "BASE_STAFF_URL" => "base-org.example.test",
      "SIDE_SERVICE_URL" => "side.example.test",
      "SIDE_CORPORATE_URL" => "side-com.example.test",
      "SIDE_STAFF_URL" => "side-org.example.test",
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

    assert_equal "https://base.example.test", values.acme_service.to_s
    assert_equal "https://sign-org.example.test", values.sign_staff.to_s
    assert_equal "https://side.example.test", values.side_service.to_s
    assert_equal "https://palm-com.example.test", values.palm_corporate.to_s
    assert_equal "https://info-org.example.test", values.info_staff.to_s
    assert_not values.acme_origins.any?(&:nil?)
  end

  test "build in production mode raises KeyError when a required ENV key is missing" do
    assert_raises(KeyError) do
      ConfigValues::HostFamilyValues.build(env: {}, production: true)
    end
  end

  test "base origins fall back to PUBLIC_BASE_*_URL when SIDE_* and BASE_* are absent" do
    env = {
      "PUBLIC_BASE_SERVICE_URL" => "www.umaxica.app",
      "PUBLIC_BASE_CORPORATE_URL" => "www.umaxica.com",
      "PUBLIC_BASE_STAFF_URL" => "www.umaxica.org",
    }
    values = ConfigValues::HostFamilyValues.build(env: env, production: false)

    assert_equal "www.umaxica.app", values.base_service.host
    assert_equal "www.umaxica.com", values.base_corporate.host
    assert_equal "www.umaxica.org", values.base_staff.host
  end

  test "SIDE_*_URL configures side origins separately from base origins" do
    env = {
      "SIDE_SERVICE_URL" => "side.umaxica.app",
      "SIDE_CORPORATE_URL" => "side.umaxica.com",
      "SIDE_STAFF_URL" => "side.umaxica.org",
      "PUBLIC_BASE_SERVICE_URL" => "www.umaxica.app",
      "PUBLIC_BASE_CORPORATE_URL" => "www.umaxica.com",
      "PUBLIC_BASE_STAFF_URL" => "www.umaxica.org",
    }
    values = ConfigValues::HostFamilyValues.build(env: env, production: false)

    assert_equal "www.umaxica.app", values.base_service.host
    assert_equal "www.umaxica.com", values.base_corporate.host
    assert_equal "www.umaxica.org", values.base_staff.host
    assert_equal "side.umaxica.app", values.side_service.host
    assert_equal "side.umaxica.com", values.side_corporate.host
    assert_equal "side.umaxica.org", values.side_staff.host
  end

  test "BASE_*_URL takes precedence over PUBLIC_BASE_*_URL for base origins" do
    env = {
      "BASE_SERVICE_URL" => "base.umaxica.app",
      "BASE_CORPORATE_URL" => "base.umaxica.com",
      "BASE_STAFF_URL" => "base.umaxica.org",
      "PUBLIC_BASE_SERVICE_URL" => "www.umaxica.app",
      "PUBLIC_BASE_CORPORATE_URL" => "www.umaxica.com",
      "PUBLIC_BASE_STAFF_URL" => "www.umaxica.org",
    }
    values = ConfigValues::HostFamilyValues.build(env: env, production: false)

    assert_equal "base.umaxica.app", values.base_service.host
    assert_equal "base.umaxica.com", values.base_corporate.host
    assert_equal "base.umaxica.org", values.base_staff.host
  end

  test "origin adds an https scheme when the raw value lacks one" do
    env = {
      "AUTH_SERVICE_URL" => "https://sign.example.test",
      "AUTH_CORPORATE_URL" => "sign-com.example.test",
      "AUTH_STAFF_URL" => "sign-org.example.test",
      "CORE_SERVICE_URL" => "jpx.example.test",
      "CORE_CORPORATE_URL" => "jpx-com.example.test",
      "CORE_STAFF_URL" => "jpx-org.example.test",
      "BASE_SERVICE_URL" => "base.example.test",
      "BASE_CORPORATE_URL" => "base-com.example.test",
      "BASE_STAFF_URL" => "base-org.example.test",
      "SIDE_SERVICE_URL" => "side.example.test",
      "SIDE_CORPORATE_URL" => "side-com.example.test",
      "SIDE_STAFF_URL" => "side-org.example.test",
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

    assert_equal "https://base.example.test", values.acme_service.to_s
    assert_equal "https://sign.example.test", values.sign_service.to_s
    assert_equal "https://help.example.test", values.help_service.to_s
    assert_equal "https://info.example.test", values.info_service.to_s
  end
end
