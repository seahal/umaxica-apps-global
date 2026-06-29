# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class SafePromotionalCtaUrlTest < ActiveSupport::TestCase
  class FakeMailer
    include SafePromotionalCtaUrl
  end

  setup do
    @mailer = FakeMailer.new
  end

  test "returns nil for blank input" do
    assert_nil @mailer.send(:safe_promotional_cta_url, "")
    assert_nil @mailer.send(:safe_promotional_cta_url, "  ")
    assert_nil @mailer.send(:safe_promotional_cta_url, nil)
  end

  test "returns nil for input with control characters" do
    assert_nil @mailer.send(:safe_promotional_cta_url, "https://example.test/\x00null")
    assert_nil @mailer.send(:safe_promotional_cta_url, "https://example.test/\x1F")
  end

  test "returns nil for non-HTTP URI" do
    assert_nil @mailer.send(:safe_promotional_cta_url, "javascript:alert(1)")
    assert_nil @mailer.send(:safe_promotional_cta_url, "ftp://example.test/link")
  end

  test "returns nil for non-HTTPS scheme" do
    assert_nil @mailer.send(:safe_promotional_cta_url, "http://example.test/link")
  end

  test "returns nil for URL with userinfo" do
    assert_nil @mailer.send(:safe_promotional_cta_url, "https://user:pass@example.test/link")
  end

  test "returns nil for URL with blank host" do
    assert_nil @mailer.send(:safe_promotional_cta_url, "https:///path")
  end

  test "returns normalizes and returns valid HTTPS URL" do
    result = @mailer.send(:safe_promotional_cta_url, " HTTPS://EXAMPLE.TEST/PATH?q=1 ")

    assert_equal "https://example.test/PATH?q=1", result
  end

  test "handles URI::InvalidURIError by returning nil" do
    assert_nil @mailer.send(:safe_promotional_cta_url, "https://example.test/ invalid")
    assert_nil @mailer.send(:safe_promotional_cta_url, "https://\x00.test/link")
  end
end
