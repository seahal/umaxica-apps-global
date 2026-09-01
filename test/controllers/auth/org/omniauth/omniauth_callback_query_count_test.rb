# typed: false
# frozen_string_literal: true

require "test_helper"

# Measures real SQL statement counts for the identity/operator resolution
# the Entra callback controller owns
# (Auth::Org::Omniauth::OmniauthCallbacksController#omniauth,
# app/controllers/auth/org/omniauth/omniauth_callbacks_controller.rb) using
# real ActiveSupport::Notifications instrumentation -- not estimation. Scoped
# to the resolution path this migration adds; the shared
# establish_signed_in_session! machinery downstream is pre-existing and out
# of scope here.
class Auth::Org::Omniauth::OmniauthCallbackQueryCountTest < ActionDispatch::IntegrationTest
  TENANT_ID = "11111111-2222-3333-4444-555555555555"
  CLIENT_ID = "22222222-3333-4444-5555-666666666666"
  OBJECT_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  # See the same helper in omniauth_callbacks_controller_test.rb: the strategy
  # reads tenant and client from configuration, replaced here with fixed test
  # values so the suite never depends on real credential values.
  def stub_configured_tenant!
    registry = ExternalAuthentication::ProviderRegistry
    @registry_originals =
      %i(tenant_id audience issuer_for).index_with { |name| registry.method(name) }
    tenant = TENANT_ID
    client = CLIENT_ID
    registry.define_singleton_method(:tenant_id) { |_provider| tenant }
    registry.define_singleton_method(:audience) { |_provider| client }
    registry.define_singleton_method(:issuer_for) { |_provider| "https://login.microsoftonline.com/#{tenant}/v2.0" }
  end

  def restore_configured_tenant!
    registry = ExternalAuthentication::ProviderRegistry
    @registry_originals&.each { |name, method| registry.define_singleton_method(name, method) }
  end

  setup do
    # See the same note in omniauth_callbacks_controller_test.rb: other suites
    # leave OmniAuth.config.test_mode = true behind, which would short-circuit
    # the real strategy this test measures.
    @previous_omniauth_test_mode = OmniAuth.config.test_mode
    OmniAuth.config.test_mode = false

    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    Rails.configuration.x.rate_limit.fetch(:store).clear
    OrganizationEntraConnectionState.ensure_defaults!
    OperatorEntraIdentityState.ensure_defaults!

    stub_configured_tenant!
    @operator = operators(:one)
    OperatorEntraIdentity.create!(
      operator_id: @operator.id,
      connection_id: nil,
      entra_tenant_id: TENANT_ID,
      entra_object_id: OBJECT_ID,
      status_id: OperatorEntraIdentityState::ACTIVE,
    )
  end

  teardown do
    restore_configured_tenant!
    Rails.configuration.x.rate_limit.fetch(:store).clear
    OmniAuth.config.test_mode = @previous_omniauth_test_mode
  end

  test "the callback resolves identity and operator with no duplicate SELECTs" do
    post "/social/entra", params: {}
    authorize_query = Rack::Utils.parse_nested_query(URI.parse(response.location).query)
    state = authorize_query.fetch("state")
    nonce = authorize_query.fetch("nonce")

    private_key = OpenSSL::PKey::RSA.generate(2048)
    jwk = JWT::JWK.new(private_key, { "kid" => "test-kid-query-count" })
    jwks_loader = ->(_opts) { { "keys" => [jwk.export] } }
    now = Time.now.to_i
    id_token = JWT.encode(
      {
        "iss" => "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
        "aud" => CLIENT_ID,
        "tid" => TENANT_ID,
        "oid" => OBJECT_ID,
        "sub" => "pairwise-sub",
        "acct" => 0,
        "ver" => "2.0",
        "nonce" => nonce,
        "iat" => now,
        "exp" => now + 3600,
      },
      private_key, "RS256", { "kid" => "test-kid-query-count" },
    )

    statements =
      capture_sql do
        stub_entra_access_token(id_token) do
          ExternalSignIn::EntraJwksCache.stub(
            :new, ->(**) {
                    loader_double = Object.new
                    loader_double.define_singleton_method(:loader) { jwks_loader }
                    loader_double
                  },
          ) do
            get("/social/entra/callback", params: { state: state, code: "authorization-code" })
          end
        end
      end

    assert_response :redirect

    connection_selects =
      statements.select { |s|
        s[:sql].include?("organization_entra_connections") && s[:sql].start_with?("SELECT")
      }
    identity_selects =
      statements.select { |s|
        s[:sql].include?("operator_entra_identities") && s[:sql].start_with?("SELECT")
      }
    operator_selects = statements.select { |s| s[:sql].include?(%(FROM "operators")) }

    # Zero: the tenant and client come from configuration, so nothing in the
    # callback path reads organization_entra_connections. A non-zero count here
    # means the connection concept has crept back into sign-in.
    assert_empty connection_selects,
                 "the callback must not query OrganizationEntraConnection, " \
                 "got:\n#{connection_selects.pluck(:sql).join("\n")}"
    assert_equal 1, identity_selects.size,
                 "expected exactly one OperatorEntraIdentity lookup, got:\n#{identity_selects.pluck(:sql).join("\n")}"
    assert_operator operator_selects.size, :<=, 2,
                    "expected at most 2 Operator lookups (resolver + login_allowed?), " \
                    "got:\n#{operator_selects.pluck(:sql).join("\n")}"

    graph_or_userinfo_calls = statements.select { |s| s[:sql].match?(/graph\.microsoft|userinfo/i) }

    assert_empty graph_or_userinfo_calls, "no Microsoft Graph or UserInfo call should ever be issued"
  end

  private

  def stub_entra_access_token(id_token, &)
    strategy_class = OmniAuth::Strategies::UmaxicaEntra
    original = strategy_class.instance_method(:access_token)
    strategy_class.define_method(:access_token) do
      verify_id_token!(id_token)
      OpenStruct.new(id_token: id_token)
    end
    yield
  ensure
    strategy_class.define_method(:access_token, original)
  end

  def capture_sql
    statements = []
    subscriber =
      ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        sql = payload[:sql].to_s
        next if payload[:name] == "SCHEMA"
        next if sql.start_with?("BEGIN", "COMMIT", "ROLLBACK", "SAVEPOINT", "RELEASE")

        statements << { sql: sql, name: payload[:name] }
      end
    yield
    statements
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
