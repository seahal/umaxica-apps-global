# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class OidcBackchannelLogoutDeliveryJobTest < ActiveSupport::TestCase
  test "perform mints the logout token during delivery" do
    sid = SecureRandom.uuid
    request = nil
    fake_response = Struct.new(:code).new("200")
    fake_http = Object.new
    fake_http.define_singleton_method(:request) do |logout_request|
      request = logout_request
      fake_response
    end

    Net::HTTP.stub(:start, proc { |*_, &block| block.call(fake_http) }) do
      OidcLogoutTokenCodec.stub(
        :encode, proc { |**kwargs|
                   assert_equal "sign-rp", kwargs.fetch(:client_id)
                   assert_equal "client", kwargs.fetch(:resource_type)
                   assert_equal "subject-1", kwargs.fetch(:subject)
                   assert_equal sid, kwargs.fetch(:sid)
                   "jwt-token"
                 },
      ) do
        OidcBackchannelLogoutDeliveryJob.perform_now(
          "https://id.app.localhost/oidc/backchannel_logout",
          "sign-rp",
          "client",
          "subject-1",
          sid,
        )
      end
    end

    assert_equal "jwt-token", Rack::Utils.parse_nested_query(request.body)["logout_token"]
  end
end
