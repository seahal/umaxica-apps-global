# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class RedirectTest < ActiveSupport::TestCase
  class RedirectHarness
    include CommonRedirect

    attr_reader :redirect_target, :redirect_options, :render_options, :logged_result

    def redirect_to(target = nil, **options)
      @redirect_target = target
      @redirect_options = options
    end

    def render(**options)
      @render_options = options
    end

    def log_redirect_target_failure(result)
      @logged_result = result
    end

    def params
      { ri: "return-id" }
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

  test "redirect target resolvers expose success and failure outcomes" do
    success = RedirectsTargetResult.ok(kind: :internal, source: :test, value: "/dashboard")
    failure = RedirectsTargetResult.failure(
      kind: :internal, source: :test, reason: :invalid, unsafe_value: "bad",
    )

    RedirectsPathTargetResolver.stub(:call, success) do
      @harness.send(:redirect_to_pt, default: "/fallback", pt: "/dashboard", status: :see_other)
    end

    assert_equal "/dashboard", @harness.redirect_target
    assert_equal :see_other, @harness.redirect_options[:status]

    RedirectsNavigationTargetResolver.stub(:call, failure) do
      @harness.send(:redirect_to_nt, :unknown)
    end

    assert_same failure, @harness.logged_result
    assert_equal :unprocessable_content, @harness.render_options[:status]

    RedirectsExternalTargetResolver.stub(:call, failure) do
      @harness.send(:redirect_to_external_jump, :unknown)
    end

    assert_equal :unprocessable_content, @harness.render_options[:status]

    RedirectsExternalTargetResolver.stub(:url, failure) do
      @harness.send(:redirect_to_external_jump_url, "https://outside.example", allowed_urls: [])
    end

    assert_equal :unprocessable_content, @harness.render_options[:status]
  end

  test "safe return helpers handle malformed URLs ports and encoded paths" do
    assert_nil @harness.send(:safe_return_path, "http://[")
    assert_equal "example.com:8443",
                 @harness.send(:normalized_host_with_optional_port, "https://example.com:8443")
    assert_nil @harness.send(:normalized_host_with_optional_port, "http://[")
    assert_equal "example.com:8443",
                 @harness.send(:host_with_optional_port, URI.parse("https://example.com:8443/path"))

    encoded = Base64.urlsafe_encode64("/dashboard", padding: false)
    @harness.send(:jump_to_generated_url, encoded, fallback: "/fallback")

    assert_equal "/dashboard", @harness.redirect_target

    @harness.send(:jump_to_generated_url, "%%%", fallback: "/fallback")

    assert_equal "/fallback", @harness.redirect_target
  end

  test "redirect context prefers an explicitly declared controller surface" do
    assert_equal({ ri: "return-id", surface: "app" }, @harness.send(:redirect_target_context_params))

    @harness.define_singleton_method(:surface_from_controller_name) { "org" }

    assert_equal "org", @harness.send(:redirect_target_surface)
  end

  test "safe jump query keys reject malformed URLs" do
    assert_empty @harness.send(:safe_jump_preserved_query_keys, "http://[")
  end

  test "redirect target resolution returns and logs resolver failures" do
    failure = RedirectsTargetResult.failure(
      kind: :internal, source: :test, reason: :invalid, unsafe_value: "bad",
    )

    result =
      RedirectsPriorityResolver.stub(:call, failure) do
        @harness.send(:resolve_redirect_target, priority: [:ri], default: "/fallback")
      end

    assert_same failure, result
    assert_same failure, @harness.logged_result
  end
end
