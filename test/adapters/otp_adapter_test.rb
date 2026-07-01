# typed: false
# frozen_string_literal: true

require "test_helper"

class OtpAdapterTest < ActiveSupport::TestCase
  test "for returns OtpEmailAdapter with App mailer for app/email" do
    adapter = OtpAdapter.for(surface: :app, channel: :email)

    assert_instance_of OtpEmailAdapter, adapter
    assert_same Email::App::OtpMailer, adapter.instance_variable_get(:@mailer)
  end

  test "for returns OtpEmailAdapter with Com mailer for com/email" do
    adapter = OtpAdapter.for(surface: :com, channel: :email)

    assert_instance_of OtpEmailAdapter, adapter
    assert_same Email::Com::OtpMailer, adapter.instance_variable_get(:@mailer)
  end

  test "for returns OtpEmailAdapter with Org mailer for org/email" do
    adapter = OtpAdapter.for(surface: :org, channel: :email)

    assert_instance_of OtpEmailAdapter, adapter
    assert_same Email::Org::OtpMailer, adapter.instance_variable_get(:@mailer)
  end

  test "for returns OtpTelephoneAdapter for app/telephone" do
    adapter = OtpAdapter.for(surface: :app, channel: :telephone)

    assert_instance_of OtpTelephoneAdapter, adapter
  end

  test "for returns OtpTelephoneAdapter for com/telephone" do
    adapter = OtpAdapter.for(surface: :com, channel: :telephone)

    assert_instance_of OtpTelephoneAdapter, adapter
  end

  test "for returns OtpTelephoneAdapter for org/telephone" do
    adapter = OtpAdapter.for(surface: :org, channel: :telephone)

    assert_instance_of OtpTelephoneAdapter, adapter
  end

  test "for accepts string surface and channel" do
    adapter = OtpAdapter.for(surface: "app", channel: "email")

    assert_instance_of OtpEmailAdapter, adapter
  end

  test "for raises ArgumentError for unknown combination" do
    assert_raises(ArgumentError) { OtpAdapter.for(surface: :side, channel: :email) }
  end

  test "base deliver raises NotImplementedError" do
    assert_raises(NotImplementedError) { OtpAdapter.new.deliver }
  end
end
