# typed: false
# frozen_string_literal: true

module CsrfTestHelpers
  TEST_CSRF_TOKEN = "test_csrf_token"

  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  def csrf_headers(token = csrf_token_value, headers: {})
    headers.merge("X-CSRF-Token" => token)
  end

  def json_csrf_headers(token = csrf_token_value, headers: {})
    csrf_headers(token, headers: { "Accept" => "application/json" }.merge(headers))
  end

  def fetch_csrf_token(path, headers: {})
    get(path, headers: headers)

    assert_response :success
    response.body
  end

  def csrf_token_value
    TEST_CSRF_TOKEN
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) { include CsrfTestHelpers }
ActiveSupport.on_load(:action_controller_test_case) { include CsrfTestHelpers }
