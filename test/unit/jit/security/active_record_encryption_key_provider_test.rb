# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "jit_security_active_record_encryption_key_provider"

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
        fake_creds.define_singleton_method(:require) { |key| "#{key}-value" }
        fake_creds.define_singleton_method(:option) { |_key, **| nil }

        Rails.app.stub(:creds, fake_creds) do
          result = JitSecurityActiveRecordEncryptionKeyProvider.fetch_from_local

          assert_equal "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY-value", result[:current]
          assert_equal "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY-value", result[:deterministic]
          assert_equal "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT-value", result[:key_derivation_salt]
          assert_equal [], result[:previous]
        end
      end

      test "parse_local_previous parses JSON array" do
        fake_creds = Object.new
        fake_creds.define_singleton_method(:require) { |_key| "current-key" }
        fake_creds.define_singleton_method(:option) { |_key, **| '["old-key-1", "old-key-2"]' }

        Rails.app.stub(:creds, fake_creds) do
          assert_equal ["old-key-1", "old-key-2"], JitSecurityActiveRecordEncryptionKeyProvider.parse_local_previous
        end
      end

      test "parse_local_previous wraps plain string" do
        fake_creds = Object.new
        fake_creds.define_singleton_method(:require) { |_key| "current-key" }
        fake_creds.define_singleton_method(:option) { |_key, **| "old-key" }

        Rails.app.stub(:creds, fake_creds) do
          assert_equal ["old-key"], JitSecurityActiveRecordEncryptionKeyProvider.parse_local_previous
        end
      end

      test "parse_local_previous wraps invalid JSON as a single entry" do
        fake_creds = Object.new
        fake_creds.define_singleton_method(:require) { |_key| "current-key" }
        fake_creds.define_singleton_method(:option) { |_key, **| "{invalid-json" }

        Rails.app.stub(:creds, fake_creds) do
          assert_equal ["{invalid-json"], JitSecurityActiveRecordEncryptionKeyProvider.parse_local_previous
        end
      end

      test "fetch delegates to local lookup" do
        fake_creds = Object.new
        fake_creds.define_singleton_method(:require) { |key| "#{key}-value" }
        fake_creds.define_singleton_method(:option) { |_key, **| nil }

        Rails.app.stub(:creds, fake_creds) do
          result = JitSecurityActiveRecordEncryptionKeyProvider.fetch

          assert_equal "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY-value", result[:current]
          assert_equal [], result[:previous]
        end
      end

      test "fetch_from_local uses deterministic fallback outside production when credentials are missing" do
        fake_creds = Object.new
        fake_creds.define_singleton_method(:require) { |_key| raise KeyError, "missing" }
        fake_creds.define_singleton_method(:option) { |_key, **| nil }

        Rails.app.stub(:creds, fake_creds) do
          Rails.env.stub(:production?, false) do
            result = JitSecurityActiveRecordEncryptionKeyProvider.fetch_from_local

            assert_predicate result[:current], :present?
            assert_predicate result[:deterministic], :present?
            assert_predicate result[:key_derivation_salt], :present?
            assert_equal 64, result[:current].length
          end
        end
      end

      test "fetch_from_local prefers option values when available" do
        fake_creds = Object.new
        fake_creds.define_singleton_method(:require) do |_key|
          raise RuntimeError, "should not be called"
        end
        fake_creds.define_singleton_method(:option) do |key, **|
          {
            ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY: "current-key",
            ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS: '["old-key"]',
            ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY: "deterministic-key",
            ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT: "salt-key",
          }.fetch(key, nil)
        end

        Rails.app.stub(:creds, fake_creds) do
          result = JitSecurityActiveRecordEncryptionKeyProvider.fetch_from_local

          assert_equal "current-key", result[:current]
          assert_equal ["old-key"], result[:previous]
          assert_equal "deterministic-key", result[:deterministic]
          assert_equal "salt-key", result[:key_derivation_salt]
        end
      end

      test "fetch_from_local raises in production when required credentials are missing" do
        fake_creds = Object.new
        fake_creds.define_singleton_method(:require) { |_key| raise KeyError, "missing" }
        fake_creds.define_singleton_method(:option) { |_key, **| nil }

        Rails.app.stub(:creds, fake_creds) do
          Rails.env.stub(:local?, false) do
            Rails.env.stub(:production?, true) do
              assert_raises(KeyError) { JitSecurityActiveRecordEncryptionKeyProvider.fetch_from_local }
            end
          end
        end
      end

      # The derivable fallback is computed from public strings, so it must be
      # gated on "is this development or test", not on "is this not production".
      # A staging or preview deployment would otherwise encrypt real PII under a
      # key anyone can recompute from the source.
      test "fetch_from_local raises in a deployed non-production environment such as staging" do
        fake_creds = Object.new
        fake_creds.define_singleton_method(:require) { |_key| raise KeyError, "missing" }
        fake_creds.define_singleton_method(:option) { |_key, **| nil }

        Rails.app.stub(:creds, fake_creds) do
          Rails.env.stub(:local?, false) do
            Rails.env.stub(:production?, false) do
              error = assert_raises(KeyError) { JitSecurityActiveRecordEncryptionKeyProvider.fetch_from_local }

              assert_match(/no derivable fallback/, error.message)
            end
          end
        end
      end

      test "fetch_from_local still uses the derivable fallback in development and test" do
        fake_creds = Object.new
        fake_creds.define_singleton_method(:require) { |_key| raise KeyError, "missing" }
        fake_creds.define_singleton_method(:option) { |_key, **| nil }

        Rails.app.stub(:creds, fake_creds) do
          result = JitSecurityActiveRecordEncryptionKeyProvider.fetch_from_local

          assert_predicate result[:current], :present?
          assert_predicate result[:deterministic], :present?
        end
      end
    end
  end
end
