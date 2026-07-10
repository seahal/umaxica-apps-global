# typed: false
# frozen_string_literal: true

require "test_helper"

class PromotionEmailAdapterTest < ActiveSupport::TestCase
  test "deliver queues promotional mail via the injected mailer" do
    calls = []
    email_record = Object.new
    fake_mail = Object.new
    fake_mail.define_singleton_method(:deliver_later) { calls << :delivered }

    fake_message = Object.new
    fake_message.define_singleton_method(:notice) { fake_mail }

    fake_mailer = Object.new
    fake_mailer.define_singleton_method(:with) do |**kwargs|
      calls << kwargs
      fake_message
    end

    adapter = PromotionEmailAdapter.new(fake_mailer)
    adapter.deliver(
      email_address: "user@example.com",
      title: "Title",
      body: "Body",
      cta_url: "https://example.com/campaign",
      email_record: email_record,
    )

    assert_equal(
      {
        email_address: "user@example.com",
        title: "Title",
        body: "Body",
        cta_url: "https://example.com/campaign",
        email_record: email_record,
      },
      calls.first,
    )
    assert_includes calls, :delivered
  end
end
