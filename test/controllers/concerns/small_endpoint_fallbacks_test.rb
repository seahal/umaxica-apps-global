# typed: false
# frozen_string_literal: true

require "test_helper"

# Four narrow response seams that surfaces share. Each decides what an
# unauthenticated or rejected caller is told, and each is reached only from a
# request state the surrounding surface normally prevents, so they are pinned
# against the module rather than through one surface that happens to reach them.
class SmallEndpointFallbacksTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def controller_harness(concern, &definition)
    Class.new(ApplicationController) do
      include concern

      attr_reader :rendered, :headers_set, :redirected

      def render(*args, **kwargs)
        @rendered = [args, kwargs]
      end

      def redirect_to(*args, **kwargs)
        @redirected = [args, kwargs]
      end

      def response
        @response_double ||= Struct.new(:headers) do
          def set_header(name, value)
            headers[name] = value
          end
        end.new({})
      end

      def invoke(name, ...) = send(name, ...)

      class_eval(&definition) if definition
    end.new
  end

  test "an unauthenticated edge api caller is answered with json, never a redirect" do
    guest = controller_harness(SignEdgeV0JsonApi) { def logged_in? = false }
    member = controller_harness(SignEdgeV0JsonApi) { def logged_in? = true }

    guest.invoke(:authenticate!)

    assert_equal [[], { json: { error: "Unauthorized" }, status: :unauthorized }], guest.rendered

    member.invoke(:authenticate!)

    assert_nil member.rendered
  end

  test "a bearer error other than an invalid token still carries a challenge header" do
    endpoint = controller_harness(BaseOauthEndpoint)

    endpoint.invoke(:render_oauth_bearer_error, "server_error")

    assert_equal "Bearer", endpoint.response.headers["WWW-Authenticate"]
    assert_equal [[], { json: { error: "server_error" }, status: :unauthorized }], endpoint.rendered
  end

  test "an unknown social provider is refused as a bad request rather than passed through" do
    ceremony =
      controller_harness(SocialCeremonyParams) do
        attr_accessor :params_hash

        def params
          ActionController::Parameters.new(params_hash || {})
        end
      end
    ceremony.params_hash = { id: "not-a-provider" }

    assert_raises(ActionController::BadRequest) { ceremony.invoke(:social_provider_param) }
  end

  test "a blank social return target resolves to nothing rather than being signed" do
    ceremony =
      controller_harness(SocialCeremonyParams) do
        def signed_pt_token(value) = "signed:#{value}"

        def path_from_signed_pt(value) = value.sub("signed:", "/")
      end

    assert_nil ceremony.invoke(:safe_social_return_to, "")
    assert_equal "/settings", ceremony.invoke(:safe_social_return_to, "settings")
  end
end
