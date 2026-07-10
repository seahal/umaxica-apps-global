# typed: false
# frozen_string_literal: true

require "test_helper"

class PromotionAdapterTest < ActiveSupport::TestCase
  test "for returns email adapters per surface" do
    app_adapter = PromotionAdapter.for(surface: :app, channel: :email)
    com_adapter = PromotionAdapter.for(surface: :com, channel: :email)
    org_adapter = PromotionAdapter.for(surface: :org, channel: :email)

    assert_instance_of PromotionEmailAdapter, app_adapter
    assert_same Email::App::PromotionalMailer, app_adapter.instance_variable_get(:@mailer)
    assert_instance_of PromotionEmailAdapter, com_adapter
    assert_same Email::Com::PromotionalMailer, com_adapter.instance_variable_get(:@mailer)
    assert_instance_of PromotionEmailAdapter, org_adapter
    assert_same Email::Org::PromotionalMailer, org_adapter.instance_variable_get(:@mailer)
  end

  test "for accepts string surface and channel" do
    adapter = PromotionAdapter.for(surface: "app", channel: "email")

    assert_instance_of PromotionEmailAdapter, adapter
  end

  test "for raises ArgumentError for unknown combination" do
    assert_raises(ArgumentError) { PromotionAdapter.for(surface: :app, channel: :telephone) }
  end

  test "base deliver raises NotImplementedError" do
    assert_raises(NotImplementedError) { PromotionAdapter.new.deliver }
  end
end
