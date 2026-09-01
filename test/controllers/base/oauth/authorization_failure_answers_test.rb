# typed: false
# frozen_string_literal: true

require "test_helper"

# The authorize endpoint answers a relying party, not a browser page, so a
# refused issuance has to come back as an OAuth error object with the reason the
# issuer gave -- a redirect or a rendered page would be followed or displayed by
# an RP that cannot read either.
class BaseOauthAuthorizationFailureAnswersTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(controller_class)
    Class.new(controller_class) do
      attr_accessor :params_hash, :rendered

      def params
        ActionController::Parameters.new(params_hash || {})
      end

      def current_session = nil

      def render(*args, **kwargs)
        self.rendered = [args, kwargs]
      end

      def invoke(name, ...) = send(name, ...)
    end.new.tap do |h|
      h.params_hash = { ri: "jp" }
      h.request = ActionDispatch::TestRequest.create
    end
  end

  [
    Base::App::Oauth::AuthorizationsController,
    Base::Com::Oauth::AuthorizationsController,
    Base::Org::Oauth::AuthorizationsController,
  ].each do |klass|
    test "#{klass.name} answers a refused issuance with the issuer's own error" do
      harness = harness_for(klass)
      refused = Struct.new(:success?, :error, :error_description, :redirect_url)
        .new(false, "invalid_request", "state is required", nil)

      Actor.clear
      OidcAuthorizationCodeIssuer.stub(:call, ->(**) { refused }) do
        harness.invoke(:issue_authorization_code!, nil, params_hash: {})
      end

      assert_equal "invalid_request", harness.rendered.last.fetch(:json).fetch(:error)
      assert_equal :bad_request, harness.rendered.last.fetch(:status)
    ensure
      Actor.clear
    end
  end
end
