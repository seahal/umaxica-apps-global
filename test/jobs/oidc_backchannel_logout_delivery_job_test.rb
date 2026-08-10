# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcBackchannelLogoutDeliveryJobTest < ActiveSupport::TestCase
  teardown { Flipper.remove(:oidc_backchannel_logout_suspended) }

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

  test "a global suspension mints no token and posts to no relying party" do
    Flipper.enable(:oidc_backchannel_logout_suspended)

    assert_nothing_raised { deliver_to("sign-rp") }
  end

  test "an actor suspension stops only the named relying party" do
    Flipper.enable_actor(
      :oidc_backchannel_logout_suspended,
      OidcClientFlipperActor.new(client_id: "sign-rp"),
    )

    assert_nothing_raised { deliver_to("sign-rp") }

    posted_to = deliver_to("other-rp", expect_delivery: true)

    assert_equal "id.app.localhost", posted_to
  end

  private

  # Delivers to `client_id` with the network and the token codec stubbed to fail
  # the test if they are reached, unless `expect_delivery` says otherwise.
  # Returns the host that was posted to.
  def deliver_to(client_id, expect_delivery: false)
    host = nil
    fake_response = Struct.new(:code).new("200")
    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |_request| fake_response }

    http_stub =
      proc do |posted_host, *_rest, &block|
        flunk("posted to #{posted_host} while suspended") unless expect_delivery
        host = posted_host
        block.call(fake_http)
      end
    codec_stub =
      proc do |**_kwargs|
        flunk("minted a logout token while suspended") unless expect_delivery
        "jwt-token"
      end

    Net::HTTP.stub(:start, http_stub) do
      OidcLogoutTokenCodec.stub(:encode, codec_stub) do
        OidcBackchannelLogoutDeliveryJob.perform_now(
          "https://id.app.localhost/oidc/backchannel_logout",
          client_id,
          "client",
          "subject-1",
          SecureRandom.uuid,
        )
      end
    end

    host
  end
end
