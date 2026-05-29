# typed: false
# frozen_string_literal: true

require "base64"
require "json"
require "jwt"
require "openssl"
require "set"

module Jit
  module Security
    module Jwt
      module Registry
        module_function

        ALGORITHM = "ES384"
        CURVE = "P-384"
        REQUIRED_JWK_FIELDS = %w(kty crv kid alg use x y).freeze
        PRIVATE_JWK_FIELDS = %w(d p q dp dq qi oth k).freeze
        SURFACE_NAMESPACES = %w(
          SIGN_APP SIGN_COM SIGN_ORG
          ACME_APP ACME_COM ACME_ORG
          CORE_APP CORE_COM CORE_ORG
        ).freeze
        SURFACE_ISSUER_ORIGINS = {
          "SIGN_APP" => "https://id.umaxica.app",
          "SIGN_COM" => "https://id.umaxica.com",
          "SIGN_ORG" => "https://id.umaxica.org",
          "ACME_APP" => "https://www.umaxica.app",
          "ACME_COM" => "https://www.umaxica.com",
          "ACME_ORG" => "https://www.umaxica.org",
          "CORE_APP" => "https://www.jp.umaxica.app",
          "CORE_COM" => "https://www.jp.umaxica.com",
          "CORE_ORG" => "https://www.jp.umaxica.org",
        }.freeze

        ConfigurationError = Class.new(StandardError)

        VERIFY_STATES = %w(active grace).freeze
        PUBLISH_STATES = %w(active grace).freeze
        DEFAULT_KID = "default"

        KeyRecord = Data.define(:kid, :private_key, :public_key, :public_jwk, :state)
        IssuerRecord = Data.define(:id, :namespace, :issuer, :audiences, :current_kid, :keys, :revoked_kids) do
          def current_key = keys.fetch(current_kid, nil)
          def public_key_for(kid)
            key = keys.fetch(kid.to_s, nil)
            return nil unless key
            return nil if revoked_kids.include?(kid.to_s)
            return nil unless VERIFY_STATES.include?(key.state)

            key.public_key
          end

          def jwks
            {
              keys: keys.values.filter_map do |key|
                next unless PUBLISH_STATES.include?(key.state)

                key.public_jwk
              end,
            }
          end
        end

        def configure!
          records = build_issuers
          validate!(records)
          @issuers = records
        rescue ConfigurationError => e
          Rails.logger.fatal("jwt.registry.configuration_invalid error_class=#{e.class.name} reason=#{e.message.inspect}")
          raise
        end

        def reload!
          configure!
        end

        def issuer(id)
          issuers.fetch(id.to_s)
        rescue KeyError
          raise ConfigurationError, "unknown JWT issuer registry id: #{id.inspect}"
        end

        def surface(namespace)
          issuer("surface:#{normalize_namespace(namespace)}")
        end

        def auth = issuer("auth")
        def preference = issuer("preference")

        def issuers
          @issuers ||= configure!
        end

        def private_key_for(id, kid = nil)
          record = issuer(id)
          key = record.keys.fetch((kid || record.current_kid).to_s, nil)
          key&.private_key
        end

        def public_key_for(id, kid)
          issuer(id).public_key_for(kid)
        end

        def jwks_for(id)
          issuer(id).jwks
        end

        def parse_header(token)
          _payload, header = JWT.decode(token, nil, false)
          header || {}
        rescue JWT::DecodeError
          {}
        end

        def normalize_namespace(namespace)
          value = namespace.to_s.upcase
          raise ConfigurationError, "unsupported JWT issuer namespace: #{namespace.inspect}" unless SURFACE_NAMESPACES.include?(value)

          value
        end

        def build_issuers
          records = {}
          records["auth"] = build_keyset_issuer(
            id: "auth",
            private_keyset_name: :AUTH_JWT_PRIVATE_KEYSET,
            public_keyset_name: :AUTH_JWT_PUBLIC_KEYSET,
            active_kid: ENV.fetch("AUTH_JWT_ACTIVE_KID", nil),
            issuer: ENV.fetch("AUTH_JWT_ISSUER", nil),
            audiences: split_csv(ENV["AUTH_JWT_AUDIENCES"]),
            revoked_kids: split_csv(ENV["AUTH_JWT_REVOKED_KIDS"]),
          )
          records["preference"] = build_keyset_issuer(
            id: "preference",
            private_keyset_name: :PREFERENCE_JWT_PRIVATE_KEYSET,
            public_keyset_name: :PREFERENCE_JWT_PUBLIC_KEYSET,
            active_kid: ENV.fetch("PREFERENCE_JWT_ACTIVE_KID", nil),
            issuer: ENV.fetch("PREFERENCE_JWT_ISSUER", nil),
            audiences: split_csv(ENV["PREFERENCE_JWT_AUDIENCES"]),
            revoked_kids: split_csv(ENV["PREFERENCE_JWT_REVOKED_KIDS"]),
          )

          SURFACE_NAMESPACES.each do |namespace|
            records["surface:#{namespace}"] = build_surface_issuer(namespace)
          end

          records.freeze
        end

        def build_keyset_issuer(id:, private_keyset_name:, public_keyset_name:, active_kid:, issuer:, audiences:, revoked_kids:)
          private_keys = parse_private_keyset(creds_option(private_keyset_name), source: private_keyset_name)
          public_keys = parse_public_jwk_collection(creds_option(public_keyset_name), source: public_keyset_name)
          current_kid = active_kid.presence || private_keys.keys.first
          keys = merge_keys(private_keys: private_keys, public_jwks: public_keys, current_kid: current_kid, revoked_kids: revoked_kids)

          IssuerRecord.new(
            id: id,
            namespace: id.upcase,
            issuer: issuer,
            audiences: audiences,
            current_kid: current_kid,
            keys: keys,
            revoked_kids: revoked_kids.to_set.freeze,
          )
        end

        def build_surface_issuer(namespace)
          active_kid = ENV["JWT_#{namespace}_ACTIVE_KID"].presence
          private_key = decode_private_key(creds_option("JWT_#{namespace}_PRIVATE_KEY"), source: "JWT_#{namespace}_PRIVATE_KEY")
          current_public_jwk = active_kid && private_key ? export_public_jwk(private_key, kid: active_kid) : nil
          legacy_jwks = parse_public_jwk_collection(ENV["JWT_#{namespace}_PUBLIC_KEYSET"], source: "JWT_#{namespace}_PUBLIC_KEYSET")
          revoked_kids = split_csv(ENV["JWT_#{namespace}_REVOKED_KIDS"]).to_set
          public_jwks = {}
          legacy_jwks.each { |kid, jwk| public_jwks[kid] = jwk }
          if active_kid && current_public_jwk && public_jwks[active_kid] && public_jwks[active_kid].except("state") != current_public_jwk
            raise ConfigurationError, "surface:#{namespace} active public JWK does not match active private key"
          end
          public_jwks[active_kid] = current_public_jwk.merge("state" => "active") if current_public_jwk

          keys = public_jwks.each_with_object({}) do |(kid, jwk), acc|
            state = key_state_for(kid: kid, current_kid: active_kid, configured_state: jwk["state"], revoked_kids: revoked_kids)
            acc[kid] = KeyRecord.new(
              kid: kid,
              private_key: kid == active_kid ? private_key : nil,
              public_key: JWT::JWK.import(jwk.except("state")).public_key,
              public_jwk: jwk.except("state"),
              state: state,
            )
          end.freeze

          IssuerRecord.new(
            id: "surface:#{namespace}",
            namespace: namespace,
            issuer: surface_issuer_origin(namespace),
            audiences: [ENV.fetch("JUMP_GATEWAY_URL", "https://jump.umaxica.net")].freeze,
            current_kid: active_kid,
            keys: keys,
            revoked_kids: revoked_kids.freeze,
          )
        end

        def validate!(records = issuers)
          records.each_value { |record| validate_record!(record) }
          validate_global_kid_uniqueness!(records)
          true
        end

        def validate_record!(record)
          return if record.current_kid.blank? && record.keys.empty?
          raise ConfigurationError, "#{record.id} active kid is missing" if record.current_kid.blank?
          raise ConfigurationError, "#{record.id} active kid must not be #{DEFAULT_KID.inspect}" if insecure_default_kid?(record.current_kid)
          raise ConfigurationError, "#{record.id} active key #{record.current_kid.inspect} is missing" unless record.keys.key?(record.current_kid)
          raise ConfigurationError, "#{record.id} active key #{record.current_kid.inspect} is revoked" if record.revoked_kids.include?(record.current_kid)

          current = record.keys.fetch(record.current_kid)
          raise ConfigurationError, "#{record.id} active private key is missing" if current.private_key.nil?

          record.keys.each_value do |key|
            validate_public_jwk!(key.public_jwk, source: "#{record.id}:#{key.kid}")
            raise ConfigurationError, "#{record.id}:#{key.kid} has invalid key state #{key.state.inspect}" unless %w(active grace retired revoked).include?(key.state)
          end
        end

        def validate_global_kid_uniqueness!(records = issuers)
          seen = {}
          records.each_value do |record|
            record.keys.each_key do |kid|
              previous = seen[kid]
              next if previous && previous != record.id && insecure_default_kid_allowed?(kid)
              raise ConfigurationError, "duplicate JWT kid #{kid.inspect} in #{previous} and #{record.id}" if previous && previous != record.id

              seen[kid] = record.id
            end
          end
        end

        def merge_keys(private_keys:, public_jwks:, current_kid:, revoked_kids:)
          merged = {}
          public_jwks.each do |kid, jwk|
            merged[kid] = KeyRecord.new(
              kid: kid,
              private_key: nil,
              public_key: import_public_key(jwk),
              public_jwk: jwk.except("state"),
              state: key_state_for(kid: kid, current_kid: current_kid, configured_state: jwk["state"], revoked_kids: revoked_kids),
            )
          end

          private_keys.each do |kid, private_key|
            derived_jwk = export_public_jwk(private_key, kid: kid)
            if public_jwks[kid] && public_jwks[kid].except("state") != derived_jwk
              raise ConfigurationError, "active/private key #{kid.inspect} does not match configured public JWK"
            end
            state = key_state_for(kid: kid, current_kid: current_kid, configured_state: public_jwks.dig(kid, "state"), revoked_kids: revoked_kids)
            merged[kid] = KeyRecord.new(
              kid: kid,
              private_key: private_key,
              public_key: private_key,
              public_jwk: derived_jwk,
              state: state,
            )
          end

          merged.freeze
        end

        def parse_private_keyset(raw, source:)
          return {} if raw.blank?

          parsed = parse_json_hash(raw, source: source)
          parsed.transform_values { |value| decode_private_key(value, source: source) }.compact
        end

        def parse_public_jwk_collection(raw, source:)
          return {} if raw.blank?

          parsed = JSON.parse(raw)
          entries =
            case parsed
            when Array
              parsed
            when Hash
              if parsed["keys"].is_a?(Array)
                parsed.fetch("keys")
              else
                raise ConfigurationError, "#{source} must be a JWK Set object with keys array"
              end
            else
              raise ConfigurationError, "#{source} must be a JWK Set JSON object or array"
            end

          entries.each_with_object({}) do |entry, acc|
            jwk = normalize_public_jwk(entry, source: source)
            acc[jwk.fetch("kid")] = jwk
          end
        rescue JSON::ParserError => e
          raise ConfigurationError, "#{source} contains invalid JSON: #{e.message}"
        end

        def parse_json_hash(raw, source:)
          parsed = JSON.parse(raw)
          raise ConfigurationError, "#{source} must be a JSON object" unless parsed.is_a?(Hash)

          parsed
        rescue JSON::ParserError => e
          raise ConfigurationError, "#{source} contains invalid JSON: #{e.message}"
        end

        def normalize_public_jwk(entry, source:)
          raise ConfigurationError, "#{source} entry must be a JSON object" unless entry.is_a?(Hash)

          source_hash = entry.stringify_keys
          raise ConfigurationError, "#{source} entry #{source_hash["kid"].inspect} contains private JWK material" if PRIVATE_JWK_FIELDS.any? { |field| source_hash.key?(field) }

          jwk = source_hash.slice(*(REQUIRED_JWK_FIELDS + ["state"]))
          validate_public_jwk!(jwk, source: source)
          validate_public_key_import!(jwk, source: source)
          jwk
        end

        def validate_public_jwk!(jwk, source:)
          missing = REQUIRED_JWK_FIELDS.reject { |field| jwk[field].present? }
          raise ConfigurationError, "#{source} public JWK is missing #{missing.join(", ")}" if missing.present?
          raise ConfigurationError, "#{source} public JWK alg must be #{ALGORITHM}" unless jwk["alg"] == ALGORITHM
          raise ConfigurationError, "#{source} public JWK use must be sig" unless jwk["use"] == "sig"
          raise ConfigurationError, "#{source} public JWK kty must be EC" unless jwk["kty"] == "EC"
          raise ConfigurationError, "#{source} public JWK crv must be #{CURVE}" unless jwk["crv"] == CURVE
        end

        def export_public_jwk(key, kid:)
          JWT::JWK.new(key, kid: kid).export.stringify_keys.except(*PRIVATE_JWK_FIELDS).merge(
            "alg" => ALGORITHM,
            "use" => "sig",
          )
        end

        def import_public_key(jwk)
          JWT::JWK.import(jwk.except("state")).public_key
        end

        def validate_public_key_import!(jwk, source:)
          import_public_key(jwk)
        rescue JWT::JWKError, OpenSSL::PKey::PKeyError, ArgumentError => e
          raise ConfigurationError, "#{source} contains invalid public JWK material: #{e.class.name}"
        end

        def decode_private_key(value, source:)
          return nil if value.blank?

          raw = value.to_s
          key = raw.include?("BEGIN") ? OpenSSL::PKey.read(raw) : OpenSSL::PKey::EC.new(Base64.decode64(raw))
          raise ConfigurationError, "#{source} must be an EC private key" unless key.is_a?(OpenSSL::PKey::EC)

          key
        rescue OpenSSL::PKey::PKeyError, ArgumentError => e
          raise ConfigurationError, "#{source} contains invalid EC key material: #{e.class.name}"
        end

        def surface_issuer_origin(namespace)
          SURFACE_ISSUER_ORIGINS.fetch(namespace)
        end

        def split_csv(value)
          value.to_s.split(",").map(&:strip).reject(&:empty?).freeze
        end

        def key_state_for(kid:, current_kid:, configured_state:, revoked_kids:)
          return "revoked" if revoked_kids.include?(kid)
          return "active" if kid == current_kid

          configured_state.presence || "grace"
        end

        def insecure_default_kid?(kid)
          kid.to_s == DEFAULT_KID && !insecure_default_kid_allowed?(kid)
        end

        def insecure_default_kid_allowed?(kid)
          kid.to_s == DEFAULT_KID && ENV["JWT_ALLOW_INSECURE_DEFAULT_KID"] == "1"
        end

        def creds_option(key)
          ENV[key.to_s].presence || Rails.app.creds.option(key)
        end
      end
    end
  end
end
