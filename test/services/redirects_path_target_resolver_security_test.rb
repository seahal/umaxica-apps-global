# typed: false
# frozen_string_literal: true

require "test_helper"

class RedirectsPathTargetResolverSecurityTest < ActiveSupport::TestCase
  test "rejects redirect fuzz payloads without issuing path-target tokens" do
    [
      "https://evil.example",
      "//evil.example",
      "https://app.example.com.evil.example/path",
      "https://evil.example/@app.example.com",
      "/%2f%2fevil.example",
      "/\\evil.example",
      "/%5c%5cevil.example",
      "/auth/logout?return_to=https://evil.example",
      "/auth/step_up?return_to=https://evil.example",
    ].each do |payload|
      result = RedirectsPathTargetResolver.call(payload, source: :security_fuzz)

      assert_not_predicate result, :ok?, payload
      assert_predicate result.unsafe_value_digest, :present?, payload
      assert_not_equal payload, result.unsafe_value_digest
    end
  end

  test "keeps internal organization paths syntactically internal for later authorization gates" do
    [
      "/org/123/settings",
      "/org/999/settings",
    ].each do |payload|
      result = RedirectsPathTargetResolver.call(payload, source: :security_fuzz)

      assert_predicate result, :ok?, payload
      assert_equal payload, result.value
    end
  end

  test "redirect rejection has a durable event name at authentication pt call sites" do
    source = Rails.root.join("app/controllers/concerns/authentication_redirects.rb").read

    assert_includes source, "path_target.rejected"
    assert_includes source, "log_signed_target_rejection"
  end
end
