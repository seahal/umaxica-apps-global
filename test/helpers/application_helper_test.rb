# typed: false
# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ActiveSupport::Testing::TimeHelpers

  fixtures :client_banners, :operator_banners, :visitor_banners, :clients, :client_statuses, :operators,
           :operator_statuses, :visitors, :visitor_statuses, :visitor_visibilities, :visitor_mfa_levels,
           :visitor_mfa_statuses

  setup do
    extend ApplicationHelper
  end

  def stub_cookie(value)
    define_singleton_method(:cookies) { { "ct" => value } }
  end

  def stub_request_host(host)
    define_singleton_method(:request) { Struct.new(:host).new(host) }
  end

  def with_edge_env(overrides)
    keys = %w(EDGE_SERVICE_URL EDGE_STAFF_URL EDGE_CORPORATE_URL)
    previous = keys.index_with { |key| ENV[key] }

    overrides.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  test "theme_cookie_value maps short codes" do
    stub_cookie("dr")

    assert_equal "dark", theme_cookie_value

    stub_cookie("li")

    assert_equal "light", theme_cookie_value

    stub_cookie("sy")

    assert_equal "system", theme_cookie_value
  end

  test "theme_cookie_value accepts full names" do
    stub_cookie("dark")

    assert_equal "dark", theme_cookie_value

    stub_cookie("light")

    assert_equal "light", theme_cookie_value

    stub_cookie("system")

    assert_equal "system", theme_cookie_value
  end

  test "theme_cookie_value falls back to system for unknown values" do
    stub_cookie("unknown")

    assert_equal "system", theme_cookie_value
  end

  test "theme_html_class includes dark class only for dark theme" do
    stub_cookie("dark")

    assert_equal "theme-dark dark", theme_html_class

    stub_cookie("light")

    assert_equal "theme-light", theme_html_class

    stub_cookie("system")

    assert_equal "theme-system", theme_html_class
  end

  test "page_title sets content for with title" do
    view.extend(ApplicationHelper)
    view.content_for(:page_title, nil)

    view.page_title("Test Title")

    assert_equal "Test Title", view.content_for(:page_title)
  end

  test "page_title returns translation default when no title set" do
    view.extend(ApplicationHelper)

    result = view.page_title

    expected = I18n.t("meta.default_title")

    assert_equal expected, result
  end

  test "theme_class is backward compatible alias for theme_html_class" do
    stub_cookie("dark")

    assert_equal theme_html_class, theme_class
  end

  test "current_banner_for returns current banner for each surface" do
    travel_to Time.zone.parse("2026-03-18 00:00:00 UTC") do
      assert_equal client_banners(:newer_current_user_banner), current_banner_for(tld: :app, region: :jp, domain: :news)
      assert_equal operator_banners(:current_staff_banner), current_banner_for(tld: :org, region: :jp, domain: :news)
      assert_equal visitor_banners(:current_visitor_banner),
                   current_banner_for(tld: :com, region: :jp, domain: :news)
    end
  end

  test "current_banner_for uses the writing connection" do
    travel_to Time.zone.parse("2026-03-18 00:00:00 UTC") do
      roles = []

      AppPrincipalRecord.stub(
        :connected_to, ->(role:, &block) do
        roles << role
        block.call
      end,
      ) do
        assert_equal client_banners(:newer_current_user_banner),
                     current_banner_for(tld: :app, region: :jp, domain: :news)
      end

      assert_equal [:writing], roles
    end
  end

  test "edge_host returns nil when matching edge env is unset" do
    stub_request_host(ENV["MAIN_CORPORATE_URL"])

    with_edge_env("EDGE_CORPORATE_URL" => nil) do
      assert_nil edge_host
    end
  end

  test "edge_host resolves service edge host for user surface" do
    stub_request_host(ENV["MAIN_SERVICE_URL"])

    with_edge_env("EDGE_SERVICE_URL" => "https://edge.app.localhost:5171") do
      assert_equal "edge.app.localhost", edge_host
    end
  end

  test "edge_host resolves staff edge host for staff surface" do
    stub_request_host(ENV["SIDE_STAFF_URL"])

    with_edge_env("EDGE_STAFF_URL" => "edge.org.localhost") do
      assert_equal "jp.umaxica.com", edge_host
    end
  end

  test "edge_host resolves corporate edge host for client surface" do
    stub_request_host(ENV["DOCS_CORPORATE_URL"])

    with_edge_env("EDGE_CORPORATE_URL" => "http://edge.com.localhost") do
      assert_equal "edge.com.localhost", edge_host
    end
  end

  test "current_banner_for returns nil when the connection is unavailable" do
    travel_to Time.zone.parse("2026-03-18 00:00:00 UTC") do
      AppPrincipalRecord.stub(
        :connected_to,
        ->(*) {
          raise ActiveRecord::ConnectionNotEstablished
        },
      ) do
        assert_nil current_banner_for(tld: :app, region: :jp, domain: :news)
      end
    end
  end

  test "validate_banner_args! rejects invalid banner inputs" do
    error = assert_raises(ArgumentError) { send(:validate_banner_args!, tld: :bad, region: :jp, domain: :news) }
    assert_match(/Invalid tld/, error.message)

    error = assert_raises(ArgumentError) { send(:validate_banner_args!, tld: :app, region: :jp, domain: :bad) }
    assert_match(/Invalid domain/, error.message)

    error = assert_raises(ArgumentError) { send(:validate_banner_args!, tld: :app, region: :us, domain: :sign) }
    assert_match(/Invalid region/, error.message)
  end
end
