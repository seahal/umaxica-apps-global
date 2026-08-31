# typed: false
# frozen_string_literal: true

require "test_helper"

# The footer year is rendered from Time.zone, so it is only correct if every
# surface resolves the timezone preference the same way. The clock is pinned to
# an instant where the two zones disagree about the year, which is the only time
# of day this can actually be observed. America/New_York is the far zone rather
# than Etc/UTC because the container's zoneinfo resolves UTC to the same offset
# as Asia/Tokyo, which would make the assertion pass without proving anything.
class CopyrightYearTimezoneTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  NEW_YEAR_STRADDLE = Time.utc(2026, 12, 31, 20, 0, 0) # 2026 in New York, 2027 in Tokyo

  SURFACES = [
    { name: "base_app",
      host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
      url_method: :base_app_preference_url, },
    { name: "base_org",
      host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
      url_method: :base_org_preference_url, },
    { name: "base_com",
      host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
      url_method: :base_com_preference_url, },
  ].freeze

  setup do
    https!
  end

  SURFACES.each do |surface|
    test "#{surface[:name]} renders the copyright year in the requested timezone" do
      host!(surface[:host])

      travel_to(NEW_YEAR_STRADDLE) do
        get public_send(surface[:url_method], ri: "jp", tz: "america/new_york")

        assert_response :success
        assert_equal "2026", rendered_copyright_year

        get public_send(surface[:url_method], ri: "jp", tz: "asia/tokyo")

        assert_response :success
        assert_equal "2027", rendered_copyright_year
      end
    end

    test "#{surface[:name]} ignores an unknown tz value rather than failing" do
      host!(surface[:host])

      travel_to(NEW_YEAR_STRADDLE) do
        get public_send(surface[:url_method], ri: "jp", tz: "Invalid/Zone")

        follow_redirect! while response.redirect?

        assert_response :success
        assert_equal "2027", rendered_copyright_year
      end
    end
  end

  test "the request time zone does not leak into the next request" do
    host!(SURFACES.first[:host])
    original = Time.zone.name

    get public_send(SURFACES.first[:url_method], ri: "jp", tz: "america/new_york")

    assert_response :success
    assert_equal original, Time.zone.name
  end

  private

  def rendered_copyright_year
    response.body[/\u00a9 (\d{4})/, 1]
  end
end
