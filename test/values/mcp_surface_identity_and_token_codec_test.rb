# typed: false
# frozen_string_literal: true

require "test_helper"

# Two value objects that decide which surface something belongs to. Both are
# exhaustive by construction and both refuse an unmapped value rather than
# defaulting, because a default here silently serves one surface's data from
# another's endpoint.
class McpSurfaceIdentityAndTokenCodecTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "an MCP identity is refused for a realm or surface that does not exist" do
    realm_error = assert_raises(ArgumentError) { McpSurfaceIdentity.new(realm: "martian", surface: "app") }

    assert_match(/unsupported MCP realm: martian/, realm_error.message)

    surface_error = assert_raises(ArgumentError) { McpSurfaceIdentity.new(realm: "base", surface: "martian") }

    assert_match(/unsupported MCP surface: martian/, surface_error.message)
  end

  test "each surface reports its own health profile and server name" do
    {
      "app" => ::Health::Profiles::App,
      "com" => ::Health::Profiles::Com,
      "org" => ::Health::Profiles::Org,
    }.each do |surface, profile|
      identity = McpSurfaceIdentity.new(realm: "base", surface: surface)

      assert_equal profile, identity.health_profile
      assert_equal "umaxica-base-#{surface}", identity.server_name
      assert_equal({ realm: "base", surface: surface }, identity.as_public_json)
    end
  end

  # Identities are compared by value and used as hash keys, so two identities for
  # the same pair have to be interchangeable and two for different pairs must not.
  test "identities compare and hash by realm and surface" do
    base_app = McpSurfaceIdentity.new(realm: "base", surface: "app")
    same = McpSurfaceIdentity.new(realm: "base", surface: "app")
    other_surface = McpSurfaceIdentity.new(realm: "base", surface: "com")
    other_realm = McpSurfaceIdentity.new(realm: "side", surface: "app")

    assert_equal base_app, same
    assert_equal base_app.hash, same.hash
    assert_not_equal base_app, other_surface
    assert_not_equal base_app, other_realm
    assert_not_equal base_app, "base/app"
    assert_equal 1, [base_app, same].uniq.size
    assert_equal 3, [base_app, same, other_surface, other_realm].uniq.size
  end

  # The OIDC client records a resource type in its own vocabulary; the token has
  # to carry the surface's. An unrecognised value is the end-user surface, which
  # is the least privileged of the three.
  test "an OIDC client's resource type maps onto the surface's own vocabulary" do
    {
      "operator" => "operator",
      "staff" => "operator",
      "visitor" => "visitor",
      "customer" => "visitor",
      "client" => "client",
      "something-else" => "client",
    }.each do |declared, expected|
      client = Struct.new(:resource_type).new(declared)

      assert_equal expected, SecurityJwtOidcIdTokenCodec.send(:resource_type_for_client, client), declared
    end
  end

  test "a numeric timestamp is normalised to UTC alongside a Time" do
    at = Time.utc(2026, 8, 31, 12, 0, 0)

    assert_equal at, SecurityJwtOidcIdTokenCodec.send(:normalize_time!, at.to_i)
    assert_equal at, SecurityJwtOidcIdTokenCodec.send(:normalize_time!, at)
    assert_equal at, SecurityJwtOidcIdTokenCodec.send(:normalize_time!, at.in_time_zone("Asia/Tokyo"))
  end
end
