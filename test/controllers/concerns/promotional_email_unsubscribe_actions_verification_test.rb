# typed: false
# frozen_string_literal: true

require "test_helper"

# One-click unsubscribe arrives as a cross-origin POST from a mail client, so it
# cannot carry a CSRF token. It is accepted only when the signed token in the
# link verifies against the addressed record and the surface's own scope --
# anything else falls back to the ordinary CSRF check.
class PromotionalEmailUnsubscribeActionsVerificationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < ActionController::Base
    include PromotionalEmailUnsubscribeActions

    attr_accessor :params_hash, :action, :email_model, :scope

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def action_name = action

    def promotional_email_model = email_model

    def promotional_email_scope = scope

    def invoke(name, ...) = send(name, ...)
  end

  class EmailModel
    def self.record = @record

    def self.record=(value)
      @record = value
    end

    def self.find_by(**) = record
  end

  setup do
    @harness = Harness.new
    @harness.email_model = EmailModel
    @harness.scope = "app"
    @harness.action = "create"
    @harness.params_hash = { id: "pub-1", token: "signed-token" }
    EmailModel.record = nil
  end

  test "a request for an action other than the unsubscribe write is not exempted" do
    @harness.action = "show"

    assert_not @harness.invoke(:promotional_unsubscribe_create_request?)
  end

  test "a link naming a record that does not exist is not exempted" do
    EmailModel.record = nil

    assert_not @harness.invoke(:promotional_unsubscribe_create_request?)
  end

  test "a link whose token verifies against the addressed record is exempted" do
    EmailModel.record = Object.new

    PromotionalEmailUnsubscribeToken.stub(:valid?, true) do
      assert @harness.invoke(:promotional_unsubscribe_create_request?)
    end
  end

  test "a link whose token does not verify is not exempted" do
    EmailModel.record = Object.new

    PromotionalEmailUnsubscribeToken.stub(:valid?, false) do
      assert_not @harness.invoke(:promotional_unsubscribe_create_request?)
    end
  end
end
