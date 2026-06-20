# typed: false
# frozen_string_literal: true

require "test_helper"

# DBSC registration/refresh URLs are a device-binding contract: the advertised `path`
# and the proof `aud` must be identical across registration and refresh. PreferenceGlobal
# merges per-request context params (ri/lx/...) into generated URLs, so the DBSC helpers
# must strip them. These tests pin the canonicalization at the helper and at the
# token_dbsc_path / token_dbsc_url route helpers.
class DbscCanonicalUrlTest < ActiveSupport::TestCase
  class Harness
    include DbscCanonicalUrl

    public :dbsc_canonical_url
  end

  setup { @harness = Harness.new }

  test "strips a single context query param" do
    assert_equal "/edge/v0/token/dbsc",
                 @harness.dbsc_canonical_url("/edge/v0/token/dbsc?ri=jp")
  end

  test "strips multiple context query params" do
    assert_equal "https://id.umaxica.app/edge/v0/token/dbsc",
                 @harness.dbsc_canonical_url("https://id.umaxica.app/edge/v0/token/dbsc?ri=us&lx=en&tz=UTC")
  end

  test "strips a fragment as well" do
    assert_equal "/edge/v0/dbsc", @harness.dbsc_canonical_url("/edge/v0/dbsc#frag")
  end

  test "leaves an already-canonical url unchanged" do
    assert_equal "/edge/v0/token/dbsc", @harness.dbsc_canonical_url("/edge/v0/token/dbsc")
    assert_equal "https://id.umaxica.app/edge/v0/token/dbsc",
                 @harness.dbsc_canonical_url("https://id.umaxica.app/edge/v0/token/dbsc")
  end

  test "returns blank input unchanged" do
    assert_nil @harness.dbsc_canonical_url(nil)
    assert_equal "", @harness.dbsc_canonical_url("")
  end

  test "token_dbsc_path strips context params injected by default_url_options" do
    controller = Sign::App::Edge::V0::Token::ChecksController.new
    controller.define_singleton_method(:resource_type) { "client" }
    # Simulate PreferenceGlobal#default_url_options leaking the region param into the
    # generated route helper.
    controller.define_singleton_method(:sign_app_edge_v0_token_dbsc_path) do
      "/edge/v0/token/dbsc?ri=jp"
    end

    assert_equal "/edge/v0/token/dbsc", controller.send(:token_dbsc_path)
  end

  test "token_dbsc_url strips context params so the audience stays stable" do
    controller = Sign::App::Edge::V0::Token::ChecksController.new
    controller.define_singleton_method(:resource_type) { "client" }
    controller.define_singleton_method(:sign_app_edge_v0_token_dbsc_url) do
      "https://id.umaxica.app/edge/v0/token/dbsc?ri=jp&lx=ja"
    end

    assert_equal "https://id.umaxica.app/edge/v0/token/dbsc", controller.send(:token_dbsc_url)
  end
end
