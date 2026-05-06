# typed: false
# frozen_string_literal: true

require "test_helper"

class Jit::Security::SecretKeyBaseProviderTest < ActiveSupport::TestCase
  setup do
    @original_env = ENV.to_hash
  end

  teardown do
    ENV.replace(@original_env)
  end

  test "fetch_from_local returns secret from ENV and empty previous when PREVIOUS is missing" do
    ENV["SECRET_KEY_BASE"] = "test_current_secret"
    ENV["SECRET_KEY_BASE_PREVIOUS"] = nil

    result = Jit::Security::SecretKeyBaseProvider.fetch_from_local

    assert_equal "test_current_secret", result[:current]
    assert_equal [], result[:previous]
  end

  test "fetch_from_local returns secret from ENV and previous array when PREVIOUS is valid JSON" do
    ENV["SECRET_KEY_BASE"] = "test_current_secret"
    ENV["SECRET_KEY_BASE_PREVIOUS"] = '["old_secret_1", "old_secret_2"]'

    result = Jit::Security::SecretKeyBaseProvider.fetch_from_local

    assert_equal "test_current_secret", result[:current]
    assert_equal ["old_secret_1", "old_secret_2"], result[:previous]
  end

  test "fetch_from_local handles malformed JSON in PREVIOUS" do
    ENV["SECRET_KEY_BASE"] = "test_current_secret"
    ENV["SECRET_KEY_BASE_PREVIOUS"] = "invalid_json"

    result = Jit::Security::SecretKeyBaseProvider.fetch_from_local

    assert_equal "test_current_secret", result[:current]
    assert_equal ["invalid_json"], result[:previous]
  end

  test "use_secrets_manager? is false when not in production" do
    Rails.env.stub(:production?, false) do
      assert_not Jit::Security::SecretKeyBaseProvider.use_secrets_manager?
    end
  end

  test "use_secrets_manager? is false when in production but secret_id is blank" do
    ENV["SECRET_KEY_BASE_SECRET_ID"] = nil

    Rails.env.stub(:production?, true) do
      assert_not Jit::Security::SecretKeyBaseProvider.use_secrets_manager?
    end
  end

  test "use_secrets_manager? is true when in production and secret_id is present" do
    ENV["SECRET_KEY_BASE_SECRET_ID"] = "some_secret_id"

    Rails.env.stub(:production?, true) do
      assert_predicate Jit::Security::SecretKeyBaseProvider, :use_secrets_manager?
    end
  end

  test "fetch returns local when not using secrets manager" do
    ENV["SECRET_KEY_BASE"] = "local_secret"
    ENV["SECRET_KEY_BASE_PREVIOUS"] = nil
    Rails.env.stub(:production?, false) do
      result = Jit::Security::SecretKeyBaseProvider.fetch

      assert_equal "local_secret", result[:current]
      assert_equal [], result[:previous]
    end
  end

  test "fetch_from_secrets_manager returns valid data" do
    ENV["SECRET_KEY_BASE_SECRET_ID"] = "my_secret_id"
    ENV["AWS_REGION"] = "ap-northeast-1"

    mock_response = Struct.new(:secret_string).new(
      { "current" => "aws_current", "previous" => ["aws_prev1"] }.to_json,
    )

    mock_client = Object.new
    mock_client.define_singleton_method(:get_secret_value) do |secret_id:|
      raise ArgumentError, "wrong secret_id" unless secret_id == "my_secret_id"

      mock_response
    end

    Aws::SecretsManager::Client.stub(:new, mock_client) do
      result = Jit::Security::SecretKeyBaseProvider.fetch_from_secrets_manager

      assert_equal "aws_current", result[:current]
      assert_equal ["aws_prev1"], result[:previous]
    end
  end

  test "fetch_from_secrets_manager raises and logs on error" do
    ENV["SECRET_KEY_BASE_SECRET_ID"] = "my_secret_id"

    mock_client = Object.new
    mock_client.define_singleton_method(:get_secret_value) do |**_kwargs|
      raise JSON::ParserError, "bad json"
    end

    logged_message = nil
    Aws::SecretsManager::Client.stub(:new, mock_client) do
      Rails.logger.stub(:error, ->(msg) { logged_message = msg }) do
        assert_raises(JSON::ParserError) do
          Jit::Security::SecretKeyBaseProvider.fetch_from_secrets_manager
        end
      end
    end

    assert_match(/Failed to fetch from Secrets Manager/, logged_message)
  end
end
