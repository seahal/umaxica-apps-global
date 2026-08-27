# typed: false
# frozen_string_literal: true

require "test_helper"
require "jit_security_active_record_encryption_key_provider"

module Jit
  module Security
    class ActiveRecordEncryptionKeyProviderTest < ActiveSupport::TestCase
      def creds_returning(values)
        fake_creds = Object.new
        fake_creds.define_singleton_method(:option) { |key, **| values.fetch(key, nil) }
        fake_creds
      end

      COMPLETE_CREDENTIALS = {
        ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY: "current-key",
        ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY: "deterministic-key",
        ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT: "salt-key",
      }.freeze

      test "fetch_from_local returns every required key and an empty previous chain when unset" do
        Rails.app.stub(:creds, creds_returning(COMPLETE_CREDENTIALS)) do
          result = JitSecurityActiveRecordEncryptionKeyProvider.fetch_from_local

          assert_equal "current-key", result[:current]
          assert_equal "deterministic-key", result[:deterministic]
          assert_equal "salt-key", result[:key_derivation_salt]
          assert_equal [], result[:previous]
        end
      end

      test "fetch_from_local returns the previous chain when set" do
        credentials = COMPLETE_CREDENTIALS.merge(
          ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS: '["old-key"]',
        )

        Rails.app.stub(:creds, creds_returning(credentials)) do
          assert_equal ["old-key"], JitSecurityActiveRecordEncryptionKeyProvider.fetch_from_local[:previous]
        end
      end

      test "fetch delegates to local lookup" do
        Rails.app.stub(:creds, creds_returning(COMPLETE_CREDENTIALS)) do
          result = JitSecurityActiveRecordEncryptionKeyProvider.fetch

          assert_equal "current-key", result[:current]
          assert_equal [], result[:previous]
        end
      end

      test "parse_local_previous parses JSON array" do
        credentials = { ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS: '["old-key-1", "old-key-2"]' }

        Rails.app.stub(:creds, creds_returning(credentials)) do
          assert_equal ["old-key-1", "old-key-2"], JitSecurityActiveRecordEncryptionKeyProvider.parse_local_previous
        end
      end

      test "parse_local_previous wraps plain string" do
        credentials = { ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS: "old-key" }

        Rails.app.stub(:creds, creds_returning(credentials)) do
          assert_equal ["old-key"], JitSecurityActiveRecordEncryptionKeyProvider.parse_local_previous
        end
      end

      test "parse_local_previous wraps invalid JSON as a single entry" do
        credentials = { ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS: "{invalid-json" }

        Rails.app.stub(:creds, creds_returning(credentials)) do
          assert_equal ["{invalid-json"], JitSecurityActiveRecordEncryptionKeyProvider.parse_local_previous
        end
      end

      # Regression guard. This provider used to substitute a SHA256 digest of public
      # strings whenever Rails.env.local?, so development and test booted with Active
      # Record encryption keys that anyone holding the source could recompute, behind a
      # log warning. Every environment now fails instead, and these tests run in the test
      # environment, which is exactly the case the removed fallback used to permit.
      COMPLETE_CREDENTIALS.each_key do |missing_key|
        test "fetch_from_local raises in development and test when #{missing_key} is missing" do
          Rails.app.stub(:creds, creds_returning(COMPLETE_CREDENTIALS.except(missing_key))) do
            assert_predicate Rails.env, :local?

            error = assert_raises(KeyError) { JitSecurityActiveRecordEncryptionKeyProvider.fetch_from_local }

            assert_match(/missing credential: #{missing_key}/, error.message)
          end
        end
      end

      test "fetch_from_local raises when a required key is blank rather than absent" do
        credentials = COMPLETE_CREDENTIALS.merge(ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY: "")

        Rails.app.stub(:creds, creds_returning(credentials)) do
          error = assert_raises(KeyError) { JitSecurityActiveRecordEncryptionKeyProvider.fetch_from_local }

          assert_match(/missing credential: ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY/, error.message)
        end
      end

      # config.require_master_key is true in development and test, so an absent
      # config/credentials/<env>.key raises MissingKeyError here. The provider must let it
      # through: rescuing RuntimeError would turn "the key file is missing" back into an
      # unrelated failure further along the boot.
      test "fetch_from_local propagates a missing credentials key error" do
        fake_creds = Object.new
        fake_creds.define_singleton_method(:option) do |_key, **|
          raise ActiveSupport::EncryptedFile::MissingKeyError.new(
            key_path: "config/credentials/test.key",
            env_key: "RAILS_MASTER_KEY",
          )
        end

        Rails.app.stub(:creds, fake_creds) do
          assert_raises(ActiveSupport::EncryptedFile::MissingKeyError) do
            JitSecurityActiveRecordEncryptionKeyProvider.fetch_from_local
          end
        end
      end
    end
  end
end
