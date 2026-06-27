# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::SignUpCompensationTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  class Harness < ApplicationController
    include SignUpSequenceControllerSupport

    attr_accessor :params_hash, :session_hash, :redirected, :rendered, :establish_kwargs,
                  :sign_up_surface_value, :sign_up_pending_actor_value
    attr_writer :sign_up_ticket_value

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def session
      @session_hash ||= {}
    end

    def request
      @request ||= Struct.new(:format).new(Struct.new(:json?, :html?).new(false, true))
    end

    def redirect_to(*args, **kwargs)
      self.redirected = [args, kwargs]
    end

    def render(*args, **kwargs)
      self.rendered = [args, kwargs]
    end

    def sign_up_surface
      sign_up_surface_value || :app
    end

    def sign_up_ticket_class
      ClientSignUpFlow
    end

    def sign_up_sequence_session_key
      :sign_app_up_sequence_id
    end

    def sign_up_ticket_record_class
      Class.new do
        def self.connected_to(...)
          yield
        end
      end
    end

    def allowed_to?(*)
      true
    end

    def sign_up_session_state
      @sign_up_session_state ||= Struct.new(:cleared) do
        def clear!
          self.cleared = true
        end

        def clear_all!
          clear!
        end
      end.new(false)
    end

    def sign_up_pending_actor
      sign_up_pending_actor_value
    end

    def sign_up_finalization_context
      Struct.new(:pending_actor).new(sign_up_pending_actor_value)
    end

    def sign_up_ticket
      sign_up_ticket_value
    end

    def sign_up_ticket_value
      @sign_up_ticket_value ||= Struct.new(
        :public_id, :entry_method, :pending_contact_type,
        :return_to, :checkpoint_pending_value,
      ) do
        def sign_up_checkpoint_pending?
          checkpoint_pending_value
        end

        def reload
          self
        end

        def with_cycle_lock
          yield
        end
      end.new("flow-1", "email", "email", nil, true)
    end

    def signed_pt_param
      nil
    end

    def path_from_signed_pt(_value)
      nil
    end

    def establish_signed_in_session!(resource, **kwargs)
      self.establish_kwargs = [resource, kwargs]
      { status: :success, redirect_path: "/dashboard" }
    end

    def reset_current_db_sign_in_flow_for_sequence!
      true
    end

    def redirect_after_sign_up_handoff!(_sign_in_result, json: false)
      self.rendered = [["redirect_after_sign_up_handoff"], { json: json }]
    end

    def sign_in_result_from_session_result(result, actor:)
      _ = actor
      result
    end

    def t(key, **)
      key.to_s
    end
  end

  test "handoff_to_sign_in_flow! marks bootstrap_actor true for new registrations" do
    harness = Harness.new
    actor = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    harness.instance_variable_set(
      :@sign_up_ticket,
      Struct.new(:public_id, :entry_method, :pending_contact_type, :return_to).new(
        "flow-1",
        "email",
        "email",
        nil,
      ),
    )

    harness.send(:handoff_to_sign_in_flow!, actor)

    assert_predicate harness.establish_kwargs, :present?
    assert_equal actor, harness.establish_kwargs.first
    assert harness.establish_kwargs.last[:bootstrap_actor]
    assert_equal "email", harness.establish_kwargs.last[:auth_method]
  end

  test "finalize_sign_up_from_checkpoint! stops before handoff when graph provisioning fails" do
    harness = Harness.new
    actor = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    harness.sign_up_pending_actor_value = actor
    harness.instance_variable_set(:@sign_up_ticket, harness.sign_up_ticket_value)

    events = []
    harness.define_singleton_method(:finalize_sign_up_side_effect!) { :accepted }
    harness.define_singleton_method(:perform_sign_up_event) do |event, payload: {}|
      events << event
      Struct.new(:success?, :status, :next_event).new(true, :ok, nil)
    end
    harness.define_singleton_method(:redirect_after_sign_up_handoff!) do |_sign_in_result, json: false|
      raise StandardError, "should not redirect"
    end

    error = RuntimeError.new("graph boom")
    IdentityGraphProvisioner.stub(:call!, ->(**) { raise error }) do
      raised = assert_raises(RuntimeError) { harness.send(:finalize_sign_up_from_checkpoint!) }
      assert_same error, raised
    end

    assert_equal [:finalize], events
    assert_not_predicate harness.sign_up_session_state, :cleared
    assert_nil harness.redirected
  end

  test "finalize_sign_up_from_checkpoint! surfaces handoff failure after graph provisioning" do
    harness = Harness.new
    actor = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    harness.sign_up_pending_actor_value = actor
    harness.instance_variable_set(:@sign_up_ticket, harness.sign_up_ticket_value)

    graph_provisioned = false
    events = []
    harness.define_singleton_method(:finalize_sign_up_side_effect!) { :accepted }
    harness.define_singleton_method(:perform_sign_up_event) do |event, payload: {}|
      events << event
      Struct.new(:success?, :status, :next_event).new(true, :ok, nil)
    end
    harness.define_singleton_method(:handoff_to_sign_in_flow!) do |_actor|
      raise RuntimeError, "session boom" if graph_provisioned

      raise RuntimeError, "graph was not provisioned"
    end
    harness.define_singleton_method(:redirect_after_sign_up_handoff!) do |_sign_in_result, json: false|
      raise StandardError, "should not redirect"
    end

    IdentityGraphProvisioner.stub(:call!, ->(**) { graph_provisioned = true }) do
      raised =
        assert_raises(RuntimeError) do
          harness.send(:finalize_sign_up_from_checkpoint!)
        end

      assert_equal "session boom", raised.message
      assert_predicate graph_provisioned, :itself
    end

    assert_equal [:finalize], events
    assert_nil harness.redirected
  end

  test "sign-up controllers do not directly issue tokens or cookies" do
    prohibited = [
      /ClientToken\.create/,
      /ClientDeviceSession\.create/,
      %r{cookies\[[^\]]*auth},
      /auth_access/,
      /auth_refresh/,
    ]
    paths = [
      "app/controllers/auth/app/sign/up/emails_controller.rb",
      "app/controllers/auth/app/sign/up/telephones_controller.rb",
      "app/controllers/auth/app/sign/up/check/email/otps_controller.rb",
      "app/controllers/auth/app/sign/up/check/telephone/otps_controller.rb",
      "app/controllers/auth/app/omniauth/omniauth_callbacks_controller.rb",
      "app/controllers/auth/app/social/authentications_controller.rb",
    ]

    matches =
      paths.flat_map do |path|
        text = File.read(path)
        prohibited.filter_map { |pattern| "#{path}:#{pattern.source}" if text.match?(pattern) }
      end

    assert_empty matches
  end
end
