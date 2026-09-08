# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationBaseBranchCoverageMoreTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include AuthenticationBase

    attr_accessor :resource_type_value, :request_value, :session_value

    def resource_type = resource_type_value || "client"

    def resource_class = Client

    def token_class = ClientToken

    def audit_class = ClientChronicle

    def resource_foreign_key = :user_id

    def request = request_value

    def session = session_value || {}

    def am_i_user? = true

    def am_i_operator? = false

    def am_i_owner? = false
  end

  test "authentication mode and filter guards skip ineligible rules" do
    klass = Class.new(Harness)
    klass.declare_authentication_mode!(:guest, only: :allowed)

    assert_includes %i(deny_all unexpected), klass.authentication_mode_for(:other)
    klass.skip_before_action({ enforce_access_policy!: true })
    assert_raises(AuthenticationBase::SkipNotAllowedError) { klass.skip_action_callback(:process_action, :before, :enforce_access_policy!) }
  end
end
