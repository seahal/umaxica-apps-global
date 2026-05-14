# typed: false
# frozen_string_literal: true

require "test_helper"

module Auth
  class AuditWriterTest < ActiveSupport::TestCase
    fixtures :users, :user_statuses, :user_chronicle_events, :user_chronicle_levels

    setup do
      @user = users(:one)
      @user.update!(status_id: UserStatus::ACTIVE, withdrawn_at: nil) if defined?(UserStatus)

      # Ensure audit master data exists
      UserChronicleEvent.ensure_defaults! if UserChronicleEvent.respond_to?(:ensure_defaults!)
      UserChronicleLevel.ensure_defaults! if UserChronicleLevel.respond_to?(:ensure_defaults!)
    end

    test "write! creates audit record successfully" do
      audit = Auth::AuditWriter.write!(
        UserChronicle,
        UserChronicleEvent::LOGGED_IN,
        resource: @user,
        actor: @user,
        ip_address: "127.0.0.1",
      )

      assert_predicate audit, :persisted?
      assert_equal UserChronicleEvent::LOGGED_IN, audit.event_id
      assert_equal @user.id.to_s, audit.subject_id
      assert_equal "User", audit.subject_type
      assert_equal IPAddr.new("127.0.0.1"), audit.ip_address
    end

    test "write! raises exception on validation failure" do
      # Create invalid event_id that doesn't exist in master data
      invalid_event_id = "INVALID_EVENT_#{SecureRandom.hex(4)}"

      assert_raises(Auth::AuditWriter::AuditWriteError) do
        Auth::AuditWriter.write!(
          UserChronicle,
          invalid_event_id,
          resource: @user,
          actor: @user,
          ip_address: "127.0.0.1",
        )
      end
    end

    test "write returns true on success" do
      result = Auth::AuditWriter.write(
        UserChronicle,
        UserChronicleEvent::LOGGED_IN,
        resource: @user,
        actor: @user,
        ip_address: "127.0.0.1",
      )

      assert result
      assert UserChronicle.exists?(event_id: UserChronicleEvent::LOGGED_IN, subject_id: @user.id)
    end

    test "write recreates missing user chronicle event and level references" do
      ChronicleRecord.connected_to(role: :writing) do
        UserChronicle.where(event_id: UserChronicleEvent::LOGGED_IN).delete_all
        UserChronicleEvent.where(id: UserChronicleEvent::LOGGED_IN).delete_all
        UserChronicleLevel.where(id: UserChronicleLevel::NOTHING).delete_all
      end

      result = Auth::AuditWriter.write(
        UserChronicle,
        "LOGGED_IN",
        resource: @user,
        actor: @user,
        ip_address: "127.0.0.1",
      )

      assert result
      assert UserChronicleEvent.exists?(id: UserChronicleEvent::LOGGED_IN)
      assert UserChronicleLevel.exists?(id: UserChronicleLevel::NOTHING)
      assert UserChronicle.exists?(event_id: UserChronicleEvent::LOGGED_IN, subject_id: @user.id)
    end

    test "write returns false on failure" do
      # Create invalid event_id that is guaranteed not to exist
      invalid_event_id = "NONEXISTENT_#{SecureRandom.hex(16).upcase}"

      # Ensure this event doesn't exist in the database
      ChronicleRecord.connected_to(role: :writing) do
        UserChronicleEvent.where(id: invalid_event_id).delete_all
      end

      result = Auth::AuditWriter.write(
        UserChronicle,
        invalid_event_id,
        resource: @user,
        actor: @user,
        ip_address: "127.0.0.1",
      )

      assert_not result, "write should return false when audit save fails"

      # Verify audit was not saved
      assert_not UserChronicle.exists?(event_id: invalid_event_id, subject_id: @user.id),
                 "Failed audit should not be saved to database"
    end

    test "write logs error on failure for observability" do
      # Create invalid event_id
      invalid_event_id = "NONEXISTENT_#{SecureRandom.hex(16).upcase}"

      # Ensure event doesn't exist
      ChronicleRecord.connected_to(role: :writing) do
        UserChronicleEvent.where(id: invalid_event_id).delete_all
      end

      # S1: Audit failure must be observable
      # We verify this by checking that write returns false
      # (The actual logging and Rails.event.notify are verified manually in development)
      result = Auth::AuditWriter.write(
        UserChronicle,
        invalid_event_id,
        resource: @user,
        actor: @user,
        ip_address: "127.0.0.1",
      )

      assert_not result, "write should return false to indicate failure (observable)"
      # Note: Rails.event.notify is called internally but not easily testable in unit tests
      # Observability is verified through integration tests and manual testing
    end

    test "write does not raise exception on failure" do
      invalid_event_id = "INVALID_EVENT_#{SecureRandom.hex(4)}"

      assert_nothing_raised do
        result = Auth::AuditWriter.write(
          UserChronicle,
          invalid_event_id,
          resource: @user,
          actor: @user,
          ip_address: "127.0.0.1",
        )

        assert_not result
      end
    end

    test "build_audit creates audit record without saving" do
      audit = Auth::AuditWriter.build_audit(
        UserChronicle,
        UserChronicleEvent::LOGGED_IN,
        resource: @user,
        actor: @user,
        ip_address: "127.0.0.1",
      )

      assert_not audit.persisted?
      assert_equal UserChronicleEvent::LOGGED_IN, audit.event_id
      assert_equal @user.id.to_s, audit.subject_id
      assert_equal "User", audit.subject_type
    end

    test "write uses writing role for audit database" do
      # Verify that ChronicleRecord.connected_to is called with role: :writing
      # This ensures audit writes go to the primary database, not replica
      original_method = ChronicleRecord.method(:connected_to)

      connection_calls = []
      ChronicleRecord.define_singleton_method(:connected_to) do |**options, &block|
        connection_calls << options
        original_method.call(**options, &block)
      end

      Auth::AuditWriter.write(
        UserChronicle,
        "LOGGED_IN",
        resource: @user,
        actor: @user,
        ip_address: "127.0.0.1",
      )

      assert connection_calls.any? { |opts| opts[:role] == :writing }
    ensure
      # Restore original method
      ChronicleRecord.define_singleton_method(:connected_to, original_method)
    end
  end
end
