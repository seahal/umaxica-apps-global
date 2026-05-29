# typed: false
# frozen_string_literal: true

require "test_helper"

class PromotionalEmailUnsubscribableTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_email_statuses

  setup do
    @user = clients(:none_user)
  end

  test "generates token with the record unsubscribe scope" do
    email = ClientEmail.new(public_id: "client_email_public_id")

    Rails.app.creds.stub(:option, "unsubscribe-secret") do
      token = email.promotional_unsubscribe_token

      assert_equal PromotionalEmailUnsubscribeToken.generate(email, scope: :client), token
      assert email.valid_promotional_unsubscribe_token?(token)
    end
  end

  test "rejects malformed promotional unsubscribe token" do
    email = ClientEmail.new(public_id: "client_email_public_id")

    Rails.app.creds.stub(:option, "unsubscribe-secret") do
      assert_not email.valid_promotional_unsubscribe_token?("not-a-token")
    end
  end

  test "unsubscribe promotional persists opt out" do
    email = ClientEmail.create!(
      user: @user,
      address: "unsubscribe-#{SecureRandom.hex(4)}@example.com",
      confirm_policy: true,
      promotional: true,
    )

    email.unsubscribe_promotional!

    assert_not email.reload.promotional
  end
end
