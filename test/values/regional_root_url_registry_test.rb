# typed: false
# frozen_string_literal: true

require "test_helper"

class RegionalRootUrlRegistryTest < ActiveSupport::TestCase
  test "every surface allowlists exactly the regions the request context contract allows" do
    expected = RequestContextContract::ALLOWED_REGIONS.sort

    RegionalRootUrlRegistry::URLS.each do |surface, urls|
      assert_equal expected, urls.keys.sort, "surface #{surface.inspect} drifted from ALLOWED_REGIONS"
    end
  end

  test "covers the three user-facing surfaces" do
    assert_equal %i(app com org), RegionalRootUrlRegistry::SURFACES
  end

  test "resolves each surface and region to its canonical regional root" do
    assert_equal "https://jp.umaxica.app/", RegionalRootUrlRegistry.url_for(surface: :app, region: "jp")
    assert_equal "https://us.umaxica.app/", RegionalRootUrlRegistry.url_for(surface: :app, region: "us")
    assert_equal "https://jp.umaxica.com/", RegionalRootUrlRegistry.url_for(surface: :com, region: "jp")
    assert_equal "https://us.umaxica.com/", RegionalRootUrlRegistry.url_for(surface: :com, region: "us")
    assert_equal "https://jp.umaxica.org/", RegionalRootUrlRegistry.url_for(surface: :org, region: "jp")
    assert_equal "https://us.umaxica.org/", RegionalRootUrlRegistry.url_for(surface: :org, region: "us")
  end

  test "returns nil for an unknown region instead of falling back to a default" do
    assert_nil RegionalRootUrlRegistry.url_for(surface: :app, region: "xx")
    assert_nil RegionalRootUrlRegistry.url_for(surface: :app, region: nil)
    assert_nil RegionalRootUrlRegistry.url_for(surface: :app, region: "")
    assert_nil RegionalRootUrlRegistry.url_for(surface: :app, region: "JP")
    assert_nil RegionalRootUrlRegistry.url_for(surface: :app, region: "jp.evil.example")
  end

  test "raises for an unknown surface" do
    assert_raises(KeyError) { RegionalRootUrlRegistry.url_for(surface: :dev, region: "jp") }
  end

  test "every destination is an https regional root with no path segment or query" do
    RegionalRootUrlRegistry::URLS.each_value do |urls|
      urls.each do |region, url|
        uri = URI.parse(url)

        assert_equal "https", uri.scheme
        assert_equal "/", uri.path
        assert_nil uri.query
        assert_nil uri.fragment
        assert uri.host.start_with?("#{region}.umaxica."), "#{url} is not the #{region} regional host"
      end
    end
  end
end
