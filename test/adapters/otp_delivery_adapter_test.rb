# typed: false
# frozen_string_literal: true

require "test_helper"

class OtpDeliveryAdapterTest < ActiveSupport::TestCase
  test "for returns OtpEmailDeliveryAdapter with App mailer for app/email" do
    adapter = OtpDeliveryAdapter.for(surface: :app, channel: :email)

    assert_instance_of OtpEmailDeliveryAdapter, adapter
  end

  test "for returns OtpEmailDeliveryAdapter with Com mailer for com/email" do
    adapter = OtpDeliveryAdapter.for(surface: :com, channel: :email)

    assert_instance_of OtpEmailDeliveryAdapter, adapter
  end

  test "for returns OtpEmailDeliveryAdapter with Org mailer for org/email" do
    adapter = OtpDeliveryAdapter.for(surface: :org, channel: :email)

    assert_instance_of OtpEmailDeliveryAdapter, adapter
  end

  test "for returns OtpTelephoneDeliveryAdapter for app/telephone" do
    adapter = OtpDeliveryAdapter.for(surface: :app, channel: :telephone)

    assert_instance_of OtpTelephoneDeliveryAdapter, adapter
  end

  test "for returns OtpTelephoneDeliveryAdapter for com/telephone" do
    adapter = OtpDeliveryAdapter.for(surface: :com, channel: :telephone)

    assert_instance_of OtpTelephoneDeliveryAdapter, adapter
  end

  test "for accepts string surface and channel" do
    adapter = OtpDeliveryAdapter.for(surface: "app", channel: "email")

    assert_instance_of OtpEmailDeliveryAdapter, adapter
  end

  test "for raises ArgumentError for unknown combination" do
    assert_raises(ArgumentError) { OtpDeliveryAdapter.for(surface: :org, channel: :telephone) }
  end

  test "base deliver raises NotImplementedError" do
    assert_raises(NotImplementedError) { OtpDeliveryAdapter.new.deliver }
  end
end
