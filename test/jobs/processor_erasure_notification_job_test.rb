# frozen_string_literal: true

require "test_helper"

class ProcessorErasureNotificationJobTest < ActiveJob::TestCase
  self.fixture_table_names = []

  test "job marks client notification notified and records occurrence" do
    client = create_client
    privacy_request = ClientPrivacyRequest.create!(client: client)
    notification = ClientProcessorErasureNotification.create!(
      client_privacy_request: privacy_request,
      processor_key: "email_delivery",
    )

    ProcessorErasureNotificationJob.perform_now(surface: "app", public_id: notification.public_id)

    assert_equal ClientProcessorErasureNotification.status_id_for("NOTIFIED"), notification.reload.status_id
    assert_predicate ClientOccurrence.where(event_type: "processor_erasure.notified"), :exists?
  end

  test "job is idempotent for notified visitor notification" do
    visitor = create_visitor
    privacy_request = VisitorPrivacyRequest.create!(visitor: visitor)
    notification = VisitorProcessorErasureNotification.create!(
      visitor_privacy_request: privacy_request,
      processor_key: "email_delivery",
      status_id: VisitorProcessorErasureNotification.status_id_for("NOTIFIED"),
      notified_at: Time.current,
    )

    assert_no_difference -> { VisitorOccurrence.count } do
      ProcessorErasureNotificationJob.perform_now(surface: "com", public_id: notification.public_id)
    end

    assert_equal VisitorProcessorErasureNotification.status_id_for("NOTIFIED"), notification.reload.status_id
  end

  private

  def create_client
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    Client.create!(
      status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
      mfa_level_id: ClientMfaLevel::NOTHING,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
  end

  def create_visitor
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    Visitor.create!(
      status_id: VisitorStatus::NOTHING,
      visibility_id: VisitorVisibility::VISITOR,
      mfa_level_id: VisitorMfaLevel::NOTHING,
      mfa_status_id: VisitorMfaStatus::UNCONFIGURED,
    )
  end
end
