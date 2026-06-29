# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PromotionalEmailUnsubscribeHeadersTest < ActiveSupport::TestCase
  class FakeMailer
    include PromotionalEmailUnsubscribeHeaders

    def headers
      @headers ||= {}
    end
  end

  setup do
    @mailer = FakeMailer.new
  end

  test "set_promotional_unsubscribe_headers sets List-Unsubscribe headers" do
    record = OpenStruct.new(
      promotional_unsubscribe_scope: :client,
      promotional_unsubscribe_token: "tok-123",
    )

    @mailer.send(:set_promotional_unsubscribe_headers, record)

    assert_predicate @mailer.headers["List-Unsubscribe"], :present?
    assert_equal "List-Unsubscribe=One-Click", @mailer.headers["List-Unsubscribe-Post"]
  end

  test "promotional_unsubscribe_edit_url returns edit route URL" do
    record = OpenStruct.new(
      promotional_unsubscribe_scope: :client,
      promotional_unsubscribe_token: "tok-edit",
    )

    url = @mailer.send(:promotional_unsubscribe_edit_url, record)

    assert_includes url, "tok-edit"
    assert_includes url, "edit"
  end
end
