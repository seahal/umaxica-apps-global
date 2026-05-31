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

  test "fixtures verify foreign key integrity" do
    assert_predicate ActiveRecord, :verify_foreign_keys_for_fixtures
  end
end
