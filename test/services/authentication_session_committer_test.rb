# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationSessionCommitterTest < ActiveSupport::TestCase
  test "delegates to the existing signed-in session helper without changing kwargs" do
    controller = Object.new
    resource = Object.new
    calls = []

    controller.define_singleton_method(:establish_signed_in_session!) do |actual_resource, **kwargs|
      calls << [actual_resource, kwargs]
      { status: :success }
    end

    result = AuthenticationSessionCommitter.call(
      controller: controller,
      resource: resource,
      pt: "/dashboard",
      ri: "jp",
      auth_method: "email",
    )

    assert_equal({ status: :success }, result)
    assert_equal [[resource, { pt: "/dashboard", ri: "jp", auth_method: "email" }]], calls
  end
end
