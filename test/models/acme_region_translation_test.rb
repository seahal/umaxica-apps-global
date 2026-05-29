# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeRegionTranslationTest < ActiveSupport::TestCase
  DOMAINS = %w(app com org).freeze

  def test_ja_region_selector_has_us_and_jp
    DOMAINS.each do |domain|
      locale_prefix = "acme.#{domain}.preferences.regions.select_region_selector"
      us_key = [locale_prefix, "US"].join(".")
      jp_key = [locale_prefix, "JP"].join(".")

      assert_equal "US — あめりかがっしゅうこく", I18n.t(us_key, locale: :ja)
      assert_equal "JP — にほん", I18n.t(jp_key, locale: :ja)
    end
  end

  def test_en_region_selector_keys_exist
    DOMAINS.each do |domain|
      locale_prefix = "acme.#{domain}.preferences.regions.select_region_selector"

      assert I18n.exists?("#{locale_prefix}.US", :en), "missing #{locale_prefix}.US for :en"
      assert I18n.exists?("#{locale_prefix}.JP", :en), "missing #{locale_prefix}.JP for :en"
    end
  end
end
