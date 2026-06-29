# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"
require "jit_security_jwt_issuer_record"

module Jit
  module Security
    module Jwt
      class IssuerRecordTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        setup do
          @active_key = OpenSSL::PKey::EC.generate("secp384r1")
          @grace_key = OpenSSL::PKey::EC.generate("secp384r1")
          @retired_key = OpenSSL::PKey::EC.generate("secp384r1")
          @active_jwk = { "kid" => "active", "state" => "active" }
          @grace_jwk = { "kid" => "grace", "state" => "grace" }
          @retired_jwk = { "kid" => "retired", "state" => "retired" }
        end

        test "public_key_for returns active and grace keys only" do
          record = issuer_record

          assert_same @active_key, record.public_key_for("active")
          assert_same @grace_key, record.public_key_for("grace")
          assert_nil record.public_key_for("retired")
          assert_nil record.public_key_for("missing")
        end

        test "public_key_for rejects revoked kids even when key state allows verification" do
          record = issuer_record(revoked_kids: Set["grace"])

          assert_nil record.public_key_for("grace")
        end

        test "jwks publishes active and grace public jwks only" do
          kids = issuer_record.jwks.fetch(:keys).map { |jwk| jwk.fetch("kid") }

          assert_equal %w(active grace), kids
        end

        test "current_key returns configured active key record" do
          record = issuer_record

          assert_equal "active", record.current_key.kid
        end

        private

        def issuer_record(revoked_kids: Set.new)
          JitSecurityJwtIssuerRecord.new(
            id: "auth",
            namespace: "AUTH",
            issuer: "issuer",
            audiences: ["audience"],
            current_kid: "active",
            keys: {
              "active" => KeyRecord.new(
                kid: "active",
                private_key: @active_key,
                public_key: @active_key,
                public_jwk: @active_jwk,
                state: "active",
              ),
              "grace" => KeyRecord.new(
                kid: "grace",
                private_key: nil,
                public_key: @grace_key,
                public_jwk: @grace_jwk,
                state: "grace",
              ),
              "retired" => KeyRecord.new(
                kid: "retired",
                private_key: nil,
                public_key: @retired_key,
                public_jwk: @retired_jwk,
                state: "retired",
              ),
            },
            revoked_kids: revoked_kids,
          )
        end
      end
    end
  end
end
