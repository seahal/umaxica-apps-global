# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuth::UidExtractorTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "extracts uid from auth_hash top-level uid string key" do
    auth_hash = { "uid" => "1234567890" }
    result = SocialAuth::UidExtractor.call(auth_hash: auth_hash)

    assert_equal "1234567890", result
  end

  test "extracts uid from auth_hash top-level uid symbol key" do
    auth_hash = { uid: "abc123" }
    result = SocialAuth::UidExtractor.call(auth_hash: auth_hash)

    assert_equal "abc123", result
  end

  test "prefers top-level uid over nested sub" do
    auth_hash = { "uid" => "primary_uid", "extra" => { "raw_info" => { "sub" => "nested_uid" } } }
    result = SocialAuth::UidExtractor.call(auth_hash: auth_hash)

    assert_equal "primary_uid", result
  end

  test "falls back to raw_info sub when top-level uid is blank" do
    auth_hash = { "uid" => "", "extra" => { "raw_info" => { "sub" => "raw_sub_value" } } }
    result = SocialAuth::UidExtractor.call(auth_hash: auth_hash)

    assert_equal "raw_sub_value", result
  end

  test "falls back to id_info sub when uid and raw_info are blank" do
    auth_hash = { "extra" => { "id_info" => { "sub" => "id_info_sub" } } }
    result = SocialAuth::UidExtractor.call(auth_hash: auth_hash)

    assert_equal "id_info_sub", result
  end

  test "falls back through all candidates in order" do
    auth_hash = { "uid" => nil, "extra" => { "raw_info" => {}, "id_info" => { "sub" => "fallback_sub" } } }
    result = SocialAuth::UidExtractor.call(auth_hash: auth_hash)

    assert_equal "fallback_sub", result
  end

  test "converts numeric uid to string" do
    auth_hash = { "uid" => 42 }
    result = SocialAuth::UidExtractor.call(auth_hash: auth_hash)

    assert_equal "42", result
  end

  test "raises ProviderError when all uid candidates are blank" do
    auth_hash = { "uid" => nil }
    error =
      assert_raises(SocialAuth::ProviderError) do
        SocialAuth::UidExtractor.call(auth_hash: auth_hash)
      end

    assert_equal "errors.social_auth.missing_uid", error.i18n_key
  end

  test "raises ProviderError when auth_hash is empty" do
    assert_raises(SocialAuth::ProviderError) do
      SocialAuth::UidExtractor.call(auth_hash: {})
    end
  end

  test "raises ProviderError when all nested subs are nil" do
    auth_hash = { "extra" => { "raw_info" => nil, "id_info" => nil } }
    assert_raises(SocialAuth::ProviderError) do
      SocialAuth::UidExtractor.call(auth_hash: auth_hash)
    end
  end

  test "handles symbol-keyed extra hash" do
    auth_hash = { extra: { raw_info: { "sub" => "sym_sub" } } }
    result = SocialAuth::UidExtractor.call(auth_hash: auth_hash)

    assert_equal "sym_sub", result
  end
end
