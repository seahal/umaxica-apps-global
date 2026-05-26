# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthorizationAuditTest < ActiveSupport::TestCase
  fixtures :clients, :operators, :client_statuses, :operator_identity_statuses

  class DummyPolicy
    attr_accessor :record

    def initialize(record: nil)
      @record = record
    end
  end

  class DummyAudit
    def self.rescue_from(*)
    end

    include AuthorizationAudit

    attr_accessor :current_user, :current_operator, :request, :action_name, :controller_name

    def initialize(current_user: nil, current_operator: nil)
      @current_user = current_user
      @current_operator = current_operator
      @action_name = "show"
      @controller_name = "widgets"
      @request = OpenStruct.new(remote_ip: "127.0.0.1", user_agent: "TestAgent")
      @flash = {}
    end

    attr_reader :redirected_to, :rendered

    def flash
      @flash
    end

    def redirect_back_or_to(path)
      @redirected_to = path
    end

    def redirect_to(path, **_options)
      @redirected_to = path
    end

    def root_path
      "/"
    end

    def render(options)
      @rendered = options
    end

    def respond_to
      format = OpenStruct.new

      # Mock html format handler
      def format.html
        yield
      end

      # Mock json format handler
      def format.json
        yield
      end

      yield format
    end
  end

  test "current_user_or_staff prefers current_user" do
    user = clients(:one)
    staff = operators(:one)
    audit = DummyAudit.new(current_user: user, current_operator: staff)

    assert_equal user, audit.send(:current_user_or_staff)
  end

  test "current_user_or_staff falls back to current_operator" do
    staff = operators(:one)
    audit = DummyAudit.new(current_user: nil, current_operator: staff)

    assert_equal staff, audit.send(:current_user_or_staff)
  end

  test "log_authorization_failure notifies once" do
    user = clients(:one)
    exception = build_exception(record: clients(:two))
    audit = DummyAudit.new(current_user: user)

    result = capture_log_data(audit, exception)

    assert_equal ["authorization.failure"], result[:events].map(&:first)
  end

  test "log_authorization_failure routes to user audit" do
    user = clients(:one)
    exception = build_exception(record: clients(:two))
    audit = DummyAudit.new(current_user: user)

    result = capture_log_data(audit, exception)

    assert result[:user_called]
    assert_not result[:staff_called]
  end

  test "log_authorization_failure routes to staff audit" do
    staff = operators(:one)
    exception = build_exception(record: staff)
    audit = DummyAudit.new(current_operator: staff)

    result = capture_log_data(audit, exception)

    assert result[:staff_called]
    assert_not result[:user_called]
  end

  test "log_authorization_failure includes actor metadata" do
    user = clients(:one)
    exception = build_exception(record: clients(:two))
    audit = DummyAudit.new(current_user: user)

    result = capture_log_data(audit, exception)

    assert_equal "Client", result[:log_data][:actor_type]
    assert_equal user.public_id, result[:log_data][:actor_id]
  end

  test "log_authorization_failure includes policy metadata" do
    user = clients(:one)
    exception = build_exception(record: clients(:two))
    audit = DummyAudit.new(current_user: user)

    result = capture_log_data(audit, exception)

    assert_equal "AuthorizationAuditTest::DummyPolicy", result[:log_data][:policy]
    assert_equal :show?, result[:log_data][:query]
  end

  test "log_authorization_failure includes record metadata" do
    user = clients(:one)
    record = clients(:two)
    exception = build_exception(record: record)
    audit = DummyAudit.new(current_user: user)

    result = capture_log_data(audit, exception)

    assert_equal "Client", result[:log_data][:record_type]
    assert_equal record.public_id, result[:log_data][:record_id]
  end

  test "log_authorization_failure includes request metadata" do
    user = clients(:one)
    exception = build_exception(record: clients(:two))
    audit = DummyAudit.new(current_user: user)

    result = capture_log_data(audit, exception)

    assert_equal "127.0.0.1", result[:log_data][:ip_address]
    assert_equal "TestAgent", result[:log_data][:user_agent]
  end

  test "log_authorization_failure includes timestamp" do
    user = clients(:one)
    exception = build_exception(record: clients(:two))
    audit = DummyAudit.new(current_user: user)

    result = capture_log_data(audit, exception)

    assert_kind_of Time, result[:log_data][:timestamp]
  end

  test "log_authorization_failure skips when no actor" do
    audit = DummyAudit.new
    exception = build_exception(record: clients(:one))

    result = capture_log_data(audit, exception)

    assert_empty result[:events]
    assert_not result[:user_called]
  end

  test "log_authorization_failure creates real user audit record" do
    user = clients(:one)
    exception = build_exception(record: clients(:two))
    audit = DummyAudit.new(current_user: user)

    assert_difference "ClientChronicle.count", 1 do
      audit.send(:log_authorization_failure, exception)
    end

    record = ClientChronicle.last

    assert_equal user, record.user
    assert_equal 3, record.event_id
  end

  test "log_authorization_failure creates real staff audit record" do
    staff = operators(:one)
    exception = build_exception(record: staff)
    audit = DummyAudit.new(current_operator: staff)

    assert_difference "OperatorChronicle.count", 1 do
      audit.send(:log_authorization_failure, exception)
    end

    record = OperatorChronicle.last

    assert_equal staff.id, record.staff.id
    assert_equal 2, record.event_id
  end

  test "handle_authorization_error handles html format" do
    user = clients(:one)
    exception = build_exception(record: clients(:two))
    audit = DummyAudit.new(current_user: user)

    # We need to stub respond_to to only execute html block to simulate html request
    audit.define_singleton_method(:respond_to) do |&block|
      format = OpenStruct.new

      format.define_singleton_method(:html) do |&inner_block|
        inner_block&.call
      end

      format.define_singleton_method(:json) { nil }

      # Do nothing for json
      block.call(format)
    end

    audit.send(:handle_authorization_error, exception)

    assert_equal I18n.t("errors.messages.not_authorized"), audit.flash[:alert]
    assert_equal "/", audit.redirected_to
  end

  test "handle_authorization_error handles json format" do
    user = clients(:one)
    exception = build_exception(record: clients(:two))
    audit = DummyAudit.new(current_user: user)

    # We need to stub respond_to to only execute json block to simulate json request
    audit.define_singleton_method(:respond_to) do |&block|
      format = OpenStruct.new

      format.define_singleton_method(:html) { nil }

      # Do nothing for html

      format.define_singleton_method(:json) do |&inner_block|
        inner_block&.call
      end

      block.call(format)
    end

    audit.send(:handle_authorization_error, exception)

    assert_equal({ error: "Unauthorized" }, audit.rendered[:json])
    assert_equal :forbidden, audit.rendered[:status]
  end

  private

  def build_exception(record:)
    OpenStruct.new(policy: DummyPolicy.new(record: record), rule: :show?)
  end

  def capture_log_data(audit, exception)
    result = { events: [], user_called: false, staff_called: false, log_data: nil }

    audit.define_singleton_method(:create_user_authorization_audit) do |_actor, log_data|
      result[:user_called] = true
      result[:log_data] = log_data
    end
    audit.define_singleton_method(:create_staff_authorization_audit) do |_actor, log_data|
      result[:staff_called] = true
      result[:log_data] = log_data
    end

    logger =
      Struct.new(:events) do
        define_method(:info) do |message|
          payload = JSON.parse(message, symbolize_names: true)
          events << [payload.fetch(:event), payload.fetch(:data)]
        end

        # Stub: silently absorb error logs. Tests that need to observe
        # error logging should add explicit capture in the test body.
        define_method(:error) { |_message| nil }
      end

    Rails.stub(:logger, logger.new(result[:events])) do
      audit.send(:log_authorization_failure, exception)
    end

    result
  end
end
