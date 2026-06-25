# typed: false
# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/app_config_loader").to_s

class AppConfigLoaderTest < ActiveSupport::TestCase
  test "loads localhost defaults in test" do
    env = {}

    config = AppConfigLoader.load!(env: env, rails_env: ActiveSupport::EnvironmentInquirer.new("test"))

    assert_equal "acme.app.localhost", config.fetch(:hosts).acme_service.host
    assert_equal "sign.app.localhost", config.fetch(:hosts).sign_service.host
    assert_equal "jpx.umaxica.app", config.fetch(:hosts).core_service.host
    assert_equal "www-jp.umaxica.app", config.fetch(:hosts).base_service.host
    assert_equal "palm-jp.umaxica.app", config.fetch(:hosts).palm_service.host
    assert_equal "help.app.localhost", config.fetch(:hosts).help_service.host
    assert_equal "https://jump.umaxica.net", config.fetch(:jump).origin.to_s
  end

  test "loads cloudflare tunnel host families from production env" do
    env = {
      "ACME_SERVICE_URL" => "www.umaxica.app",
      "ACME_CORPORATE_URL" => "www.umaxica.com",
      "ACME_STAFF_URL" => "www.umaxica.org",
      "SIGN_SERVICE_URL" => "id.umaxica.app",
      "SIGN_CORPORATE_URL" => "id.umaxica.com",
      "SIGN_STAFF_URL" => "id.umaxica.org",
      "CORE_SERVICE_URL" => "jpx.umaxica.app",
      "CORE_CORPORATE_URL" => "jpx.umaxica.com",
      "CORE_STAFF_URL" => "jpx.umaxica.org",
      "BASE_SERVICE_URL" => "www-jp.umaxica.app",
      "BASE_CORPORATE_URL" => "www-jp.umaxica.com",
      "BASE_STAFF_URL" => "www-jp.umaxica.org",
      "PALM_SERVICE_URL" => "palm-jp.umaxica.app",
      "PALM_CORPORATE_URL" => "palm-jp.umaxica.com",
      "PALM_STAFF_URL" => "palm-jp.umaxica.org",
      "HELP_SERVICE_URL" => "help.jp.umaxica.app",
      "HELP_CORPORATE_URL" => "help.jp.umaxica.com",
      "HELP_STAFF_URL" => "help.jp.umaxica.org",
      "JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
    }

    config = AppConfigLoader.load!(env: env, rails_env: ActiveSupport::EnvironmentInquirer.new("production"))
    hosts = config.fetch(:hosts)

    assert_equal ["jpx.umaxica.app", "jpx.umaxica.com", "jpx.umaxica.org"], hosts.core_origins.map(&:host)
    assert_equal ["www-jp.umaxica.app", "www-jp.umaxica.com", "www-jp.umaxica.org"], hosts.base_origins.map(&:host)
    assert_equal ["palm-jp.umaxica.app", "palm-jp.umaxica.com", "palm-jp.umaxica.org"], hosts.palm_origins.map(&:host)
  end

  test "raises on missing production critical host env" do
    env = {}

    error =
      assert_raises(KeyError) do
        AppConfigLoader.load!(env: env, rails_env: ActiveSupport::EnvironmentInquirer.new("production"))
      end

    assert_match(/ACME_SERVICE_URL/, error.message)
    assert_no_match(/https:\/\//, error.message)
  end
end
