# frozen_string_literal: true

require "test_helper"

class FailFastEnvironmentConfigTest < ActiveSupport::TestCase
  fixtures_none!

  test "missing translations raise strictly in test" do
    assert_equal :strict, Rails.application.config.i18n.raise_on_missing_translations
    assert_raises(I18n::MissingTranslationData) do
      I18n.t!("test.missing_translation_for_fail_fast_config")
    end
  end

  test "test postgres options do not disable sequential scans" do
    assert_no_match(/enable_seqscan=off/, ENV.fetch("PGOPTIONS", ""))
  end

  test "fixtures do not run foreign key validation in test" do
    assert_not_predicate ActiveRecord, :verify_foreign_keys_for_fixtures
  end

  test "trusted proxies config parses valid cidr entries" do
    proxies = Jit::TrustedProxiesConfig.parse("10.0.0.0/8")

    assert_equal [IPAddr.new("10.0.0.0/8")], proxies
  end

  test "trusted proxies config parses multiple entries" do
    proxies = Jit::TrustedProxiesConfig.parse("10.0.0.0/8, 192.0.2.10,2001:db8::/32")

    assert_equal [
      IPAddr.new("10.0.0.0/8"),
      IPAddr.new("192.0.2.10"),
      IPAddr.new("2001:db8::/32"),
    ], proxies
  end

  test "trusted proxies config raises for invalid entries" do
    error =
      assert_raises(ArgumentError) do
        Jit::TrustedProxiesConfig.parse("10.0.0.0/8,not-a-cidr")
      end

    assert_includes error.message, 'Invalid TRUSTED_PROXIES entry: "not-a-cidr"'
  end

  test "trusted proxies config keeps blank and unset values empty" do
    assert_empty Jit::TrustedProxiesConfig.parse(nil)
    assert_empty Jit::TrustedProxiesConfig.parse("")
    assert_empty Jit::TrustedProxiesConfig.parse(" , ")
  end
end
