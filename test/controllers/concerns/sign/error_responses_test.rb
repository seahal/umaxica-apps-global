# typed: false
# frozen_string_literal: true

require "test_helper"

class SignErrorResponsesTest < ActiveSupport::TestCase
  class FormatCollector
    def initialize(kind)
      @kind = kind
    end

    def html
      yield if @kind == :html
    end

    def json
      yield if @kind == :json
    end

    def any
      yield if @kind == :any
    end
  end

  class Harness
    include SignErrorResponses

    attr_accessor :format_kind, :flash, :request

    def initialize
      @format_kind = :json
      @flash = {}
      @request = Struct.new(:format).new(Struct.new(:json?).new(true))
    end

    def respond_to
      yield FormatCollector.new(format_kind)
    end

    def render(**kwargs)
      @rendered = kwargs
    end

    def rendered
      @rendered
    end

    def head(status)
      @headed = status
    end

    def headed
      @headed
    end

    def safe_redirect_back_or_to(path)
      @redirected = path
    end

    def redirected
      @redirected
    end
  end

  class FakeApplicationError < StandardError
    def status_code
      :unprocessable_content
    end
  end

  test "application error responds for html, json, and any formats" do
    harness = Harness.new
    error = FakeApplicationError.new("boom")

    harness.format_kind = :html
    harness.handle_application_error(error)

    assert_equal "boom", harness.flash[:alert]
    assert_equal "/", harness.redirected

    harness.format_kind = :json
    harness.handle_application_error(error)

    assert_equal({ error: "boom" }, harness.rendered[:json])
    assert_equal :unprocessable_content, harness.rendered[:status]

    harness.format_kind = :any
    harness.handle_application_error(error)

    assert_equal :unprocessable_content, harness.headed
  end

  test "authorization and csrf handlers honor request format" do
    harness = Harness.new
    I18n.backend.store_translations(:ja, errors: { forbidden: "Forbidden" })

    harness.format_kind = :json
    harness.handle_not_authorized

    assert_equal({ error: "Forbidden" }, harness.rendered[:json])
    assert_equal :forbidden, harness.rendered[:status]

    harness.format_kind = :any
    harness.handle_not_authorized

    assert_equal :forbidden, harness.headed

    harness.request = Struct.new(:format).new(Struct.new(:json?).new(true))
    harness.handle_csrf_failure

    assert_equal :unprocessable_content, harness.rendered[:status]

    harness.request = Struct.new(:format).new(Struct.new(:json?).new(false))
    assert_raises(ActionController::InvalidCrossOriginRequest) do
      harness.handle_csrf_failure
    end
  end
end
