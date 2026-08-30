# typed: false
# frozen_string_literal: true

require "test_helper"

class ComSignUpCheckpointPageTest < ActiveSupport::TestCase
  class Harness
    include ComSignUpCheckpointPage

    attr_accessor :ticket, :missing, :actor, :params_hash, :render_args, :surface, :headers, :restart_path

    def initialize
      @params_hash = { ri: "tokyo" }
      @headers = {}
      @surface = "com"
      @restart_path = "/sign-up"
      @missing = []
    end

    def params = ActionController::Parameters.new(@params_hash)

    def t(key, **)
      I18n.t(key, **)
    end

    def signed_pt_param
      "pt-token"
    end

    def sign_up_missing_requirements
      missing
    end

    def sign_up_pending_actor
      actor
    end

    def sign_up_surface
      surface
    end

    def sign_up_restart_path
      restart_path
    end

    def helpers
      Object.new.tap do |helper|
        helper.define_singleton_method(:sign_up_birthdate_date_format) { "ymd" }
        helper.define_singleton_method(:sign_up_birthdate_prop_separator) { "-" }
        helper.define_singleton_method(:sign_up_birthdate_prop_parts) { |_date| %w(2000 01 02) }
      end
    end

    def response
      Struct.new(:headers).new(headers)
    end

    def render(**kwargs)
      @render_args = kwargs
    end

    def auth_com_sign_up_check_telephone_birthdate_path(**kwargs)
      "/check/telephone/birthdate?#{kwargs.to_query}"
    end

    def auth_com_sign_up_check_telephone_passkey_path(**kwargs)
      "/check/telephone/passkey?#{kwargs.to_query}"
    end

    def auth_com_sign_up_check_telephone_passcode_path(**kwargs)
      "/check/telephone/passcode?#{kwargs.to_query}"
    end

    def auth_com_sign_up_check_telephone_path(**kwargs)
      "/check/telephone?#{kwargs.to_query}"
    end
  end

  test "render_sign_up_checkpoint includes every missing requirement section" do
    harness = Harness.new
    harness.ticket = Struct.new(:completed_requirements, :entry_method, :checkpoint_version).new(
      [:email], "telephone", 3,
    )
    harness.missing = %i(birthdate passkey passcode)
    harness.actor = Struct.new(:birthdate).new(Date.new(2000, 1, 2))
    harness.instance_variable_set(:@sign_up_ticket, harness.ticket)

    harness.send(:render_sign_up_checkpoint)
    props = harness.render_args[:props]

    assert_equal ComSignUpCheckpointPage::CHECKPOINT_COMPONENT, harness.render_args[:inertia]
    assert_equal :ok, harness.render_args[:status]
    assert_predicate props[:birthdate], :present?
    assert_predicate props[:passkey], :present?
    assert_predicate props[:passcode], :present?
    assert_nil props[:complete_message]
    assert_equal I18n.t("actions.cancel"), props[:cancellation][:label]
  end

  test "render_sign_up_checkpoint reports completion when nothing is missing" do
    harness = Harness.new
    harness.ticket = Struct.new(:completed_requirements, :entry_method, :checkpoint_version).new(
      %i(birthdate passkey), "telephone", 1,
    )
    harness.missing = []
    harness.instance_variable_set(:@sign_up_ticket, harness.ticket)

    harness.send(:render_sign_up_checkpoint)
    props = harness.render_args[:props]

    assert_nil props[:birthdate]
    assert_equal I18n.t("sign.com.registration.checkpoint.show.complete"), props[:complete_message]
  end

  test "render_sign_up_age_restricted rejects a non-com surface and otherwise renders inertia" do
    harness = Harness.new
    harness.surface = "app"

    error = assert_raises(ArgumentError) { harness.send(:render_sign_up_age_restricted) }
    assert_match(/sign_up_surface "app"/, error.message)

    harness.surface = "com"
    harness.send(:render_sign_up_age_restricted)

    assert_equal "no-store, private", harness.headers["Cache-Control"]
    assert_equal ComSignUpCheckpointPage::AGE_RESTRICTED_COMPONENT, harness.render_args[:inertia]
    assert_equal "/sign-up", harness.render_args[:props][:back][:href]
  end
end
