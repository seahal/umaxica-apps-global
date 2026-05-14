# typed: false
# frozen_string_literal: true

require "test_helper"

module Auth
  class CurrentResourceResolverTest < ActiveSupport::TestCase
    FakeResource = Struct.new(:id)

    class FakeTokenScope
      def where(*)
        self
      end

      def or(_other)
        self
      end

      def exists?
        true
      end
    end

    class FakeTokenClass
      def self.where(*)
        FakeTokenScope.new
      end

      def self.column_names
        %w(id public_id lapses_at session_id)
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
      result = Auth::CurrentResourceResolver.new(
        access_token: nil,
        request_host: "app.localhost",
        resource_type: "user",
        resource_class: FakeResourceClass,
        token_class: FakeTokenClass,
        test_env: true,
      ).call

      assert_equal :blank_access_token, result.failure_reason
      assert_nil result.resource
    end

    test "returns resource and session id when token is valid" do
      payload = { "sub" => 123, "sid" => "sess_1", "act" => "user" }

      Authentication::Base::Token.stub(:decode, payload) do
        Authentication::Base::Token.stub(:validate_actor_claim!, true) do
          connection_calls = []
          TokenRecord.stub(:connected_to, ->(**options, &block) { connection_calls << options; block.call }) do
            result = Auth::CurrentResourceResolver.new(
              access_token: "token",
              request_host: "app.localhost",
              resource_type: "user",
              resource_class: FakeResourceClass,
              token_class: FakeTokenClass,
              test_env: true,
            ).call

            assert_nil result.failure_reason
            assert_equal "sess_1", result.session_public_id
            assert_equal 123, result.resource.id
            assert connection_calls.any? { |opts| opts[:role] == :writing }
          end
        end
      end
    end

    test "uses the token class connection owner" do
      resolver = Auth::CurrentResourceResolver.new(
        access_token: "token",
        request_host: "app.localhost",
        resource_type: "user",
        resource_class: FakeResourceClass,
        token_class: UserToken,
        test_env: true,
      )

      assert_equal MarkRecord, resolver.send(:token_connection_owner)
    end

    test "returns actor_mismatch failure when actor claim differs" do
      payload = { "sub" => 123, "sid" => "sess_1", "act" => "operator" }

      Authentication::Base::Token.stub(:decode, payload) do
        Authentication::Base::Token.stub(:validate_actor_claim!, false) do
          result = Auth::CurrentResourceResolver.new(
            access_token: "token",
            request_host: "app.localhost",
            resource_type: "user",
            resource_class: FakeResourceClass,
            token_class: FakeTokenClass,
            test_env: true,
          ).call

          assert_equal :actor_mismatch, result.failure_reason
          assert_equal payload, result.payload
        end
      end
    end
  end
end
