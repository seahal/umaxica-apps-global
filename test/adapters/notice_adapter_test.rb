# typed: false
# frozen_string_literal: true

require "test_helper"

class NoticeAdapterTest < ActiveSupport::TestCase
  test "for returns email adapters per surface" do
    app_adapter = NoticeAdapter.for(surface: :app, channel: :email)
    com_adapter = NoticeAdapter.for(surface: :com, channel: :email)
    org_adapter = NoticeAdapter.for(surface: :org, channel: :email)

    assert_instance_of NoticeEmailAdapter, app_adapter
    assert_same Email::App::AlertMailer, app_adapter.instance_variable_get(:@mailer)
    assert_instance_of NoticeEmailAdapter, com_adapter
    assert_same Email::Com::AlertMailer, com_adapter.instance_variable_get(:@mailer)
    assert_instance_of NoticeEmailAdapter, org_adapter
    assert_same Email::Org::AlertMailer, org_adapter.instance_variable_get(:@mailer)
  end

  test "for accepts string surface and channel" do
    adapter = NoticeAdapter.for(surface: "app", channel: "email")

    assert_instance_of NoticeEmailAdapter, adapter
  end

  test "for raises ArgumentError for unknown combination" do
    assert_raises(ArgumentError) { NoticeAdapter.for(surface: :app, channel: :telephone) }
  end

  test "base deliver raises NotImplementedError" do
    assert_raises(NotImplementedError) { NoticeAdapter.new.deliver }
  end
end
