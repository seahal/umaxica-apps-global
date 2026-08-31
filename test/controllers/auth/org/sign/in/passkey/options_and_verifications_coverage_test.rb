# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthOrgSignInPasskeyCoverageTest < ActiveSupport::TestCase
  module Shared
    attr_accessor :rendered, :established, :issued_gate

    def initialize
      @params_hash = { identifier: "op_public_id" }
    end

    def params = ActionController::Parameters.new(@params_hash)

    def render_session_limit_hard_reject(**kwargs)
      self.rendered = kwargs
    end

    def issue_session_limit_gate!(**)
      self.issued_gate = true
    end

    def request
      Struct.new(:fullpath, :remote_ip).new("/passkeys", "127.0.0.1")
    end

    def render(json:, status:)
      self.rendered = [json, status]
    end

    def establish_signed_in_session!(staff, **)
      self.established = staff
    end

    def retrieve_pt_for_checkpoint
      "pt"
    end

    def current_region_identifier
      "tokyo"
    end

    def auth_org_sign_in_session_path
      "/org/session"
    end

    def auth_org_sign_in_check_path(**kwargs)
      "/org/check?#{kwargs.to_query}"
    end

    def auth_org_root_path(**kwargs)
      "/org?#{kwargs.to_query}"
    end

    def new_auth_org_sign_in_passkey_path
      "/org/passkey/new"
    end

    def verify_turnstile_stealth!
      true
    end
  end

  class OptionsHarness < Auth::Org::Sign::In::Passkey::OptionsController
    include Shared

    def initialize
      @params_hash = { identifier: "op_public_id" }
    end
  end

  class VerificationsHarness < Auth::Org::Sign::In::Passkey::VerificationsController
    include Shared

    def initialize
      @params_hash = { identifier: "op_public_id" }
    end
  end

  [OptionsHarness, VerificationsHarness].each do |harness_class|
    test "#{harness_class} identifier helpers and login status branches" do
      harness = harness_class.new

      assert_equal "errors.webauthn.identifier_required", harness.send(:passkey_identifier_required_error_key)
      assert_equal "errors.webauthn.identifier_invalid", harness.send(:passkey_identifier_invalid_error_key)
      assert harness.send(:before_passkey_options_request!)

      staff = Object.new
      staff.define_singleton_method(:login_allowed?) { true }
      passkey = Struct.new(:staff).new(staff)
      Operator.stub(:normalize_public_id, "abc") do
        Operator.stub(:find_by, staff) do
          assert_equal staff, harness.send(:find_active_passkey_actor, "abc")
        end
      end
      Operator.stub(:normalize_public_id, "") do
        assert_nil harness.send(:find_active_passkey_actor, " ")
      end

      harness.send(:perform_passkey_sign_in, passkey)

      assert_equal staff, harness.established
      assert harness.send(
        :handle_domain_specific_login_status,
        { status: :session_limit_hard_reject, message: "limit", http_status: 403 },
      )
      assert harness.send(:handle_domain_specific_login_status, { status: :session_limit_exceeded })
      assert harness.issued_gate
      assert_equal false, harness.send(:handle_domain_specific_login_status, { status: :ok })

      harness.send(:render_passkey_restricted_success, {})

      assert_equal "session_restricted", harness.rendered.first[:status]
      assert_includes harness.send(:passkey_checkpoint_redirect_url), "pt=pt"
      assert_includes harness.send(:passkey_default_redirect_url), "ri=tokyo"
    end
  end
end
