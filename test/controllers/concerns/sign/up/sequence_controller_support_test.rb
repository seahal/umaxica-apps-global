# typed: false
# frozen_string_literal: true

require "test_helper"

class SignUpSequenceControllerSupportTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include SignUpSequenceControllerSupport

    attr_accessor :params_hash, :session_hash, :rendered, :redirected, :performed_value,
                  :allowed_value, :sign_up_surface_value, :sign_up_ticket_record_class_value,
                  :sign_up_session_state_value, :sign_up_flow_locator_value, :sign_up_policy_context_value,
                  :sign_up_requirement_context_value, :sign_up_pending_actor_value, :sign_up_actor_authentication_value,
                  :sign_up_missing_requirements_value

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def session
      @session_hash ||= {}
    end

    def request
      @request ||= Struct.new(:format).new(Struct.new(:json?, :html?).new(false, true))
    end

    def render(*args, **kwargs)
      self.rendered = [args, kwargs]
    end

    def redirect_to(*args, **kwargs)
      self.redirected = [args, kwargs]
    end

    def performed?
      performed_value || false
    end

    def allowed_to?(*)
      return allowed_value unless allowed_value.nil?

      true
    end

    def sign_up_surface
      sign_up_surface_value || :app
    end

    def sign_up_session_state
      @sign_up_session_state_value ||= Struct.new(:age_restricted?, :cleared) do
        def clear!
          self.cleared = true
        end
      end.new(false, false)
    end

    def sign_up_flow_locator
      @sign_up_flow_locator_value || Struct.new(:current).new(nil)
    end

    def sign_up_policy_context
      sign_up_policy_context_value
    end

    def sign_up_requirement_context
      sign_up_requirement_context_value
    end

    def sign_up_pending_actor
      sign_up_pending_actor_value
    end

    def sign_up_actor_authentication
      sign_up_actor_authentication_value
    end

    def sign_up_ticket_record_class
      @sign_up_ticket_record_class_value || Class.new do
        def self.connected_to(...)
          yield
        end
      end
    end

    def sign_up_missing_requirements
      sign_up_missing_requirements_value || []
    end

    def t(key, **)
      key.to_s
    end
  end

  test "sign_up_pending_telephone_status? covers client and visitor branches" do
    harness = Harness.new
    client_telephone = ClientTelephone.new(user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP)
    visitor_telephone = VisitorTelephone.new(visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP)

    assert harness.send(:sign_up_pending_telephone_status?, client_telephone)
    assert harness.send(:sign_up_pending_telephone_status?, visitor_telephone)
    assert_not harness.send(:sign_up_pending_telephone_status?, Object.new)
  end

  test "hide_sign_up_auth_navigation and load_sign_up_ticket handle the fallback branches" do
    harness = Harness.new

    harness.send(:hide_sign_up_auth_navigation)

    assert harness.instance_variable_get(:@hide_auth_navigation)

    state = Object.new
    def state.age_restricted?
      false
    end
    flow = Struct.new(:current).new(:ticket)
    harness.sign_up_session_state_value = state
    harness.sign_up_flow_locator_value = flow

    harness.send(:load_sign_up_ticket)

    assert_equal :ticket, harness.instance_variable_get(:@sign_up_ticket)

    harness.sign_up_flow_locator_value = Struct.new(:current).new(nil)
    harness.send(:load_sign_up_ticket)

    assert_equal :not_found, harness.rendered.last[:status]
  end

  test "authorize_sign_up_participant! and requirement helpers reject when policy denies" do
    harness = Harness.new
    harness.allowed_value = false

    harness.send(:authorize_sign_up_participant!, :show?)

    assert_equal :forbidden, harness.rendered.last[:status]

    harness.rendered = nil
    context = Object.new
    def context.present?
      true
    end
    harness.sign_up_requirement_context_value = context
    harness.send(:authorize_sign_up_requirement_or_cleared_continue!, :show?)

    assert_equal :forbidden, harness.rendered.last[:status]
  end

  test "render_sign_up_result maps result statuses to the expected HTTP response" do
    harness = Harness.new
    result = Struct.new(:status).new(:expired)

    harness.send(:render_sign_up_result, result)

    assert_equal :gone, harness.rendered.last[:status]
  end

  test "sign_up telephone helpers cover surface-specific branches" do
    harness = Harness.new
    harness.sign_up_surface_value = :com

    assert_equal :visitor_telephone_registration, harness.send(:sign_up_telephone_registration_session_key)
    assert_equal "sign.com.registration.telephone.update.passkey_required",
                 harness.send(:telephone_passkey_required_i18n_key)

    harness.sign_up_surface_value = :app

    assert_equal :user_telephone_registration, harness.send(:sign_up_telephone_registration_session_key)
    assert_match(
      /sign\.app\.registration\.telephone\.update\.passkey_required/,
      harness.send(:telephone_passkey_required_i18n_key),
    )
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
