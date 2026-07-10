# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SitemapTest < ActiveSupport::TestCase
  class Harness
    include Sitemap

    attr_reader :response, :rendered

    Response =
      Struct.new(:headers) do
        def set_header(key, value)
          headers[key] = value
        end
      end

    def initialize
      @response = Response.new({})
      @rendered = nil
    end

    def render(**args)
      @rendered = args
    end

    def sitemap_urls
      %w(/foo /bar)
    end
  end

  test "show_xml sets cache headers and renders xml" do
    harness = Harness.new

    harness.send(:show_xml)

    assert_equal "public, max-age=300, s-maxage=600", harness.response.headers["Cache-Control"]
    assert_equal "max-age=600", harness.response.headers["Surrogate-Control"]
    assert_equal({ formats: :xml }, harness.rendered)
  end

  test "show_json renders the sitemap urls as json" do
    harness = Harness.new

    harness.send(:show_json)

    assert_equal({ json: { urls: %w(/foo /bar) } }, harness.rendered)
  end

  test "default sitemap_urls is empty" do
    plain = Class.new { include Sitemap }.new

    assert_empty plain.send(:sitemap_urls)
  end
end
