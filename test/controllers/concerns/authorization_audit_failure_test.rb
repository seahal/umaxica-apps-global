# typed: false
# frozen_string_literal: true

require "test_helper"

# An authorization failure is itself audited. If that audit row cannot be
# written -- most often because the event id has not been seeded on this
# database yet -- the request must still be answered, and the diagnostic that is
# logged must name the rejected attributes rather than quote their values, which
# would put the rejected input into the log unredacted.
class AuthorizationAuditFailureTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include AuthorizationAudit

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
    @log_data = { ip_address: "203.0.113.5", timestamp: Time.current }
  end

  def capture_info
    recorded = []
    Rails.logger.stub(:info, ->(*args, &block) { recorded << (args.first || block&.call).to_s }) { yield }
    recorded
  end

  test "an unwritable client audit row is reported by attribute name, not by value" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    invalid = ClientChronicle.new
    invalid.errors.add(:event_id, :blank)

    recorded =
      capture_info do
        ClientChronicle.stub(:new, ->(**) { raise ActiveRecord::RecordInvalid, invalid }) do
          @harness.invoke(:create_user_authorization_audit, client, @log_data)
        end
      end

    assert(recorded.any? { |line| line.include?("authorization.audit.user_creation_failed") })
    assert(recorded.any? { |line| line.include?("event_id") })
  end

  test "an unwritable operator audit row is reported under the staff event" do
    operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    invalid = OperatorChronicle.new
    invalid.errors.add(:event_id, :blank)

    recorded =
      capture_info do
        OperatorChronicle.stub(:new, ->(**) { raise ActiveRecord::RecordInvalid, invalid }) do
          @harness.invoke(:create_staff_authorization_audit, operator, @log_data)
        end
      end

    assert(recorded.any? { |line| line.include?("authorization.audit.staff_creation_failed") })
  end

  test "an unwritable visitor audit row is reported under the visitor event" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    invalid = ClientChronicle.new
    invalid.errors.add(:event_id, :blank)

    recorded =
      capture_info do
        ClientChronicle.stub(:new, ->(**) { raise ActiveRecord::RecordInvalid, invalid }) do
          @harness.invoke(:create_visitor_authorization_audit, visitor, @log_data)
        end
      end

    assert(recorded.any? { |line| line.include?("authorization.audit.visitor_creation_failed") })
  end
end
