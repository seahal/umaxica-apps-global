# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "sha3"

class AcmePreferenceTest < ActionDispatch::IntegrationTest
  setup do
    https!
  end

  DOMAINS = [
    {
      name: "app",
      host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
      scope: "base.app.preferences",
      preference_model: AppPreference,
      audit_class: AppPreferenceChronicle,
      audit_event_class: AppPreferenceChronicleEvent,
    },
    {
      name: "org",
      host: ENV.fetch("PRIVATE_BASE_STAFF_URL", "www.org.localhost"),
      scope: "base.org.preferences",
      preference_model: OrgPreference,
      audit_class: OrgPreferenceChronicle,
      audit_event_class: OrgPreferenceChronicleEvent,
    },
    {
      name: "com",
      host: ENV.fetch("PRIVATE_BASE_CORPORATE_URL", "www.com.localhost"),
      scope: "base.com.preferences",
      preference_model: ComPreference,
      audit_class: ComPreferenceChronicle,
      audit_event_class: ComPreferenceChronicleEvent,
    },
  ].freeze

  DOMAINS.each do |domain|
    test "#{domain[:name]} domain creates preference on index" do
      host!(domain[:host])

      pref, _token, _cookie_name = assert_preference_created(domain)
      assert pref.status_id.nil? || [0, 2].include?(pref.status_id)

      assert_equal PreferenceClassRegistry.option_class(domain[:name].camelize, :region)::JP,
                   pref.public_send("#{domain[:name]}_preference_region").option_id
      assert_equal PreferenceClassRegistry.option_class(domain[:name].camelize, :language)::JA,
                   pref.public_send("#{domain[:name]}_preference_language").option_id
    end

    test "#{domain[:name]} domain seeds new preference language from requested region" do
      host!(domain[:host])

      pref, _token, _cookie_name = assert_preference_created(domain, ri: "us")

      assert_equal PreferenceClassRegistry.option_class(domain[:name].camelize, :region)::US,
                   pref.public_send("#{domain[:name]}_preference_region").option_id
      assert_equal PreferenceClassRegistry.option_class(domain[:name].camelize, :language)::EN,
                   pref.public_send("#{domain[:name]}_preference_language").option_id
    end

    test "#{domain[:name]} domain redirects to add ri param when missing" do
      host!(domain[:host])

      # Visit URL without ri parameter
      get public_send("base_#{domain[:name]}_preference_url")

      # Should redirect to include ri=jp
      assert_redirected_to public_send("base_#{domain[:name]}_preference_url", ri: "jp")
    end

    test "#{domain[:name]} domain does not redirect when ri param present" do
      host!(domain[:host])

      # Visit URL with ri parameter
      get public_send("base_#{domain[:name]}_preference_url", ri: "us")

      # Should not redirect
      assert_response :success
    end

    test "#{domain[:name]} domain respects lx param for locale" do
      host!(domain[:host])

      # Visit URL with lx=en and ri=us
      get public_send("edit_base_#{domain[:name]}_preference_cookie_url", lx: "en", ri: "us")

      # Should not redirect and locale should be set to English
      assert_response :success
      assert_equal :en, I18n.locale
    end

    test "#{domain[:name]} domain updates region" do
      host!(domain[:host])
      pref, = assert_preference_created(domain)

      state = default_state.merge(ri: "us")

      assert_preference_update(
        domain,
        :region,
        { preference_region: { option_id: "US" } },
        state,
      )

      pref.reload

      assert_equal 1, pref.try("#{domain[:name]}_preference_region").option_id
      assert_equal PreferenceClassRegistry.option_class(domain[:name].camelize, :language)::EN,
                   pref.try("#{domain[:name]}_preference_language").option_id
    end

    test "#{domain[:name]} domain keeps request region context when saved region changes to Japan" do
      host!(domain[:host])
      pref, = assert_preference_created(domain, ri: "us")

      state = { ri: "us" }

      get public_send("edit_base_#{domain[:name]}_preference_region_url", state)

      assert_response :success

      patch public_send("base_#{domain[:name]}_preference_region_url", state),
            params: { preference_region: { option_id: "JP" } }

      assert_response :redirect

      location = URI.parse(response.headers.fetch("Location"))
      query = Rack::Utils.parse_query(location.query)

      assert_nil query["ri"]
      assert_not query.key?("lx")

      pref.reload

      assert_equal PreferenceClassRegistry.option_class(domain[:name].camelize, :region)::JP,
                   pref.try("#{domain[:name]}_preference_region").option_id
      assert_equal PreferenceClassRegistry.option_class(domain[:name].camelize, :language)::JA,
                   pref.try("#{domain[:name]}_preference_language").option_id
    end

    test "#{domain[:name]} domain region edit and update do not change preference count" do
      host!(domain[:host])
      pref, = assert_preference_created(domain)
      state = default_state.merge(ri: "us")

      assert_no_difference -> { domain[:preference_model].count } do
        get public_send("edit_base_#{domain[:name]}_preference_region_url", state)

        assert_response :success

        patch public_send("base_#{domain[:name]}_preference_region_url", state),
              params: { preference_region: { option_id: "US" } }

        assert_response :redirect
        assert_equal(
          URI.parse(public_send("edit_base_#{domain[:name]}_preference_region_url")).path,
          URI.parse(response.location).path,
        )
      end

      pref.reload

      assert_equal 1, pref.try("#{domain[:name]}_preference_region").option_id
      assert_equal PreferenceClassRegistry.option_class(domain[:name].camelize, :language)::EN,
                   pref.try("#{domain[:name]}_preference_language").option_id
    end

    test "#{domain[:name]} domain region edit renders a submit button inside the form" do
      host!(domain[:host])

      get public_send("edit_base_#{domain[:name]}_preference_region_url", default_state)

      assert_response :success
      assert_select "form" do
        assert_select "input[type='submit']", count: 1
      end
    end

    test "#{domain[:name]} domain updates timezone" do
      host!(domain[:host])
      pref, = assert_preference_created(domain)

      state = default_state.merge(tz: "etc/utc")
      update_option_id = "Etc/UTC"

      assert_preference_update(
        domain,
        :timezone,
        { preference_timezone: { option_id: update_option_id } },
        state,
      )

      pref.reload

      assert_equal 1, pref.try("#{domain[:name]}_preference_timezone").option_id
    end

    test "#{domain[:name]} domain timezone edit and update do not change preference count" do
      host!(domain[:host])
      pref, = assert_preference_created(domain)
      state = default_state.merge(tz: "etc/utc")

      assert_no_difference -> { domain[:preference_model].count } do
        get public_send("edit_base_#{domain[:name]}_preference_timezone_url", state)

        assert_response :success

        patch public_send("base_#{domain[:name]}_preference_timezone_url", state),
              params: { preference_timezone: { option_id: "Etc/UTC" } }

        assert_redirected_to public_send(
          "edit_base_#{domain[:name]}_preference_timezone_url",
          default_state.merge(tz: nil),
        )
      end

      pref.reload

      assert_equal 1, pref.try("#{domain[:name]}_preference_timezone").option_id
    end

    test "#{domain[:name]} domain timezone update removes only timezone overlay from redirect" do
      host!(domain[:host])

      assert_preference_created(domain)

      state = default_state.merge(lx: "en", tz: "Asia/Tokyo")

      patch public_send("base_#{domain[:name]}_preference_timezone_url", state),
            params: { preference_timezone: { option_id: "Pacific/Honolulu" } }

      location = URI.parse(response.headers.fetch("Location"))
      query = Rack::Utils.parse_query(location.query)

      assert_equal "/preference/timezone/edit", location.path
      assert_equal "jp", query["ri"]
      assert_equal "en", query["lx"]
      assert_not query.key?("tz")
    end

    test "#{domain[:name]} domain updates language" do
      host!(domain[:host])
      pref, = assert_preference_created(domain)

      state = default_state.merge(lx: "en")

      assert_preference_update(
        domain,
        :language,
        { preference_language: { option_id: "EN" } },
        state,
      )

      pref.reload

      assert_equal 2, pref.try("#{domain[:name]}_preference_language").option_id
    end

    test "#{domain[:name]} domain language edit and update do not change preference count" do
      host!(domain[:host])
      pref, = assert_preference_created(domain)
      state = default_state.merge(lx: "en")

      assert_no_difference -> { domain[:preference_model].count } do
        get public_send("edit_base_#{domain[:name]}_preference_language_url", state)

        assert_response :success

        patch public_send("base_#{domain[:name]}_preference_language_url", state),
              params: { preference_language: { option_id: "EN" } }

        assert_redirected_to public_send(
          "edit_base_#{domain[:name]}_preference_language_url",
          default_state.merge(lx: nil),
        )
      end

      pref.reload

      assert_equal 2, pref.try("#{domain[:name]}_preference_language").option_id
    end

    test "#{domain[:name]} domain applies language setting to locale" do
      host!(domain[:host])

      assert_preference_created(domain)

      # Update language to English
      state = default_state.merge(lx: "en")
      patch public_send("base_#{domain[:name]}_preference_language_url", state),
            params: { preference_language: { option_id: "EN" } }

      # Visit a page without language param to verify DB preference is applied
      get public_send("base_#{domain[:name]}_preference_url", ri: "jp")

      assert_response :success

      # Check that the locale was set to English
      assert_equal :en, I18n.locale
      # Verify the page content is in English
      translation_key = "acme.#{domain[:name]}.preferences.title"
      english_title = I18n.t(translation_key, locale: :en)

      assert_select "h1", text: english_title

      # Update language to Japanese
      state = default_state.merge(lx: "ja")
      patch public_send("base_#{domain[:name]}_preference_language_url", state),
            params: { preference_language: { option_id: "JA" } }

      # Visit a page without language param to verify DB preference is applied
      get public_send("base_#{domain[:name]}_preference_url", ri: "jp")

      assert_response :success

      # Check that the locale was set to Japanese
      assert_equal :ja, I18n.locale
      # Verify the page content is in Japanese
      japanese_title = I18n.t(translation_key, locale: :ja)

      assert_select "h1", text: japanese_title

      # Verify the translations are actually different
      assert_not_equal english_title, japanese_title
    end

    test "#{domain[:name]} domain language edit ignores lx overlay so page matches the selected option" do
      host!(domain[:host])

      assert_preference_created(domain)

      # Saved language is the default (ja). Open the language settings screen with
      # a transient ?lx=en overlay. The page must render in the *saved* language so
      # the displayed language matches the option pre-selected in the form, instead
      # of showing an English page with the Japanese option selected.
      get public_send("edit_base_#{domain[:name]}_preference_language_url", default_state.merge(lx: "en"))

      assert_response :success
      assert_equal :ja, I18n.locale

      # The selector's selected option is the saved language option (JA = 1).
      option_class = PreferenceClassRegistry.option_class(domain[:name].camelize, :language)

      assert_select "select[name=?] option[selected][value=?]",
                    "preference_language[option_id]",
                    option_class::JA.to_s
    end

    test "#{domain[:name]} domain falls back to Japanese when lx invalid" do
      host!(domain[:host])

      get public_send("base_#{domain[:name]}_preference_url", ri: "jp", lx: "ex")
      follow_redirect! if response.redirect?

      assert_response :success
      assert_equal :ja, I18n.locale
    end

    test "#{domain[:name]} domain applies timezone setting to Time.zone" do
      host!(domain[:host])

      assert_preference_created(domain)

      # Update timezone to UTC
      state = default_state.merge(tz: "etc/utc")
      patch public_send("base_#{domain[:name]}_preference_timezone_url", state),
            params: { preference_timezone: { option_id: "Etc/UTC" } }

      # Visit a page to verify DB preference is applied to Time.zone
      get public_send("edit_base_#{domain[:name]}_preference_timezone_url", default_state)

      assert_response :success
      assert_equal "Etc/UTC", Time.zone.name

      # Update timezone to Asia/Tokyo
      state = default_state.merge(tz: "asia/tokyo")
      patch public_send("base_#{domain[:name]}_preference_timezone_url", state),
            params: { preference_timezone: { option_id: "Asia/Tokyo" } }

      # Visit a page to verify DB preference is applied to Time.zone
      get public_send("edit_base_#{domain[:name]}_preference_timezone_url", default_state)

      assert_response :success
      assert_equal "Asia/Tokyo", Time.zone.name
    end

    test "#{domain[:name]} domain redirects timezone edit with updated tz when request omits tz" do
      host!(domain[:host])

      pref, = assert_preference_created(domain)

      patch public_send("base_#{domain[:name]}_preference_timezone_url", ri: "us"),
            params: { preference_timezone: { option_id: "Etc/UTC" } }

      assert_redirected_to public_send(
        "edit_base_#{domain[:name]}_preference_timezone_url",
        ri: "us",
      )
      follow_redirect!

      assert_select "select[name='preference_timezone[option_id]'] option[selected='selected'][value='1']"

      pref.reload

      assert_equal 1, pref.try("#{domain[:name]}_preference_timezone").option_id
    end

    test "#{domain[:name]} domain language select uses localized options" do
      host!(domain[:host])
      get public_send("edit_base_#{domain[:name]}_preference_language_url", default_state)

      # Acme renders language option names in the current page locale.
      assert_select "select[name='preference_language[option_id]']" do
        ja_key = "acme.#{domain[:name]}.preference.language.options.ja"
        en_key = "acme.#{domain[:name]}.preference.language.options.en"

        assert_select "option[value='1']", text: I18n.t(ja_key)
        assert_select "option[value='2']", text: I18n.t(en_key)
      end

      assert_select "select[name='preference_language[option_id]'] option", text: "日本語"
      assert_select "select[name='preference_language[option_id]'] option", text: "英語 - English"

      reset!
      host!(domain[:host])
      get public_send("edit_base_#{domain[:name]}_preference_language_url", ri: "us")

      assert_response :success
      assert_select "html[lang='en']"
      assert_select "select[name='preference_language[option_id]'] option", text: "Japanese - 日本語"
      assert_select "select[name='preference_language[option_id]'] option", text: "English"
    end

    test "#{domain[:name]} domain updates theme" do
      host!(domain[:host])
      pref, = assert_preference_created(domain)

      state = default_state

      assert_preference_update(
        domain,
        :theme,
        { preference_theme: { option_id: "dr" } },
        state,
      )

      assert_select(
        "select[name='preference_theme[option_id]'] option[selected='selected'][value='2']",
        count: 1,
      )

      pref.reload

      assert_equal 2, pref.try("#{domain[:name]}_preference_theme").option_id
    end

    test "#{domain[:name]} domain theme edit and update do not change preference count" do
      host!(domain[:host])
      pref, = assert_preference_created(domain)
      state = default_state

      assert_no_difference -> { domain[:preference_model].count } do
        get public_send("edit_base_#{domain[:name]}_preference_theme_url", state)

        assert_response :success

        patch public_send("base_#{domain[:name]}_preference_theme_url", state),
              params: { preference_theme: { option_id: "dr" } }

        assert_redirected_to public_send("edit_base_#{domain[:name]}_preference_theme_url", state)
      end

      pref.reload

      assert_equal 2, pref.try("#{domain[:name]}_preference_theme").option_id
    end

    test "#{domain[:name]} domain timezone select omits blank option" do
      host!(domain[:host])
      get public_send("edit_base_#{domain[:name]}_preference_timezone_url", default_state)

      assert_select "select[name='preference_timezone[option_id]'] option[value='']", count: 0
    end

    test "#{domain[:name]} domain updates cookie" do
      host!(domain[:host])
      pref, = assert_preference_created(domain)

      assert_preference_update(
        domain,
        :cookie,
        { preference_cookie: { functional: "1" } },
        default_state,
      )

      assert_select "input[type='checkbox'][name='preference_cookie[functional]'][checked='checked']", count: 1

      pref.reload

      assert pref.try("#{domain[:name]}_preference_cookie").functional
    end

    test "#{domain[:name]} domain cookie edit and update do not change preference count" do
      host!(domain[:host])
      pref, = assert_preference_created(domain)
      state = default_state

      assert_no_difference -> { domain[:preference_model].count } do
        get public_send("edit_base_#{domain[:name]}_preference_cookie_url", state)

        assert_response :success

        patch public_send("base_#{domain[:name]}_preference_cookie_url", state),
              params: { preference_cookie: { functional: "1", performant: "0", targetable: "0" } }

        assert_redirected_to public_send("edit_base_#{domain[:name]}_preference_cookie_url", state)
      end

      pref.reload

      assert pref.try("#{domain[:name]}_preference_cookie").functional
    end

    test "#{domain[:name]} domain resets preferences" do
      host!(domain[:host])
      pref, old_token, cookie_name = assert_preference_created(domain)

      get public_send("edit_base_#{domain[:name]}_preference_reset_url", default_state)

      assert_response :success

      delete(
        public_send("base_#{domain[:name]}_preference_reset_url", ri: "jp"),
        params: { confirm_reset: "1" },
      )

      assert_response :see_other
      assert_equal public_send("base_#{domain[:name]}_preference_url"), response.location

      assert_nil flash[:notice]

      pref.reload

      assert_equal preference_status_class(domain)::DELETED, pref.status_id
      assert_operator pref.discarded_at, :<=, Time.current
      assert_not_equal old_token, cookies[cookie_name]
      assert_not_equal pref.id, find_preference_by_refresh_token(domain, cookies[cookie_name]).id
    end

    test "#{domain[:name]} domain reset edit and destroy rebootstrap preference state" do
      host!(domain[:host])
      pref, = assert_preference_created(domain)
      state = default_state.merge(ri: "us")

      assert_difference -> { domain[:preference_model].count }, 1 do
        get public_send("edit_base_#{domain[:name]}_preference_reset_url", state)

        assert_response :success

        delete(
          public_send("base_#{domain[:name]}_preference_reset_url", state),
          params: { confirm_reset: "1" },
        )

        assert_response :see_other
        assert_equal public_send("base_#{domain[:name]}_preference_url"), response.location
      end

      pref.reload

      assert_equal preference_status_class(domain)::DELETED, pref.status_id
      assert_operator pref.discarded_at, :<=, Time.current
    end

    test "#{domain[:name]} domain creates a fresh preference after reset" do
      host!(domain[:host])
      pref, _token, cookie_name = assert_preference_created(domain)

      delete(
        public_send("base_#{domain[:name]}_preference_reset_url", ri: "jp"),
        params: { confirm_reset: "1" },
      )

      new_pref = find_preference_by_refresh_token(domain, cookies[cookie_name])

      assert_not_nil new_pref
      assert_not_equal pref.id, new_pref.id

      get public_send("base_#{domain[:name]}_preference_url")

      assert_response :redirect
      assert_equal public_send("base_#{domain[:name]}_preference_url", ri: "jp"), response.location

      pref.reload

      assert_equal preference_status_class(domain)::DELETED, pref.status_id
    end

    test "#{domain[:name]} domain surfaces localized timezone errors" do
      host!(domain[:host])
      state = { ri: "jp" }
      patch public_send("base_#{domain[:name]}_preference_timezone_url", state),
            params: { preference_timezone: { option_id: "Invalid/Zone" } }

      # Expect redirect back to edit with current params
      assert_redirected_to public_send("edit_base_#{domain[:name]}_preference_timezone_url", state)
      assert_nil flash[:alert]
    end

    test "#{domain[:name]} domain timezone edit links to region edit" do
      host!(domain[:host])

      get public_send("edit_base_#{domain[:name]}_preference_timezone_url", default_state)

      assert_response :success

      assert_select "a[href^=?]", public_send("edit_base_#{domain[:name]}_preference_region_path")
    end

    test "#{domain[:name]} domain language edit links to region edit" do
      host!(domain[:host])

      get public_send("edit_base_#{domain[:name]}_preference_language_url", default_state)

      assert_response :success

      links = css_select("section > div:first-child > a")

      assert_equal 1, links.size
      assert_equal "もどる", links.first.text
      assert_includes links.first["href"], public_send("edit_base_#{domain[:name]}_preference_region_path")
      assert_includes links.first["href"], "ri=jp"
    end

    test "#{domain[:name]} domain region edit links to timezone and language with params" do
      host!(domain[:host])
      state = { ri: "jp", lx: "ja" }

      get public_send("edit_base_#{domain[:name]}_preference_region_url", state)

      assert_response :success

      assert_select "a[href=?]",
                    public_send("edit_base_#{domain[:name]}_preference_timezone_path", state)
      assert_select "a[href=?]",
                    public_send("edit_base_#{domain[:name]}_preference_language_path", state)
    end

    if domain[:name] == "app"
      test "app domain currency edit renders localized currency names with code suffixes" do
        host!(domain[:host])
        state = { ri: "jp", lx: "ja" }

        get edit_base_app_preference_currency_url(state)

        assert_response :success
        assert_select "select[name='preference_currency[option_id]'] option", text: "米国ドル (USD)"
        assert_select "select[name='preference_currency[option_id]'] option", text: "日本円 (JPY)"
      end
    end

    test "#{domain[:name]} domain updates extended preference options" do
      host!(domain[:host])
      pref, = assert_preference_created(domain)

      Prosopite.pause do
        [
          [:currency, :preference_currency, :currency, "usd", 1],
          [:calendar, :preference_date_format, :date_format, "uk", 2],
          [:clock, :preference_time_format, :time_format, "2", 2],
          [:motion, :preference_motion, :motion, "reduced", 2],
          [:density, :preference_density, :density, "compact", 2],
          [:pagination, :preference_page_size, :page_size, "50", 3],
        ].each do |route_suffix, param_scope, association_suffix, submitted_value, expected_id|
          get public_send("edit_base_#{domain[:name]}_preference_#{route_suffix}_url", default_state)

          assert_response :success
          assert_select "select[name='#{param_scope}[option_id]'] option[value='']", count: 0

          patch public_send("base_#{domain[:name]}_preference_#{route_suffix}_url", default_state),
                params: { param_scope => { option_id: submitted_value } }

          assert_redirected_to public_send("edit_base_#{domain[:name]}_preference_#{route_suffix}_url", default_state)

          pref.reload

          assert_equal expected_id, pref.public_send("#{domain[:name]}_preference_#{association_suffix}").option_id
          get public_send("edit_base_#{domain[:name]}_preference_#{route_suffix}_url", default_state)

          assert_select "select[name='#{param_scope}[option_id]'] option[selected='selected'][value='#{expected_id}']",
                        count: 1
        end
      end
    end
  end

  test "org extended region preference edit pages show top localized back link" do
    host!(DOMAINS.second[:host])

    assert_preference_created(DOMAINS.second)
    state = { ri: "us", lx: "ja" }

    [
      edit_base_org_preference_currency_url(state),
      edit_base_org_preference_calendar_url(state),
      edit_base_org_preference_clock_url(state),
    ].each do |url|
      get url

      assert_response :success
      links = css_select("section > div:first-child > a")

      assert_equal 1, links.size
      assert_equal "もどる", links.first.text
      assert_includes links.first["href"], edit_base_org_preference_region_path
      assert_includes links.first["href"], "ri=us"
      assert_includes links.first["href"], "lx=ja"
    end
  end

  test "app extended display and accessibility preference edit pages allow signed-in clients" do
    host!(DOMAINS.first[:host])
    user = clients(:one)
    headers = as_user_headers(user, host: DOMAINS.first[:host])

    [
      edit_base_app_preference_motion_url(ri: "jp"),
      edit_base_app_preference_density_url(ri: "jp"),
      edit_base_app_preference_pagination_url(ri: "jp"),
    ].each do |url|
      get url, headers: headers

      assert_response :success
      assert_not_equal base_app_dashboard_path, URI.parse(request.path).path
    end

    [
      edit_base_app_preference_motion_url(ri: "jp"),
      edit_base_app_preference_density_url(ri: "jp"),
    ].each do |url|
      get url, headers: headers

      links = css_select("section > div:first-child > a")

      assert_equal 1, links.size
      assert_equal "もどる", links.first.text
      assert_includes links.first["href"], base_app_preference_path
      assert_includes links.first["href"], "ri=jp"
    end
  end

  test "app extended region preference edit pages do not write missing child records" do
    host!(DOMAINS.first[:host])
    pref, = assert_preference_created(DOMAINS.first)

    Prosopite.pause do
      [
        [:app_preference_currency, edit_base_app_preference_currency_url(ri: "jp")],
        [:app_preference_date_format, edit_base_app_preference_calendar_url(ri: "jp")],
        [:app_preference_time_format, edit_base_app_preference_clock_url(ri: "jp")],
      ].each do |association, url|
        pref.public_send(association).destroy!
        pref.reload

        assert_nil pref.public_send(association)

        get url

        assert_response :success
        pref.reload

        assert_nil pref.public_send(association)
      end
    end
  end

  DOMAINS.each do |domain|
    test "#{domain[:name]} domain reset edit page has confirmation checkbox" do
      host!(domain[:host])

      assert_preference_created(domain)

      get public_send("edit_base_#{domain[:name]}_preference_reset_url", ri: "jp")

      assert_response :success

      links = css_select("section > div:first-child > a")

      assert_equal 1, links.size
      assert_equal "もどる", links.first.text
      assert_includes links.first["href"], public_send("base_#{domain[:name]}_preference_path")
      assert_includes links.first["href"], "ri=jp"
      assert_select "a", text: I18n.t(["acme", domain[:name], "preference.resets.back"].join(".")), count: 0
      assert_select "input[type='checkbox'][name='confirm_reset'][required]"
      assert_select "label[for='confirm_reset']"
    end

    test "#{domain[:name]} domain reset destroy resets preference to defaults" do
      host!(domain[:host])
      pref, _token, _cookie_name = assert_preference_created(domain)
      audit_class = domain[:audit_class]

      # Record initial state
      initial_audit_count = audit_class.where(subject_id: pref.id).count

      # Submit reset form with confirmation
      delete(
        public_send("base_#{domain[:name]}_preference_reset_url", ri: "jp"),
        params: { confirm_reset: "1" },
      )

      assert_response :see_other
      assert_equal public_send("base_#{domain[:name]}_preference_url"), response.location

      # Verify database changes; the old preference is retired and a fresh one is issued.
      pref.reload
      final_audit_count = audit_class.where(subject_id: pref.id).count

      assert_equal preference_status_class(domain)::DELETED, pref.status_id
      assert_operator final_audit_count, :>, initial_audit_count,
                      "Audit log should be created"

      # Verify audit log event
      event_class = domain[:audit_event_class]
      reset_audit = audit_class.where(subject_id: pref.id, event_id: event_class::RESET_BY_USER_DECISION)

      assert_predicate reset_audit, :exists?
    end

    test "#{domain[:name]} domain reset destroy replaces preference cookies and clears request context" do
      host!(domain[:host])
      _pref, old_token, cookie_name = assert_preference_created(domain)

      cookies[PreferenceBase::THEME_COOKIE_KEY] = "dr"
      cookies[PreferenceBase::LANGUAGE_COOKIE_KEY] = "en"
      cookies[PreferenceBase::TIMEZONE_COOKIE_KEY] = "etc/utc"

      delete(
        public_send("base_#{domain[:name]}_preference_reset_url", ri: "jp"),
        params: { confirm_reset: "1" },
      )

      assert_not_nil cookies[cookie_name], "Preference refresh cookie should be reissued after reset"
      assert_not_equal old_token, cookies[cookie_name]
      assert_not_equal "dr", cookies[PreferenceBase::THEME_COOKIE_KEY]
      assert_not_equal "en", cookies[PreferenceBase::LANGUAGE_COOKIE_KEY]
      assert_not_equal "etc/utc", cookies[PreferenceBase::TIMEZONE_COOKIE_KEY]
    end

    test "#{domain[:name]} domain reset destroy fails without confirmation" do
      host!(domain[:host])
      pref, _token, cookie_name = assert_preference_created(domain)

      # Submit reset form WITHOUT confirmation
      delete(
        public_send("base_#{domain[:name]}_preference_reset_url", ri: "jp"),
        params: { confirm_reset: "0" },
      )

      # Should render edit with unprocessable_content status
      assert_response :unprocessable_content

      # Verify database is unchanged
      pref.reload

      assert_includes [0, 2], pref.status_id, "Status should remain NOTHING"

      # Verify cookie is still present
      assert_not_nil cookies[cookie_name], "Cookie should still exist"
    end

    test "#{domain[:name]} domain reset logs database operations" do
      host!(domain[:host])
      _, _token, _cookie_name = assert_preference_created(domain)
      domain[:audit_class]

      # Capture SQL queries
      queries = []
      callback = ->(event) { queries << event.payload[:sql] }
      ActiveSupport::Notifications.subscribe("sql.active_record", callback)

      begin
        delete(
          public_send("base_#{domain[:name]}_preference_reset_url", ri: "jp"),
          params: { confirm_reset: "1" },
        )
      ensure
        ActiveSupport::Notifications.unsubscribe(callback)
      end

      # Verify INSERT query was executed on chronicle table (audit log)
      insert_queries = queries.select { |q| q.include?("INSERT") && q.include?("chronicl") }

      assert_not_empty insert_queries, "Should have INSERT query on chronicle table"
    end
  end

  private

  def preference_refresh_cookie_name(domain)
    PreferenceCookieName.refresh(production: false, surface: domain[:name].to_sym)
  end

  def preference_access_cookie_name(domain)
    PreferenceCookieName.access(production: false, surface: domain[:name].to_sym)
  end

  def preference_status_class(domain)
    "#{domain[:preference_model].name}Status".constantize
  end

  def default_state
    { ri: "jp" }
  end

  def assert_preference_created(domain, state = { ri: "jp" })
    get(public_send("edit_base_#{domain[:name]}_preference_region_url", state))

    assert_response :success

    cookie_name = preference_refresh_cookie_name(domain)
    token = cookies[cookie_name]

    assert_not_nil token
    token_digest = refresh_token_digest_for(token)
    pref =
      domain[:preference_model].superclass.connected_to(role: :writing) do
        domain[:preference_model].find_by(token_digest: token_digest)
      end
    if pref.nil?
      access_cookie_name = preference_access_cookie_name(domain)
      access_token = cookies[access_cookie_name]
      payload = access_token && PreferenceToken.decode(access_token, host: domain[:host])
      pref =
        domain[:preference_model].superclass.connected_to(role: :writing) do
          domain[:preference_model].find_by(public_id: payload&.dig("public_id")) ||
            domain[:preference_model].order(created_at: :desc).first
        end
    end

    assert_not_nil pref
    [pref, token, cookie_name]
  end

  def find_preference_by_refresh_token(domain, token)
    token_digest = refresh_token_digest_for(token)
    return if token_digest.blank?

    domain[:preference_model].superclass.connected_to(role: :writing) do
      domain[:preference_model].find_by(token_digest: token_digest)
    end
  end

  def refresh_token_digest_for(token)
    return nil if token.blank?

    verifier = token.include?(".") ? token.split(".", 2).last : token
    SHA3::Digest::SHA3_384.digest(verifier)
  end

  def assert_preference_update(domain, kind, params, state)
    suffix = preference_route_suffix(kind)
    get(public_send("edit_base_#{domain[:name]}_preference_#{suffix}_url", state))

    assert_response :success

    patch(public_send("base_#{domain[:name]}_preference_#{suffix}_url", state), params: params)

    assert_preference_redirected_to_edit(domain, suffix, kind, state, params)
    follow_redirect!

    assert_nil flash[:notice]
  end

  def preference_route_suffix(kind)
    case kind
    when :date_format
      "date"
    when :time_format
      "time"
    when :density
      "density"
    else
      kind.to_s
    end
  end

  def preference_write_redirect_state(kind, state, _params = {})
    if kind == :region
      return {}
    end

    state.slice(:ri).merge(preference_context_key_for_kind(kind) => nil)
  end

  def assert_preference_redirected_to_edit(domain, suffix, kind, state, params)
    expected = public_send(
      "edit_base_#{domain[:name]}_preference_#{suffix}_url",
      preference_write_redirect_state(kind, state, params),
    )
    return assert_redirected_to(expected) unless kind == :region

    assert_response :redirect
    assert_equal URI.parse(expected).path, URI.parse(response.location).path
  end

  def preference_context_key_for_kind(kind)
    {
      language: :lx,
      timezone: :tz,
      theme: :ct,
      currency: :cu,
      date_format: :df,
      time_format: :tf,
      motion: :mo,
      density: :dn,
      page_size: :ps,
    }[kind]
  end
  private

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "X-CSRF-Token" => csrf_token,
    }

    if respond_to?(:cookies, true)
      cookies["csrf_token"] = csrf_token
    else
      headers["Cookie"] = "csrf_token=#{csrf_token}"
    end

    headers
  end

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-USER" => user.id.to_s)
    return base unless user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"

    token =
      if session_public_id.present?
        ClientToken.find_by(public_id: session_public_id)
      else
        ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
      end
    token ||= ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client")
      }",
    )
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)
    return base unless staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"

    token =
      if session_public_id.present?
        OperatorToken.find_by(public_id: session_public_id)
      else
        OperatorToken.where(staff_id: staff.id).where(
          "discarded_at > ?",
          Time.current,
        ).order(created_at: :desc).first
      end
    token ||= OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(staff, host: host, session_public_id: token.public_id, resource_type: "operator")
      }",
    )
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    VisitorTokenBindingMethod.ensure_defaults! if defined?(VisitorTokenBindingMethod)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB) if defined?(VisitorTokenKind)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)
    return base unless visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"

    token =
      if session_public_id.present?
        VisitorToken.find_by(public_id: session_public_id)
      else
        VisitorToken.where(visitor_id: visitor.id).where(
          "discarded_at > ?",
          Time.current,
        ).order(created_at: :desc).first
      end
    token ||= VisitorToken.create!(visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(visitor, host: host, session_public_id: token.public_id, resource_type: "visitor")
      }",
    )
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def jwt_access_token_for(resource, host: nil, session_id: nil, session_public_id: nil, resource_type: nil,
                           dpop_jkt: nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || "unknown"
    resource_type ||=
      case resource
      when Client then "client"
      when Operator then "operator"
      when Visitor then "visitor"
      end
    AuthenticationToken.encode(
      resource,
      host: host_value,
      session_id: session_id,
      session_public_id: session_public_id,
      resource_type: resource_type,
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: jwt_issuer_id_for_test_host(host_value, resource_type),
    )
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    base_hosts = {
      "APP" => ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
      "ORG" => ENV.fetch("PRIVATE_BASE_STAFF_URL", "base.org.localhost"),
      "COM" => ENV.fetch("PRIVATE_BASE_CORPORATE_URL", "base.com.localhost"),
    }
    return "surface:BASE_#{base_hosts.key(normalized)}" if base_hosts.value?(normalized)

    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "SIGN")
    surface =
      if service == "SIGN"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end
