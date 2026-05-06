# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceGlobalParamContextTest < ActionDispatch::IntegrationTest
  setup do
    https!
  end

  DOMAINS = [
    { name: "sign_app", host: "id.app.localhost", preference_url_method: :sign_app_preference_url },
    { name: "sign_org", host: "id.org.localhost", preference_url_method: :sign_org_preference_url },
    { name: "sign_com", host: "id.com.localhost", preference_url_method: :sign_com_preference_url },
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
      get public_send(url_method, ri: "us", lx: "en", ct: "dr", tz: "utc")

      assert_response :success

      # Check that preference links preserve all params
      links = css_select("a[href*='/preference']")

      assert_predicate links, :any?, "Should have preference links"

      # At least some links should have all the params
      links_with_all_params =
        links.select do |link|
          href = link["href"]
          href.include?("lx=en") && href.include?("ct=dr") && href.include?("tz=utc")
        end

      assert_predicate links_with_all_params, :any?,
                       "Some preference links should have all optional params preserved"
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
