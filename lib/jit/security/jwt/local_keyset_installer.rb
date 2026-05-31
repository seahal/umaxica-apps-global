# typed: false
# frozen_string_literal: true

require "base64"
require "fileutils"
require "json"
require "jit/security/jwt/jwk"
require "openssl"

module Jit
  module Security
    module Jwt
      module LocalKeysetInstaller
        module_function

        DEFAULT_STORE_PATH = Rails.root.join("tmp/local_jwt_keysets.json")

        def install!(store_path: DEFAULT_STORE_PATH)
          store = load_store(store_path)
          changed = false

          changed |= install_keyset_issuer!(
            store,
            prefix: "AUTH",
            kid: "#{Rails.env}-auth-es384-a",
          )
          changed |= install_keyset_issuer!(
            store,
            prefix: "PREFERENCE",
            kid: "#{Rails.env}-preference-es384-a",
          )

          Registry::SURFACE_NAMESPACES.each do |namespace|
            changed |= install_surface_issuer!(
              store,
              namespace: namespace,
              kid: "#{Rails.env}-#{namespace.downcase.tr("_", "-")}-es384-a",
            )
          end

          write_store(store_path, store) if changed
          true
        end

        def install_keyset_issuer!(store, prefix:, kid:)
          active_name = "#{prefix}_JWT_ACTIVE_KID"
          private_name = "#{prefix}_JWT_PRIVATE_KEYSET"
          public_name = "#{prefix}_JWT_PUBLIC_KEYSET"
          return false if complete_env?(active_name, private_name, public_name)

          env_values =
            store.fetch(prefix) do
              keyset_issuer_env(kid)
            end
          store[prefix] = env_values

          ENV[active_name] = env_values.fetch("active_kid")
          ENV[private_name] = env_values.fetch("private_keyset")
          ENV[public_name] = env_values.fetch("public_keyset")
          true
        end

        def install_surface_issuer!(store, namespace:, kid:)
          active_name = "JWT_#{namespace}_ACTIVE_KID"
          private_name = "JWT_#{namespace}_PRIVATE_KEY"
          public_name = "JWT_#{namespace}_PUBLIC_KEYSET"
          return false if complete_env?(active_name, private_name, public_name)

          store_key = "JWT_#{namespace}"
          env_values =
            store.fetch(store_key) do
              surface_issuer_env(kid)
            end
          store[store_key] = env_values

          ENV[active_name] = env_values.fetch("active_kid")
          ENV[private_name] = env_values.fetch("private_key")
          ENV[public_name] = env_values.fetch("public_keyset")
          true
        end

        def complete_env?(*names)
          names.all? { |name| ENV[name].present? }
        end

        def load_store(path)
          return {} unless File.exist?(path)

          parsed = JSON.parse(File.read(path))
          parsed.is_a?(Hash) ? parsed : {}
        rescue JSON::ParserError => e
          Rails.logger.warn(
            Jit::LogEvent.format(
              "jwt.local_keyset_store.malformed",
              error_class: e.class.name,
              path: path.to_s,
            ),
          )
          {}
        end

        def write_store(path, store)
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, JSON.pretty_generate(store), mode: "w", perm: 0o600)
        end

        def keyset_issuer_env(kid)
          key = OpenSSL::PKey::EC.generate("secp384r1")
          {
            "active_kid" => kid,
            "private_keyset" => JSON.generate(kid => base64_der(key)),
            "public_keyset" => JSON.generate("keys" => [public_jwk(key, kid)]),
          }
        end

        def surface_issuer_env(kid)
          key = OpenSSL::PKey::EC.generate("secp384r1")
          {
            "active_kid" => kid,
            "private_key" => base64_der(key),
            "public_keyset" => JSON.generate("keys" => [public_jwk(key, kid)]),
          }
        end

        def public_jwk(key, kid)
          Jwk.export_public(key, kid: kid).merge("state" => "active")
        end

        def base64_der(key)
          Base64.strict_encode64(key.to_der)
        end
      end
    end
  end
end
