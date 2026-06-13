# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcUserInfoResponseCoverageTest < ActiveSupport::TestCase
  test "build returns profile claims when the resource exposes them" do
    resource = Struct.new(:public_id, :name, :email).new("user-1", "Ada Lovelace", "ada@example.test")

    claims = OidcUserInfoResponse.build(resource: resource, payload: { "act" => "client" })

    assert_equal "Ada Lovelace", claims[:name]
    assert_equal "ada@example.test", claims[:email]
    assert_equal true, claims[:email_verified]
    assert_equal OidcSubject.for(resource, resource_type: "client"), claims[:sub]
  end

  test "build omits profile claims when the resource does not expose them" do
    resource = Struct.new(:public_id).new("visitor-1")

    claims = OidcUserInfoResponse.build(resource: resource, payload: { "act" => "visitor", "acr" => "acr" })

    assert_equal "acr", claims[:acr]
    assert_equal OidcSubject.for(resource, resource_type: "visitor"), claims[:sub]
    assert_not claims.key?(:name)
    assert_not claims.key?(:email)
    assert_not claims.key?(:email_verified)
  end
end
