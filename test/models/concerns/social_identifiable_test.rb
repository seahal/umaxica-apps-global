# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialIdentifiableTest < ActiveSupport::TestCase
  test "normalizes provider strategy names without deciding authorization" do
    assert_equal "google", SocialIdentifiable.normalize_provider("google_app")
    assert_equal "google", SocialIdentifiable.normalize_provider("google_oauth2")
    assert_equal "apple", SocialIdentifiable.normalize_provider("APPLE")
  end

  test "preserves unknown provider names for the provider registry to reject" do
    assert_equal "google_org", SocialIdentifiable.normalize_provider("google_org")
    assert_equal "microsoft_graph", SocialIdentifiable.normalize_provider("MICROSOFT_GRAPH")
    assert_equal "custom", SocialIdentifiable.normalize_provider("CUSTOM")
  end
end
