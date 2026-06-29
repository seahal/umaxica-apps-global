# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class SignSecretIssueTest < ActiveSupport::TestCase
  test "issues a secret credential and records issuance details" do
    collection = Class.new do
      def new(attributes)
        Class.new do
          attr_reader :attributes, :raw_secret_credential

          def initialize(attributes)
            @attributes = attributes
          end

          def id
            123
          end

          def raw_secret_credential=(value)
            @raw_secret_credential = value
          end

          def save!
            true
          end
        end.new(attributes)
      end
    end.new
    secret_class =
      Class.new do
        def self.generate_raw_secret_credential
          "abcdef123456"
        end

        def self.transaction
          yield
        end
      end

    captured = nil
    SignSecretRecordEvent.stub(:call, ->(**kwargs) { captured = kwargs }) do
      result = SignSecretIssue.call(
        credential_collection: collection,
        secret_credential_class: secret_class,
        name: "  API Key  ",
        secret_kind: :api_key,
        usage_policy: :standard,
        delivery_method: :email,
        scope: :app,
        issued_at: Time.zone.parse("2026-06-14 12:00:00 UTC"),
      )

      assert_equal "abcdef123456", result.raw_secret_credential
      assert_equal "API Key", result.secret_credential.attributes[:name]
    end

    assert_equal "secret.issued", captured.fetch(:event_name)
    assert_equal :api_key, captured.fetch(:details)[:secret_kind]
    assert_equal :standard, captured.fetch(:details)[:usage_policy]
    assert_equal :email, captured.fetch(:details)[:delivery_method]
    assert_equal :app, captured.fetch(:details)[:scope]
  end

  test "rejects limited session issuance" do
    secret_class =
      Class.new do
        def self.generate_raw_secret_credential
          "abcdef123456"
        end

        def self.transaction
          yield
        end
      end

    error =
      assert_raises(ArgumentError) do
        SignSecretIssue.call(
          credential_collection: Class.new,
          secret_credential_class: secret_class,
          name: "Key",
          secret_kind: :api_key,
          usage_policy: :limited_session,
        )
      end

    assert_equal "limited_session issuance is not enabled yet", error.message
  end
end
