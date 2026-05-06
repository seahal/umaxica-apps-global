# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_chronicle_events
# Database name: chronicle
#
#  id :bigint           not null, primary key
#

require "test_helper"

class UserChronicleEventTest < ActiveSupport::TestCase
  setup do
    @model_class = UserChronicleEvent
    @valid_id = UserChronicleEvent::LOGGED_IN
    @subject = @model_class.new(id: @valid_id)
  end

  test "accepts integer ids" do
    record = UserChronicleEvent.new(id: 9)

    assert_predicate record, :valid?
  end

  test "constants are grouped and defined" do
    assert_equal [
      UserChronicleEvent::ACCOUNT_RECOVERED,
      UserChronicleEvent::ACCOUNT_WITHDRAWN,
      UserChronicleEvent::AUTHORIZATION_FAILED,
      UserChronicleEvent::LOGGED_IN,
      UserChronicleEvent::LOGGED_OUT,
      UserChronicleEvent::LOGIN_FAILED,
      UserChronicleEvent::LOGIN_SUCCESS,
      UserChronicleEvent::LOGOUT,
      UserChronicleEvent::NOTHING,
      UserChronicleEvent::NON_EXISTENT_EVENT,
      UserChronicleEvent::PASSKEY_REGISTERED,
      UserChronicleEvent::PASSKEY_REMOVED,
      UserChronicleEvent::RECOVERY_CODES_GENERATED,
      UserChronicleEvent::RECOVERY_CODE_USED,
      UserChronicleEvent::SIGNED_UP_WITH_APPLE,
      UserChronicleEvent::SIGNED_UP_WITH_EMAIL,
      UserChronicleEvent::SIGNED_UP_WITH_GOOGLE,
      UserChronicleEvent::SIGNED_UP_WITH_TELEPHONE,
      UserChronicleEvent::TOKEN_REFRESHED,
      UserChronicleEvent::TOTP_DISABLED,
      UserChronicleEvent::TOTP_ENABLED,
      UserChronicleEvent::USER_SECRET_CREATED,
      UserChronicleEvent::USER_SECRET_REMOVED,
      UserChronicleEvent::USER_SECRET_UPDATED,
      UserChronicleEvent::EMAIL_REMOVED,
      UserChronicleEvent::TELEPHONE_REMOVED,
      UserChronicleEvent::SOCIAL_UNLINKED,
      UserChronicleEvent::STEP_UP_VERIFIED,
    ], UserChronicleEvent::DEFAULTS.sort
  end

  test "record_timestamps is disabled" do
    assert_not UserChronicleEvent.record_timestamps
  end

  test "DEFAULTS array contains all event IDs" do
    assert_kind_of Array, UserChronicleEvent::DEFAULTS
    assert_equal 28, UserChronicleEvent::DEFAULTS.size
    assert_includes UserChronicleEvent::DEFAULTS, UserChronicleEvent::LOGGED_IN
    assert_includes UserChronicleEvent::DEFAULTS, UserChronicleEvent::LOGIN_SUCCESS
    assert_includes UserChronicleEvent::DEFAULTS, UserChronicleEvent::TOKEN_REFRESHED
  end

  test "ensure_defaults! creates records" do
    UserChronicleEvent.delete_all
    assert_difference("UserChronicleEvent.count", 28) do
      UserChronicleEvent.ensure_defaults!
    end
    assert UserChronicleEvent.exists?(id: UserChronicleEvent::LOGGED_IN)
  end

  test "returns all default records" do
    UserChronicleEvent.ensure_defaults!
    ids = UserChronicleEvent.pluck(:id)

    assert_empty(UserChronicleEvent::DEFAULTS - ids)
  end

  test "has_many association with user_chronicles" do
    association = UserChronicleEvent.reflect_on_association(:user_chronicles)

    assert_equal :has_many, association.macro
    assert_equal :restrict_with_error, association.options[:dependent]
    assert_equal :event_id, association.options[:foreign_key]
  end
end