end

# DAMP auth header helpers for this test class.
class AcmePreferenceTest
  private

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "X-CSRF-Token" => csrf_token,
    }

    if respond_to?(:cookies, true)
      cookies["csrf_token"] = csrf_token
    else
      headers["Cookie"] = "csrf_token=#{csrf_token}"
    end

    headers
  end

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-USER" => user.id.to_s)
    return base unless user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"

    token =
      if session_public_id.present?
        ClientToken.find_by(public_id: session_public_id)
      else
        ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
      end
    token ||= ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client")
      }",
    )
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)
    return base unless staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"

    token =
      if session_public_id.present?
        OperatorToken.find_by(public_id: session_public_id)
      else
        OperatorToken.where(staff_id: staff.id).where(
          "discarded_at > ?",
          Time.current,
        ).order(created_at: :desc).first
      end
    token ||= OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(staff, host: host, session_public_id: token.public_id, resource_type: "operator")
      }",
    )
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    VisitorTokenBindingMethod.ensure_defaults! if defined?(VisitorTokenBindingMethod)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB) if defined?(VisitorTokenKind)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)
    return base unless visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"

    token =
      if session_public_id.present?
        VisitorToken.find_by(public_id: session_public_id)
      else
        VisitorToken.where(visitor_id: visitor.id).where(
          "discarded_at > ?",
          Time.current,
        ).order(created_at: :desc).first
      end
    token ||= VisitorToken.create!(visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(visitor, host: host, session_public_id: token.public_id, resource_type: "visitor")
      }",
    )
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end
