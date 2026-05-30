# typed: false
# frozen_string_literal: true

require "test_helper"

class SignUpSequenceControllerSupportTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include Sign::Up::SequenceControllerSupport
  end

  test "sign_up_pending_actor loads the matching client or visitor by id" do
    harness = Harness.new

    harness.instance_variable_set(:@sign_up_ticket, ClientSignUpFlow.new(principal_id: clients(:sample_user).id))

    assert_equal clients(:sample_user), harness.send(:sign_up_pending_actor)

    harness.instance_variable_set(
      :@sign_up_ticket,
      VisitorSignUpFlow.new(principal_id: visitors(:reserved_visitor).id),
    )

    assert_equal visitors(:reserved_visitor), harness.send(:sign_up_pending_actor)
  end

  test "sign_up_pending_telephone loads the matching client or visitor telephone by id" do
    client_telephone = ClientTelephone.create!(
      user: clients(:sample_user),
      raw_number: "+819012399991",
      confirm_policy: "1",
      confirm_using_mfa: "1",
    )
    visitor_telephone = VisitorTelephone.create!(
      visitor: visitors(:reserved_visitor),
      raw_number: "+819012399992",
      confirm_policy: "1",
      confirm_using_mfa: "1",
    )

    harness = Harness.new

    harness.instance_variable_set(
      :@sign_up_ticket,
      ClientSignUpFlow.new(pending_contact_id: client_telephone.id),
    )

    assert_equal client_telephone, harness.send(:sign_up_pending_telephone)

    harness.instance_variable_set(
      :@sign_up_ticket,
      VisitorSignUpFlow.new(pending_contact_id: visitor_telephone.id),
    )

    assert_equal visitor_telephone, harness.send(:sign_up_pending_telephone)
  end
end
