# typed: false
# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/app_config_loader").to_s

class AppConfigLoaderTest < ActiveSupport::TestCase
  test "loads localhost defaults in test" do
    env = {}

    config = AppConfigLoader.load!(env: env, rails_env: ActiveSupport::EnvironmentInquirer.new("test"))

    assert_equal "www.app.localhost", config.fetch(:hosts).acme_service.host
    assert_equal "id.app.localhost", config.fetch(:hosts).sign_service.host
    assert_equal "help.app.localhost", config.fetch(:hosts).help_service.host
    assert_equal "https://jump.umaxica.net", config.fetch(:jump).origin.to_s
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
