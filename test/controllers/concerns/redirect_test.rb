# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class RedirectTest < ActiveSupport::TestCase
  class RedirectHarness
    include CommonRedirect

    attr_reader :redirect_target, :redirect_options

    def redirect_to(target = nil, **options)
      @redirect_target = target
      @redirect_options = options
    end
  end

  setup do
    @harness = RedirectHarness.new
  end

  test "safe_redirect_to allows absolute internal paths only" do
    @harness.send(:safe_redirect_to, "/dashboard?x=1", fallback: "/fallback", status: :found)

    assert_equal "/dashboard?x=1", @harness.redirect_target
    assert_not @harness.redirect_options[:allow_other_host]
    assert_equal :found, @harness.redirect_options[:status]
  end

  test "safe_redirect_to rejects absolute URL and falls back" do
    @harness.send(:safe_redirect_to, "https://app.localhost/dashboard", fallback: "/fallback")

    assert_equal "/fallback", @harness.redirect_target
    assert_not @harness.redirect_options[:allow_other_host]
  end

  test "safe_redirect_to rejects protocol-relative URL and falls back" do
    @harness.send(:safe_redirect_to, "//app.localhost/dashboard", fallback: "/fallback")

    assert_equal "/fallback", @harness.redirect_target
    assert_not @harness.redirect_options[:allow_other_host]
  end

  test "safe_redirect_to rejects path without leading slash and falls back" do
    @harness.send(:safe_redirect_to, "a/b", fallback: "/fallback")

    assert_equal "/fallback", @harness.redirect_target
    assert_not @harness.redirect_options[:allow_other_host]
  end

  test "safe_redirect_to rejects control characters and falls back" do
    @harness.send(:safe_redirect_to, "/dashboard\nx", fallback: "/fallback")

    assert_equal "/fallback", @harness.redirect_target
    assert_not @harness.redirect_options[:allow_other_host]
  end

  test "generate_redirect_url encodes internal paths only" do
    encoded = @harness.send(:generate_redirect_url, "/dashboard?x=1")

    assert_not_nil encoded
    assert_equal "/dashboard?x=1", Base64.urlsafe_decode64(encoded)
    assert_nil @harness.send(:generate_redirect_url, "https://app.localhost/dashboard")
  end
end
