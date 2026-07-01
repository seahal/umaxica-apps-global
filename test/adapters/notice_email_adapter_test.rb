# typed: false
# frozen_string_literal: true

require "test_helper"

class NoticeEmailAdapterTest < ActiveSupport::TestCase
  test "deliver queues notice mail via the injected mailer" do
    calls = []
    fake_mail = Object.new
    fake_mail.define_singleton_method(:deliver_later) { calls << :delivered }

    fake_message = Object.new
    fake_message.define_singleton_method(:notice) { fake_mail }

    fake_mailer = Object.new
    fake_mailer.define_singleton_method(:with) do |**kwargs|
      calls << kwargs
      fake_message
    end

    adapter = NoticeEmailAdapter.new(fake_mailer)
    adapter.deliver(email_address: "user@example.com", title: "Title", body: "Body")

    assert_equal({ email_address: "user@example.com", title: "Title", body: "Body" }, calls.first)
    assert_includes calls, :delivered
  end
end
