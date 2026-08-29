# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationLogoutAllSessionsTest < ActiveSupport::TestCase
  test "returns true when no actor is supplied" do
    assert AuthenticationLogoutAllSessions.call(resource: nil)
  end

  test "returns true for an unsupported actor class" do
    assert AuthenticationLogoutAllSessions.call(resource: Object.new)
  end

  test "records a session version failure without raising" do
    resource = Object.new
    resource.define_singleton_method(:session_version) { 1 }
    resource.define_singleton_method(:session_version=) { |_value| }
    resource.define_singleton_method(:save!) { raise ActiveRecord::RecordInvalid.new(Client.new) }
    resource.define_singleton_method(:id) { "resource-1" }

    assert AuthenticationLogoutAllSessions.call(resource: resource)
  end
end
