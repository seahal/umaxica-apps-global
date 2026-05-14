# typed: false
# frozen_string_literal: true

module VisitorHelpers
  def ensure_visitor_reference_records!
    Prosopite.pause do
      [VisitorStatus::ACTIVE, VisitorStatus::NOTHING, VisitorStatus::RESERVED].each do |id|
        VisitorStatus.find_or_create_by!(id: id)
      end
      [VisitorVisibility::NOBODY, VisitorVisibility::VISITOR, VisitorVisibility::STAFF,
       VisitorVisibility::BOTH,].each do |id|
        VisitorVisibility.find_or_create_by!(id: id)
      end
      [1, 2, 3, 4, 5, 6, 7].each do |id|
        VisitorEmailStatus.find_or_create_by!(id: id)
        VisitorTelephoneStatus.find_or_create_by!(id: id)
      end
      [1, 2, 3, 4, 5].each do |id|
        VisitorPasskeyStatus.find_or_create_by!(id: id)
      end
      [1, 2, 3, 4].each do |id|
        VisitorSecretKind.find_or_create_by!(id: id)
      end
      [1, 2, 3, 4, 5, 6].each do |id|
        VisitorSecretStatus.find_or_create_by!(id: id)
      end
    end
  end

  def ensure_visitor_token_reference_records!
    Prosopite.pause do
      VisitorTokenBindingMethod.ensure_defaults!
      VisitorTokenDbscStatus.ensure_defaults!
      [VisitorTokenKind::BROWSER_WEB, VisitorTokenKind::CLIENT_IOS, VisitorTokenKind::CLIENT_ANDROID].each do |id|
        VisitorTokenKind.find_or_create_by!(id: id)
      end
      VisitorTokenStatus::DEFAULTS.each do |id|
        VisitorTokenStatus.find_or_create_by!(id: id)
      end
    end
  end

  def create_verified_visitor_with_email(email_address: "visitor@example.com", status: VisitorStatus::ACTIVE)
    ensure_visitor_reference_records!
    ensure_visitor_token_reference_records!
    visitor = Visitor.create!(status_id: status, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor: visitor,
      address: email_address,
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: "1",
    )
    visitor
  end
end

ActiveSupport.on_load(:active_support_test_case) { include VisitorHelpers }
