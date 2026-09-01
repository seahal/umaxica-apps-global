# typed: false
# frozen_string_literal: true

require "test_helper"

# The audit writer accepts an event by name and resolves it to the numeric id of
# the surface's own chronicle event table. The three preference chronicles each
# have their own table, so resolving against the wrong one writes a row that
# names a different event -- and the preference branches of that map had no
# coverage at all.
#
# The two notifier rescues exist so that a failure while recording a failure is
# swallowed rather than replacing the original error; both are pinned here.
class AuthenticationAuditWriterEventMapTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  {
    AppPreferenceChronicle => AppPreferenceChronicleEvent,
    ComPreferenceChronicle => ComPreferenceChronicleEvent,
    OrgPreferenceChronicle => OrgPreferenceChronicleEvent,
  }.each do |audit_class, event_class|
    test "#{audit_class} resolves preference event names against its own event table" do
      assert_equal event_class::REFRESH_TOKEN_ROTATED,
                   AuthenticationAuditWriter.send(:normalize_event_id, audit_class, "REFRESH_TOKEN_ROTATED")
      assert_equal event_class::CREATE_NEW_PREFERENCE_TOKEN,
                   AuthenticationAuditWriter.send(:normalize_event_id, audit_class, "CREATE_NEW_PREFERENCE_TOKEN")
      assert_equal event_class::RESET_BY_USER_DECISION,
                   AuthenticationAuditWriter.send(:normalize_event_id, audit_class, "RESET_BY_USER_DECISION")
    end
  end

  test "an unknown audit class resolves nothing and hands the name back unchanged" do
    assert_equal "LOGGED_IN", AuthenticationAuditWriter.send(:normalize_event_id, ChronicleOutboxEntry, "LOGGED_IN")
    assert_equal 7, AuthenticationAuditWriter.send(:normalize_event_id, ClientChronicle, 7)
  end

  test "a failure while notifying a failed write is swallowed rather than raised" do
    unavailable_logger = Object.new
    unavailable_logger.define_singleton_method(:info) { |*| raise IOError, "log sink unavailable" }

    Rails.stub(:logger, unavailable_logger) do
      assert_not AuthenticationAuditWriter.send(:notify_write_failed, { event: "x" })
    end
  end

  test "a failure while recording the structured fallback is swallowed rather than raised" do
    unusable = Object.new
    unusable.define_singleton_method(:id) { raise IOError, "subject unavailable" }

    assert_not AuthenticationAuditWriter.send(
      :record_structured_fallback,
      event_uuid: SecureRandom.uuid, event: "audit.outbox_unavailable", event_id: "LOGGED_IN",
      resource: unusable, actor: nil, error: RuntimeError.new("boom"),
      manual_recovery_required: true,
    )
  end
end
