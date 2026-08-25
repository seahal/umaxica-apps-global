# typed: false
# frozen_string_literal: true

require "test_helper"

# The Auth credential gateway must carry the same region contract as Base: every browser-facing
# page normalizes a missing or unrecognized `ri` to the default region, and every URL it generates
# carries the region forward.
#
# The sign-in and sign-up pages used to skip `PreferenceGlobal#set_region`. A request without `ri`
# therefore rendered with no region in the request context and produced region-less links, and a
# request with an unrecognized `ri` propagated that unvalidated value into every generated URL.
class AuthRegionContractTest < ActionDispatch::IntegrationTest
  SURFACES = [
    ["app", ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")],
    ["com", ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")],
    ["org", ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")],
  ].freeze

  ENTRY_PATHS = %w(/sign/in /sign/up).freeze

  test "a missing region is normalized on every credential gateway entry page" do
    SURFACES.each do |surface, host|
      ENTRY_PATHS.each do |path|
        host! host
        get path

        assert_response :found, "#{surface} #{path} must normalize a missing region"
        assert_equal "http://#{host}#{path}?ri=jp", response.location
      end
    end
  end

  test "an unrecognized region is normalized instead of being propagated" do
    SURFACES.each do |surface, host|
      ENTRY_PATHS.each do |path|
        host! host
        get path, params: { ri: "xx" }

        assert_response :found, "#{surface} #{path} must normalize an unrecognized region"
        assert_equal "http://#{host}#{path}?ri=jp", response.location
      end
    end
  end

  # The authorization endpoint skips region normalization, so the region has to travel on the
  # authorize URL itself. It used to be absent, which sent the whole ceremony -- and every URL
  # built from it inside the credential gateway -- into the default region.
  test "the base authorization handoff carries the region into the credential gateway" do
    %w(jp us).each do |region|
      host! ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
      get "/dashboard", params: { ri: region }

      assert_response :found

      query = Rack::Utils.parse_nested_query(URI.parse(response.location).query)

      assert_equal region, query["ri"],
                   "the authorization handoff dropped the #{region} region: #{response.location}"
    end
  end

  test "every generated link on an entry page carries the requested region" do
    SURFACES.each do |surface, host|
      ENTRY_PATHS.each do |path|
        %w(jp us).each do |region|
          host! host
          get path, params: { ri: region }

          assert_response :success, "#{surface} #{path}?ri=#{region} must render"

          relative = response.body.scan(/(?:href|action)="(\/[^"]*)"/).flatten.uniq
          missing = relative.reject { |target| asset_target?(target) || target.include?("ri=#{region}") }

          assert_empty missing,
                       "#{surface} #{path}?ri=#{region} generated links without the region: #{missing.inspect}"
        end
      end
    end
  end

  private

  # The layout links its surface stylesheet, and a built environment additionally emits
  # `<link rel="modulepreload">` for the entrypoint's chunks. Those are assets rather than
  # navigation, and Vite serves them all from its own output directory, so the region does not and
  # must not travel on them.
  def asset_target?(target)
    target.start_with?("/#{ViteRuby.config.public_output_dir}/")
  end
end
