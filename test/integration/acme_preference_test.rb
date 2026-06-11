# typed: false
# frozen_string_literal: true

require "test_helper"
require "sha3"

class AcmePreferenceTest < ActionDispatch::IntegrationTest
  setup do
    https!
  end

  DOMAINS = [
    {
      name: "app",
      host: ENV.fetch("ACME_SERVICE_URL", "www.umaxica.app"),
      scope: "acme.app.preferences",
      preference_model: AppPreference,
      audit_class: AppPreferenceChronicle,
      audit_event_class: AppPreferenceChronicleEvent,
    },
    {
      name: "org",
      host: ENV.fetch("ACME_STAFF_URL", "www.umaxica.org"),
      scope: "acme.org.preferences",
      preference_model: OrgPreference,
      audit_class: OrgPreferenceChronicle,
      audit_event_class: OrgPreferenceChronicleEvent,
    },
    {
      name: "com",
      host: ENV.fetch("ACME_CORPORATE_URL", "www.umaxica.com"),
      scope: "acme.com.preferences",
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
    end

    test "#{domain[:name]} domain redirects to add ri param when missing" do
      host!(domain[:host])

      # Visit URL without ri parameter
      get public_send("acme_#{domain[:name]}_preference_url")

      # Should redirect to include ri=jp
      assert_redirected_to public_send("acme_#{domain[:name]}_preference_url", ri: "jp")
    end

    test "#{domain[:name]} domain does not redirect when ri param present" do
      host!(domain[:host])

      # Visit URL with ri parameter
      get public_send("acme_#{domain[:name]}_preference_url", ri: "us")

      # Should not redirect
      assert_response :success
    end

    test "#{domain[:name]} domain respects lx param for locale" do
      host!(domain[:host])

      # Visit URL with lx=en and ri=us
      get public_send("edit_acme_#{domain[:name]}_preference_cookie_url", lx: "en", ri: "us")

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
    end

    test "#{domain[:name]} domain region edit and update do not change preference count" do
      host!(domain[:host])
      pref, = assert_preference_created(domain)
      state = default_state.merge(ri: "us")

      assert_no_difference -> { domain[:preference_model].count } do
        get public_send("edit_acme_#{domain[:name]}_preference_region_url", state)

        assert_response :success

        patch public_send("acme_#{domain[:name]}_preference_region_url", state),
              params: { preference_region: { option_id: "US" } }

        assert_redirected_to public_send("edit_acme_#{domain[:name]}_preference_region_url", state)
      end

      pref.reload

      assert_equal 1, pref.try("#{domain[:name]}_preference_region").option_id
    end

    test "#{domain[:name]} domain region edit renders a submit button inside the form" do
      host!(domain[:host])

      get public_send("edit_acme_#{domain[:name]}_preference_region_url", default_state)

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
        get public_send("edit_acme_#{domain[:name]}_preference_timezone_url", state)

        assert_response :success

        patch public_send("acme_#{domain[:name]}_preference_timezone_url", state),
              params: { preference_timezone: { option_id: "Etc/UTC" } }

        assert_redirected_to public_send(
          "edit_acme_#{domain[:name]}_preference_timezone_url",
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

      patch public_send("acme_#{domain[:name]}_preference_timezone_url", state),
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
        get public_send("edit_acme_#{domain[:name]}_preference_language_url", state)

        assert_response :success

        patch public_send("acme_#{domain[:name]}_preference_language_url", state),
              params: { preference_language: { option_id: "EN" } }

        assert_redirected_to public_send(
          "edit_acme_#{domain[:name]}_preference_language_url",
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
      patch public_send("acme_#{domain[:name]}_preference_language_url", state),
            params: { preference_language: { option_id: "EN" } }

      # Visit a page without language param to verify DB preference is applied
      get public_send("acme_#{domain[:name]}_preference_url", ri: "jp")

      assert_response :success

      # Check that the locale was set to English
      assert_equal :en, I18n.locale
      # Verify the page content is in English
      translation_key = "acme.#{domain[:name]}.preferences.title"
      english_title = I18n.t(translation_key, locale: :en)

      assert_select "h1", text: english_title

      # Update language to Japanese
      state = default_state.merge(lx: "ja")
      patch public_send("acme_#{domain[:name]}_preference_language_url", state),
            params: { preference_language: { option_id: "JA" } }

      # Visit a page without language param to verify DB preference is applied
      get public_send("acme_#{domain[:name]}_preference_url", ri: "jp")

      assert_response :success

      # Check that the locale was set to Japanese
      assert_equal :ja, I18n.locale
      # Verify the page content is in Japanese
      japanese_title = I18n.t(translation_key, locale: :ja)

      assert_select "h1", text: japanese_title

      # Verify the translations are actually different
      assert_not_equal english_title, japanese_title
    end

    test "#{domain[:name]} domain falls back to Japanese when lx invalid" do
      host!(domain[:host])

      get public_send("acme_#{domain[:name]}_preference_url", ri: "jp", lx: "ex")
      follow_redirect! if response.redirect?

      assert_response :success
      assert_equal :ja, I18n.locale
    end

    test "#{domain[:name]} domain applies timezone setting to Time.zone" do
      host!(domain[:host])

      assert_preference_created(domain)

      # Update timezone to UTC
      state = default_state.merge(tz: "etc/utc")
      patch public_send("acme_#{domain[:name]}_preference_timezone_url", state),
            params: { preference_timezone: { option_id: "Etc/UTC" } }

      # Visit a page to verify DB preference is applied to Time.zone
      get public_send("edit_acme_#{domain[:name]}_preference_timezone_url", default_state)

      assert_response :success
      assert_equal "Etc/UTC", Time.zone.name

      # Update timezone to Asia/Tokyo
      state = default_state.merge(tz: "asia/tokyo")
      patch public_send("acme_#{domain[:name]}_preference_timezone_url", state),
            params: { preference_timezone: { option_id: "Asia/Tokyo" } }

      # Visit a page to verify DB preference is applied to Time.zone
      get public_send("edit_acme_#{domain[:name]}_preference_timezone_url", default_state)

      assert_response :success
      assert_equal "Asia/Tokyo", Time.zone.name
    end

    test "#{domain[:name]} domain redirects timezone edit with updated tz when request omits tz" do
      host!(domain[:host])

      pref, = assert_preference_created(domain)

      patch public_send("acme_#{domain[:name]}_preference_timezone_url", ri: "us"),
            params: { preference_timezone: { option_id: "Etc/UTC" } }

      assert_redirected_to public_send(
        "edit_acme_#{domain[:name]}_preference_timezone_url",
        ri: "us",
      )
      follow_redirect!

      assert_select "select[name='preference_timezone[option_id]'] option[selected='selected'][value='1']"

      pref.reload

      assert_equal 1, pref.try("#{domain[:name]}_preference_timezone").option_id
    end

    test "#{domain[:name]} domain language select uses localized options" do
      host!(domain[:host])
      get public_send("edit_acme_#{domain[:name]}_preference_language_url", default_state)

      # Acme renders the abbreviated locale codes for the language options.
      assert_select "select[name='preference_language[option_id]']" do
        assert_select "option[value='1']", text: "Ja"
        assert_select "option[value='2']", text: "En"
      end
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
        get public_send("edit_acme_#{domain[:name]}_preference_theme_url", state)

        assert_response :success

        patch public_send("acme_#{domain[:name]}_preference_theme_url", state),
              params: { preference_theme: { option_id: "dr" } }

        assert_redirected_to public_send("edit_acme_#{domain[:name]}_preference_theme_url", state)
      end

      pref.reload

      assert_equal 2, pref.try("#{domain[:name]}_preference_theme").option_id
    end

    test "#{domain[:name]} domain timezone select omits blank option" do
      host!(domain[:host])
      get public_send("edit_acme_#{domain[:name]}_preference_timezone_url", default_state)

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
        get public_send("edit_acme_#{domain[:name]}_preference_cookie_url", state)

        assert_response :success

        patch public_send("acme_#{domain[:name]}_preference_cookie_url", state),
              params: { preference_cookie: { functional: "1", performant: "0", targetable: "0" } }

        assert_redirected_to public_send("edit_acme_#{domain[:name]}_preference_cookie_url", state)
      end

      pref.reload

      assert pref.try("#{domain[:name]}_preference_cookie").functional
    end

    test "#{domain[:name]} domain resets preferences" do
      host!(domain[:host])
      pref, = assert_preference_created(domain)

      get public_send("edit_acme_#{domain[:name]}_preference_reset_url", default_state)

      assert_response :success

      delete(
        public_send("acme_#{domain[:name]}_preference_reset_url", ri: "jp"),
        params: { confirm_reset: "1" },
      )

      assert_response :see_other
      assert_equal public_send("acme_#{domain[:name]}_preference_url", ri: "jp"), response.location

      assert_equal I18n.t("acme." + domain[:name] + ".preference.resets.destroyed"), flash[:notice]

      pref.reload

      # Reset to defaults keeps the preference active (status stays NOTHING)
      assert_includes [0, 2], pref.status_id
      assert_not_nil pref.discarded_at
    end

    test "#{domain[:name]} domain reset edit and destroy do not change preference count" do
      host!(domain[:host])
      pref, = assert_preference_created(domain)
      state = default_state.merge(ri: "us")

      assert_no_difference -> { domain[:preference_model].count } do
        get public_send("edit_acme_#{domain[:name]}_preference_reset_url", state)

        assert_response :success

        delete(
          public_send("acme_#{domain[:name]}_preference_reset_url", state),
          params: { confirm_reset: "1" },
        )

        assert_response :see_other
        assert_equal public_send("acme_#{domain[:name]}_preference_url", ri: "us"), response.location
      end

      pref.reload

      assert_includes [0, 2], pref.status_id
      assert_not_nil pref.discarded_at
    end

    test "#{domain[:name]} domain keeps same preference after reset" do
      host!(domain[:host])
      pref, _token, cookie_name = assert_preference_created(domain)

      delete(
        public_send("acme_#{domain[:name]}_preference_reset_url", ri: "jp"),
        params: { confirm_reset: "1" },
      )

      get public_send("acme_#{domain[:name]}_preference_url", ri: "jp")

      assert_response :success

      # Reset to defaults keeps the same preference record and cookie
      current_token = cookies[cookie_name]

      assert_not_nil current_token

      pref.reload

      assert_includes [0, 2], pref.status_id
    end

    test "#{domain[:name]} domain surfaces localized timezone errors" do
      host!(domain[:host])
      state = { ri: "jp" }
      patch public_send("acme_#{domain[:name]}_preference_timezone_url", state),
            params: { preference_timezone: { option_id: "Invalid/Zone" } }

      # Expect redirect back to edit with current params
      assert_redirected_to public_send("edit_acme_#{domain[:name]}_preference_timezone_url", state)
      assert_equal I18n.t("errors.messages.preference_operation_failed"), flash[:alert]
    end

    test "#{domain[:name]} domain timezone edit links to region edit" do
      host!(domain[:host])

      get public_send("edit_acme_#{domain[:name]}_preference_timezone_url", default_state)

      assert_response :success

      assert_select "a[href^=?]", public_send("edit_acme_#{domain[:name]}_preference_region_path")
    end

    test "#{domain[:name]} domain language edit links to region edit" do
      host!(domain[:host])

      get public_send("edit_acme_#{domain[:name]}_preference_language_url", default_state)

      assert_response :success

      links = css_select("section > div:first-child > a")

      assert_equal 1, links.size
      assert_equal "もどる", links.first.text
      assert_includes links.first["href"], public_send("edit_acme_#{domain[:name]}_preference_region_path")
      assert_includes links.first["href"], "ri=jp"
    end

    test "#{domain[:name]} domain region edit links to timezone and language with params" do
      host!(domain[:host])
      state = { ri: "jp", lx: "ja" }

      get public_send("edit_acme_#{domain[:name]}_preference_region_url", state)

      assert_response :success

      assert_select "a[href=?]",
                    public_send("edit_acme_#{domain[:name]}_preference_timezone_path", state)
      assert_select "a[href=?]",
                    public_send("edit_acme_#{domain[:name]}_preference_language_path", state)
    end

    test "#{domain[:name]} domain updates extended preference options" do
      host!(domain[:host])
      pref, = assert_preference_created(domain)

      Prosopite.pause do
        [
          [:currency, :preference_currency, :currency, "usd", 1],
          [:date, :preference_date_format, :date_format, "uk", 2],
          [:time, :preference_time_format, :time_format, "hour_12", 2],
          [:motion, :preference_motion, :motion, "reduced", 2],
          [:density, :preference_density, :density, "compact", 2],
          [:page_size, :preference_page_size, :page_size, "50", 3],
        ].each do |route_suffix, param_scope, association_suffix, submitted_value, expected_id|
          get public_send("edit_acme_#{domain[:name]}_preference_#{route_suffix}_url", default_state)

          assert_response :success
          assert_select "select[name='#{param_scope}[option_id]'] option[value='']", count: 0

          patch public_send("acme_#{domain[:name]}_preference_#{route_suffix}_url", default_state),
                params: { param_scope => { option_id: submitted_value } }

          assert_redirected_to public_send("edit_acme_#{domain[:name]}_preference_#{route_suffix}_url", default_state)

          pref.reload

          assert_equal expected_id, pref.public_send("#{domain[:name]}_preference_#{association_suffix}").option_id
        end
      end
    end
  end

  test "org extended region preference edit pages show top localized back link" do
    host!(DOMAINS.second[:host])

    assert_preference_created(DOMAINS.second)
    state = { ri: "us", lx: "ja" }

    [
      edit_acme_org_preference_currency_url(state),
      edit_acme_org_preference_date_url(state),
      edit_acme_org_preference_time_url(state),
    ].each do |url|
      get url

      assert_response :success
      links = css_select("section > div:first-child > a")

      assert_equal 1, links.size
      assert_equal "もどる", links.first.text
      assert_includes links.first["href"], edit_acme_org_preference_region_path
      assert_includes links.first["href"], "ri=us"
      assert_includes links.first["href"], "lx=ja"
    end
  end

  test "app extended display and accessibility preference edit pages allow signed-in clients" do
    host!(DOMAINS.first[:host])
    user = clients(:one)
    headers = as_user_headers(user, host: DOMAINS.first[:host])

    [
      edit_acme_app_preference_motion_url(ri: "jp"),
      edit_acme_app_preference_density_url(ri: "jp"),
      edit_acme_app_preference_page_size_url(ri: "jp"),
    ].each do |url|
      get url, headers: headers

      assert_response :success
      assert_not_equal acme_app_dashboard_path, URI.parse(request.path).path
    end

    [
      edit_acme_app_preference_motion_url(ri: "jp"),
      edit_acme_app_preference_density_url(ri: "jp"),
    ].each do |url|
      get url, headers: headers

      links = css_select("section > div:first-child > a")

      assert_equal 1, links.size
      assert_equal "もどる", links.first.text
      assert_includes links.first["href"], acme_app_preference_path
      assert_includes links.first["href"], "ri=jp"
    end
  end

  test "app extended region preference edit pages do not write missing child records" do
    host!(DOMAINS.first[:host])
    pref, = assert_preference_created(DOMAINS.first)

    Prosopite.pause do
      [
        [:app_preference_currency, edit_acme_app_preference_currency_url(ri: "jp")],
        [:app_preference_date_format, edit_acme_app_preference_date_url(ri: "jp")],
        [:app_preference_time_format, edit_acme_app_preference_time_url(ri: "jp")],
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

      get public_send("edit_acme_#{domain[:name]}_preference_reset_url", ri: "jp")

      assert_response :success

      links = css_select("section > div:first-child > a")

      assert_equal 1, links.size
      assert_equal "もどる", links.first.text
      assert_includes links.first["href"], public_send("acme_#{domain[:name]}_preference_path")
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
        public_send("acme_#{domain[:name]}_preference_reset_url", ri: "jp"),
        params: { confirm_reset: "1" },
      )

      assert_response :see_other
      assert_equal public_send("acme_#{domain[:name]}_preference_url", ri: "jp"), response.location

      # Verify database changes; preference stays active after reset to defaults.
      pref.reload
      final_audit_count = audit_class.where(subject_id: pref.id).count

      # After reset, status should be a valid state (0 or 2)
      assert_includes [0, 2], pref.status_id, "Status should be NOTHING after reset to defaults"
      assert_operator final_audit_count, :>, initial_audit_count,
                      "Audit log should be created"

      # Verify audit log event
      event_class = domain[:audit_event_class]
      reset_audit = audit_class.where(subject_id: pref.id, event_id: event_class::RESET_BY_USER_DECISION)

      assert_predicate reset_audit, :exists?
    end

    test "#{domain[:name]} domain reset destroy keeps preference cookies" do
      host!(domain[:host])
      _pref, _token, cookie_name = assert_preference_created(domain)

      cookies[PreferenceBase::THEME_COOKIE_KEY] = "dr"
      cookies[PreferenceBase::LANGUAGE_COOKIE_KEY] = "en"
      cookies[PreferenceBase::TIMEZONE_COOKIE_KEY] = "etc/utc"

      delete(
        public_send("acme_#{domain[:name]}_preference_reset_url", ri: "jp"),
        params: { confirm_reset: "1" },
      )

      # Reset to defaults keeps cookies intact (values are reset in DB, not deleted)
      assert_not_nil cookies[cookie_name],
                     "Preference refresh cookie should be kept after reset"
    end

    test "#{domain[:name]} domain reset destroy fails without confirmation" do
      host!(domain[:host])
      pref, _token, cookie_name = assert_preference_created(domain)

      # Submit reset form WITHOUT confirmation
      delete(
        public_send("acme_#{domain[:name]}_preference_reset_url", ri: "jp"),
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
          public_send("acme_#{domain[:name]}_preference_reset_url", ri: "jp"),
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

  def default_state
    { ri: "jp" }
  end

  def assert_preference_created(domain)
    get(public_send("edit_acme_#{domain[:name]}_preference_region_url", ri: "jp"))

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

  def refresh_token_digest_for(token)
    return nil if token.blank?

    verifier = token.include?(".") ? token.split(".", 2).last : token
    SHA3::Digest::SHA3_384.digest(verifier)
  end

  def assert_preference_update(domain, kind, params, state)
    suffix = preference_route_suffix(kind)
    get(public_send("edit_acme_#{domain[:name]}_preference_#{suffix}_url", state))

    assert_response :success

    patch(public_send("acme_#{domain[:name]}_preference_#{suffix}_url", state), params: params)

    assert_redirected_to public_send(
      "edit_acme_#{domain[:name]}_preference_#{suffix}_url",
      preference_write_redirect_state(kind, state),
    )
    follow_redirect!

    expect_notice = true
    if expect_notice
      assert_includes(
        I18n.available_locales.map { |locale| I18n.t(domain[:scope] + ".update_success", locale: locale) },
        flash[:notice],
      )
    else
      assert_nil flash[:notice]
    end
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

  def preference_write_redirect_state(kind, state)
    return state if kind == :region

    state.slice(:ri).merge(preference_context_key_for_kind(kind) => nil)
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
end
