# typed: false
# frozen_string_literal: true

require "test_helper"

# A CSRF failure on the two sign-up entry points is the signal a scripted
# registration attempt leaves behind, so those paths record an audit line naming
# the step and why the token was rejected before the request is refused. Every
# other path is refused without that extra record.
class Auth::App::SignUpCsrfFailureTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    host! @host
  end

  teardown do
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  test "a telephone sign-up submission without a token is refused and recorded as a rejected step" do
    ActionController::Base.allow_forgery_protection = true
    recorded = []
    Rails.logger.stub(:info, ->(*args, &block) { recorded << (args.first || block&.call).to_s }) do
      post auth_app_sign_up_telephone_url(ri: "jp", format: :json),
           params: { user_telephone: { raw_number: "+1234567890" } },
           headers: { "Host" => @host, "Origin" => "null" }
    end

    assert_response :forbidden
    assert_equal I18n.t("errors.invalid_authenticity_token"), response.parsed_body.fetch("error")
    assert(recorded.any? { |line| line.include?("sign.signup.telephone.create.rejected") })
    assert(recorded.any? { |line| line.include?("null_origin") })
  end
end
