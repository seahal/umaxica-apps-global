# typed: false
# frozen_string_literal: true

require "test_helper"
require "jit/security/active_record_encryption_key_provider"

module Jit
  module Security
    class ActiveRecordEncryptionKeyProviderTest < ActiveSupport::TestCase
      def with_env(overrides)
        saved = {}
        overrides.each do |key, value|
          saved[key] = ENV[key]
          value.nil? ? ENV.delete(key) : ENV[key] = value
        end
        yield
      ensure
        saved.each do |key, value|
          value.nil? ? ENV.delete(key) : ENV[key] = value
        end
      end

      test "fetch_from_local returns current and empty previous when unset" do
        fake_creds = Object.new
        fake_creds.define_singleton_method(:require) { |_key| "current-key" }
        fake_creds.define_singleton_method(:option) { |_key, **| nil }

        Rails.app.stub(:creds, fake_creds) do
          result = ActiveRecordEncryptionKeyProvider.fetch_from_local

          assert_equal "current-key", result[:current]
          assert_equal [], result[:previous]
        end
      end

      test "parse_local_previous parses JSON array" do
        fake_creds = Object.new
        fake_creds.define_singleton_method(:require) { |_key| "current-key" }
        fake_creds.define_singleton_method(:option) { |_key, **| '["old-key-1", "old-key-2"]' }

        Rails.app.stub(:creds, fake_creds) do
          assert_equal ["old-key-1", "old-key-2"], ActiveRecordEncryptionKeyProvider.parse_local_previous
        end
      end

      test "parse_local_previous wraps plain string" do
        fake_creds = Object.new
        fake_creds.define_singleton_method(:require) { |_key| "current-key" }
        fake_creds.define_singleton_method(:option) { |_key, **| "old-key" }

        Rails.app.stub(:creds, fake_creds) do
          assert_equal ["old-key"], ActiveRecordEncryptionKeyProvider.parse_local_previous
        end
      end

      test "fetch delegates to local lookup" do
        fake_creds = Object.new
        fake_creds.define_singleton_method(:require) { |_key| "current-key" }
        fake_creds.define_singleton_method(:option) { |_key, **| nil }

        Rails.app.stub(:creds, fake_creds) do
          result = ActiveRecordEncryptionKeyProvider.fetch

          assert_equal "current-key", result[:current]
          assert_equal [], result[:previous]
        end
      end
    end
  end
end
