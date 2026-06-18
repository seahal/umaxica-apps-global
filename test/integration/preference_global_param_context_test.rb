# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceGlobalParamContextTest < ActionDispatch::IntegrationTest
  fixtures_none!

  setup do
    https!
  end

  DOMAINS = [
    { name: "acme_app", host: "www.app.localhost", preference_url_method: :acme_app_preference_url },
    { name: "acme_org", host: "www.org.localhost", preference_url_method: :acme_org_preference_url },
    { name: "acme_com", host: "www.com.localhost", preference_url_method: :acme_com_preference_url },
  ].freeze

  # =============================================================================
  # ri parameter tests - ri is always required
  # =============================================================================

  DOMAINS.each do |domain|
    test "#{domain[:name]} redirects to add ri param when missing" do
      host!(domain[:host])

      url_method = domain[:preference_url_method] || domain[:root_url_method]
      get public_send(url_method)

      assert_response :redirect
      follow_redirect!

      # After redirect, ri should be present in URL
      assert_match(/ri=jp/, request.url)
    end

    test "#{domain[:name]} does not redirect when ri param is present" do
      host!(domain[:host])

      url_method = domain[:preference_url_method] || domain[:root_url_method]
      get public_send(url_method, ri: "us")

      assert_response :success
      assert_match(/ri=us/, request.url)
    end

    test "#{domain[:name]} uses ri as request-local locale when lx is absent" do
      host!(domain[:host])

      url_method = domain[:preference_url_method] || domain[:root_url_method]
      get public_send(url_method, ri: "us")

      assert_response :success
      assert_select "html[lang='en']"

      get public_send(url_method, ri: "jp")

      assert_response :success
      assert_select "html[lang='ja']"
    end

    test "#{domain[:name]} prefers explicit lx over ri-derived locale" do
      host!(domain[:host])

      url_method = domain[:preference_url_method] || domain[:root_url_method]
      get public_send(url_method, ri: "jp", lx: "en")

      assert_response :success
      assert_select "html[lang='en']"
    end

    test "#{domain[:name]} timezone edit includes United States timezone options" do
      host!(domain[:host])

      surface = domain[:name].delete_prefix("acme_")
      get public_send("edit_acme_#{surface}_preference_timezone_url", ri: "jp", lx: "ja")

      assert_response :success
      assert_select "html[lang='ja']"
      assert_select "select[name='preference_timezone[option_id]'] option", text: /東部時間/
      assert_select "select[name='preference_timezone[option_id]'] option", text: /中部時間/
      assert_select "select[name='preference_timezone[option_id]'] option", text: /山岳部時間/
      assert_select "select[name='preference_timezone[option_id]'] option", text: /太平洋時間/
      assert_select "select[name='preference_timezone[option_id]'] option", text: /アラスカ時間/
      assert_select "select[name='preference_timezone[option_id]'] option", text: /ハワイ時間/
    end

    test "#{domain[:name]} ri param is always included in default_url_options" do
      host!(domain[:host])

      url_method = domain[:preference_url_method] || domain[:root_url_method]
      get public_send(url_method, ri: "us", lx: "en", ct: "dr", tz: "utc")

      assert_response :success

      # Check that links generated with url helpers have ri parameter
      # Look for specific navigation links that use url helpers
      links = css_select("a[href*='/preference']")
      links.each do |link|
        href = link["href"]

        assert_match(/ri=/, href, "Preference link should include ri parameter: #{href}")
      end
    end
  end

  # =============================================================================
  # Optional params tests - lx, ct, tz are only added if present in request
  # =============================================================================

  DOMAINS.each do |domain|
    test "#{domain[:name]} lx param is preserved in navigation links when present in request" do
      host!(domain[:host])

      url_method = domain[:preference_url_method] || domain[:root_url_method]
      get public_send(url_method, ri: "jp", lx: "en", ct: "dr", tz: "utc")

      assert_response :success

      # Check preference links (which use url helpers)
      links = css_select("a[href*='/preference'][href*='lx=en']")

      assert_predicate links, :any?,
                       "Preference links should preserve lx=en parameter when it was in the request"
    end

    test "#{domain[:name]} lx param is NOT added to navigation links when NOT in request" do
      host!(domain[:host])

      url_method = domain[:preference_url_method] || domain[:root_url_method]
      get public_send(url_method, ri: "jp")

      assert_response :success

      # Check preference links - they should NOT have lx parameter
      links = css_select("a[href*='/preference']")
      links.each do |link|
        href = link["href"]

        assert_no_match(/lx=/, href, "Preference link should NOT include lx parameter: #{href}")
      end
    end

    test "#{domain[:name]} ct param is preserved in navigation links when present in request" do
      host!(domain[:host])

      url_method = domain[:preference_url_method] || domain[:root_url_method]
      get public_send(url_method, ri: "jp", lx: "en", ct: "dr", tz: "utc")

      assert_response :success

      links = css_select("a[href*='/preference'][href*='ct=dr']")

      assert_predicate links, :any?,
                       "Preference links should preserve ct=dr parameter when it was in the request"
    end

    test "#{domain[:name]} ct param is NOT added to navigation links when NOT in request" do
      host!(domain[:host])

      url_method = domain[:preference_url_method] || domain[:root_url_method]
      get public_send(url_method, ri: "jp")

      assert_response :success

      links = css_select("a[href*='/preference']")
      links.each do |link|
        href = link["href"]

        assert_no_match(/ct=/, href, "Preference link should NOT include ct parameter: #{href}")
      end
    end

    test "#{domain[:name]} tz param is preserved in navigation links when present in request" do
      host!(domain[:host])

      url_method = domain[:preference_url_method] || domain[:root_url_method]
      get public_send(url_method, ri: "jp", lx: "en", ct: "dr", tz: "utc")

      assert_response :success

      links = css_select("a[href*='/preference'][href*='tz=utc']")

      assert_predicate links, :any?,
                       "Preference links should preserve tz=utc parameter when it was in the request"
    end

    test "#{domain[:name]} tz param is NOT added to navigation links when NOT in request" do
      host!(domain[:host])

      url_method = domain[:preference_url_method] || domain[:root_url_method]
      get public_send(url_method, ri: "jp")

      assert_response :success

      links = css_select("a[href*='/preference']")
      links.each do |link|
        href = link["href"]

        assert_no_match(/tz=/, href, "Preference link should NOT include tz parameter: #{href}")
      end
    end

    test "#{domain[:name]} multiple optional params are preserved together in navigation links" do
      host!(domain[:host])

      url_method = domain[:preference_url_method] || domain[:root_url_method]
      get public_send(
        url_method,
        ri: "us",
        lx: "en",
        ct: "dr",
        tz: "utc",
        cu: "usd",
        df: "us",
        tf: "12",
        mo: "rd",
        dn: "cp",
        ps: "50",
      )

      assert_response :success

      # Check that preference links preserve all params
      links = css_select("a[href*='/preference']")

      assert_predicate links, :any?, "Should have preference links"

      # At least some links should have all the params
      links_with_all_params =
        links.select do |link|
          href = link["href"]
          %w(lx=en ct=dr tz=utc cu=usd df=us tf=12 mo=rd dn=cp ps=50).all? do |param|
            href.include?(param)
          end
        end

      assert_predicate links_with_all_params, :any?,
                       "Some preference links should have all optional params preserved"
    end

    test "#{domain[:name]} redirect target params are not preserved in navigation links by default" do
      host!(domain[:host])

      url_method = domain[:preference_url_method] || domain[:root_url_method]
      get public_send(url_method, ri: "jp", pt: "signed-path-target", nt: "dashboard")

      assert_response :success

      links = css_select("a[href*='/preference']")
      links.each do |link|
        href = link["href"]

        assert_no_match(/pt=/, href, "Preference link should not include pt by default: #{href}")
        assert_no_match(/nt=/, href, "Preference link should not include nt by default: #{href}")
      end
    end

    test "#{domain[:name]} invalid optional params are removed from request URL" do
      host!(domain[:host])

      url_method = domain[:preference_url_method] || domain[:root_url_method]
      get public_send(url_method, ri: "jp", lx: "kr", ct: "purple", tz: "Mars/Base")

      assert_response :redirect
      location = response.headers["Location"]

      assert_match(/ri=jp/, location)
      assert_no_match(/lx=/, location)
      assert_no_match(/ct=/, location)
      assert_no_match(/tz=/, location)
    end

    test "#{domain[:name]} jst timezone param is removed from theme edit URL" do
      host!(domain[:host])

      surface = domain[:name].delete_prefix("acme_")
      get public_send("edit_acme_#{surface}_preference_theme_url", ri: "us", lx: "en", tz: "jst")

      assert_response :redirect
      location = URI.parse(response.headers.fetch("Location"))
      query = Rack::Utils.parse_query(location.query)

      assert_equal "/preference/theme/edit", location.path
      assert_equal "us", query["ri"]
      assert_equal "en", query["lx"]
      assert_not query.key?("tz")
    end

    test "#{domain[:name]} canonicalizes timezone param in request URL to lowercase" do
      host!(domain[:host])

      surface = domain[:name].delete_prefix("acme_")
      get public_send("edit_acme_#{surface}_preference_theme_url", ri: "jp", tz: "Asia/Tokyo")

      assert_response :redirect
      location = URI.parse(response.headers.fetch("Location"))
      query = Rack::Utils.parse_query(location.query)

      assert_equal "/preference/theme/edit", location.path
      assert_equal "jp", query["ri"]
      assert_equal "asia/tokyo", query["tz"]
    end
  end

  # =============================================================================
  # Redirect behavior tests
  # =============================================================================

  DOMAINS.each do |domain|
    test "#{domain[:name]} redirect to add ri preserves existing query params" do
      host!(domain[:host])

      url_method = domain[:preference_url_method] || domain[:root_url_method]
      # Access without ri but with other params
      get public_send(url_method, foo: "bar")

      assert_response :redirect
      location = response.headers["Location"]

      # Should have ri added
      assert_match(/ri=jp/, location)
      # Should preserve other params
      assert_match(/foo=bar/, location)
    end

    test "#{domain[:name]} redirect to add ri does NOT add lx automatically" do
      host!(domain[:host])

      url_method = domain[:preference_url_method] || domain[:root_url_method]
      get public_send(url_method)

      assert_response :redirect
      location = response.headers["Location"]

      # Should have ri added
      assert_match(/ri=jp/, location)
      # Should NOT have lx added automatically
      assert_no_match(/lx=/, location)
    end
  end

  private

  def internal_links_for(host)
    allowed_hosts = [
      host,
      ENV["ID_SERVICE_URL"],
      ENV["ID_STAFF_URL"],
      ENV["EDGE_SERVICE_URL"],
      ENV["EDGE_STAFF_URL"],
    ].compact

    css_select("a[href]").select do |link|
      href = link["href"]
      next false if href.blank? || href.start_with?("#")

      if href.start_with?("/")
        true
      else
        uri = URI.parse(href) rescue nil
        uri&.host && allowed_hosts.include?(uri.host)
      end
    end
  end
end
