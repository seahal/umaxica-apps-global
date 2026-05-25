# typed: false
# frozen_string_literal: true

require "test_helper"

module Authentication
  class CurrentResourceResolverTest < ActiveSupport::TestCase
    FakeResource = Struct.new(:id)

    class FakeTokenScope
      FakeToken =
        Struct.new(:public_id, :oidc_jti) do
          def has_attribute?(attribute)
            %i(public_id oidc_jti).include?(attribute.to_sym)
          end
        end

      def self.token_oidc_jti
        @token_oidc_jti
      end

      def self.token_oidc_jti=(value)
        @token_oidc_jti = value
      end

      def where(*)
        self
      end

      def includes(*)
        self
      end

      def or(_other)
        self
      end

      def exists?
        true
      end

      def first
        FakeToken.new("token_public_id", self.class.token_oidc_jti)
      end
    end

    class FakeTokenClass
      def self.where(*)
        FakeTokenScope.new
      end

      def self.column_names
        %w(id public_id discarded_at oidc_sid)
      end

      def self.arel_table
        Arel::Table.new("tokens")
      end
    end

    class FakeResourceClass
      def self.find_by(id:)
        return FakeResource.new(id) if id == 123

        nil
      end
    end

    test "returns failure when access token is blank" do
      result = Authentication::CurrentResourceResolver.new(
        access_token: nil,
        request_host: "app.localhost",
        resource_type: "client",
        resource_class: FakeResourceClass,
        token_class: FakeTokenClass,
      ).call

      assert_equal :blank_access_token, result.failure_reason
      assert_nil result.resource
    end

    test "returns resource and session id when token is valid" do
      payload = { "sub" => 123, "sid" => "sess_1", "act" => "client", "jti" => "current-jti" }
      FakeTokenScope.token_oidc_jti = "current-jti"

      Authentication::Base::Token.stub(:decode, payload) do
        Authentication::Base::Token.stub(:validate_actor_claim!, true) do
          connection_calls = []
          OrgTicketRecord.stub(:connected_to, ->(**options, &block) { connection_calls << options; block.call }) do
            result = Authentication::CurrentResourceResolver.new(
              access_token: "token",
              request_host: "app.localhost",
              resource_type: "client",
              resource_class: FakeResourceClass,
              token_class: FakeTokenClass,
            ).call

            assert_nil result.failure_reason
            assert_equal "token_public_id", result.session_public_id
            assert_equal 123, result.resource.id
            assert connection_calls.any? { |opts| opts[:role] == :writing }
          end
        end
      end
    ensure
      FakeTokenScope.token_oidc_jti = nil
    end

    test "returns token_jti_mismatch when access token jti is stale" do
      payload = { "sub" => 123, "sid" => "sess_1", "act" => "client", "jti" => "stale-jti" }
      FakeTokenScope.token_oidc_jti = "current-jti"

      Authentication::Base::Token.stub(:decode, payload) do
        Authentication::Base::Token.stub(:validate_actor_claim!, true) do
          OrgTicketRecord.stub(:connected_to, ->(**, &block) { block.call }) do
            result = Authentication::CurrentResourceResolver.new(
              access_token: "token",
              request_host: "app.localhost",
              resource_type: "client",
              resource_class: FakeResourceClass,
              token_class: FakeTokenClass,
            ).call

            assert_equal :token_jti_mismatch, result.failure_reason
            assert_nil result.resource
          end
        end
      end
    ensure
      FakeTokenScope.token_oidc_jti = nil
    end

    test "uses the token class connection owner" do
      resolver = Authentication::CurrentResourceResolver.new(
        access_token: "token",
        request_host: "app.localhost",
        resource_type: "client",
        resource_class: FakeResourceClass,
        token_class: ClientToken,
      )

      assert_equal AppTicketRecord, resolver.send(:token_connection_owner)
    end

    test "returns actor_mismatch failure when actor claim differs" do
      payload = { "sub" => 123, "sid" => "sess_1", "act" => "operator" }

      Authentication::Base::Token.stub(:decode, payload) do
        Authentication::Base::Token.stub(:validate_actor_claim!, false) do
          result = Authentication::CurrentResourceResolver.new(
            access_token: "token",
            request_host: "app.localhost",
            resource_type: "client",
            resource_class: FakeResourceClass,
            token_class: FakeTokenClass,
          ).call

          assert_equal :actor_mismatch, result.failure_reason
          assert_equal payload, result.payload
        end
      end
    end
  end
end
