# typed: false
# frozen_string_literal: true

require "net/http"

# Checks everything about the org Entra sign-in that can be checked without a
# browser, so a failed live smoke test points at one cause instead of the whole
# ceremony. Administrator tooling, run through `rake entra_identity:preflight`.
#
# This is not part of the test suite and nothing in the request path calls it:
# it reaches Microsoft, and the ordinary suite must stay offline.
#
# Credential values are never returned or printed. Only presence, shape, and
# length are reported, so the result can be pasted into an incident note.
class OrgEntraSignInPreflight < ApplicationService
  class MetadataError < StandardError; end

  Check = Data.define(:name, :ok, :detail)
  Result =
    Data.define(:checks) do
      def ok? = checks.all?(&:ok)
    end

  UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  private_constant :UUID_FORMAT

  # metadata_fetcher is injectable so the unit test can exercise the comparison
  # logic without a network call.
  def initialize(metadata_fetcher: nil)
    super()
    @metadata_fetcher = metadata_fetcher || method(:fetch_discovery_document)
  end

  def call
    Result.new(checks: [credentials_check, redirect_uri_check, kill_switch_check, issuer_check, provisioning_check])
  end

  private

  def credentials_check
    tenant = safe { ExternalAuthentication::ProviderRegistry.tenant_id("entra") }
    client = safe { ExternalAuthentication::ProviderRegistry.audience("entra") }
    secret = Rails.app.creds.option(:OMNI_AUTH_ENTRA_ORG_CLIENT_SECRET).to_s

    problems = []
    problems << "OMNI_AUTH_ENTRA_ORG_TENANT_ID missing or not a UUID" unless tenant.to_s.match?(UUID_FORMAT)
    problems << "OMNI_AUTH_ENTRA_ORG_CLIENT_ID missing or not a UUID" unless client.to_s.match?(UUID_FORMAT)
    problems << "OMNI_AUTH_ENTRA_ORG_CLIENT_SECRET missing" if secret.empty?

    Check.new(
      name: "credentials",
      ok: problems.empty?,
      detail: problems.presence&.join("; ") ||
        "tenant and client are UUIDs, secret present (#{secret.length} characters)",
    )
  end

  # Entra exact-matches the redirect URI, so a mismatch here is the single most
  # common cause of AADSTS50011 and is worth stating literally.
  def redirect_uri_check
    uri = safe { ExternalAuthenticationEntraRedirectUri.call }
    Check.new(
      name: "redirect_uri",
      ok: uri.present?,
      detail: uri.presence || "could not be built; the org auth host is not configured",
    )
  end

  def kill_switch_check
    feature = ExternalAuthentication::FlipperProviderAvailabilityAdapter::PROVIDER_FEATURE_NAMES.fetch("entra")
    # Through the registry, not Flipper directly: an unregistered name reads as
    # "not enabled", which for an availability flag is indistinguishable from a
    # working closed gate (Security::Invariants::FeatureFlagRegistryInvariantTest).
    enabled = FeatureFlags.enabled?(feature)
    Check.new(
      name: "kill_switch",
      ok: enabled,
      detail: enabled ? "#{feature} is enabled" : "#{feature} is disabled; run rake social_ceremony:enable[entra]",
    )
  end

  # Discovery is disabled at runtime (the endpoints are derived from the pinned
  # tenant). Fetching it here is a check, not a dependency: it proves the tenant
  # exists and that the issuer the verifier will demand is the one Microsoft
  # actually advertises.
  def issuer_check
    expected = safe { ExternalAuthentication::ProviderRegistry.issuer_for("entra") }
    return Check.new(name: "issuer", ok: false, detail: "tenant is not configured") if expected.blank?

    document = @metadata_fetcher.call(ExternalAuthentication::ProviderRegistry.tenant_id("entra"))
    advertised = document["issuer"].to_s
    # Neither issuer is echoed. Both embed the tenant id, and this output is
    # meant to be pasted into incident and release-gate notes; the mismatch
    # itself, plus the credential that decides it, is what an administrator acts on.
    Check.new(
      name: "issuer",
      ok: advertised == expected,
      detail: (advertised == expected) ? "the tenant answers on the issuer the verifier requires" : "the tenant answers on a different issuer; check OMNI_AUTH_ENTRA_ORG_TENANT_ID",
    )
  rescue StandardError => e
    Check.new(name: "issuer", ok: false, detail: "could not reach the tenant: #{e.class}")
  end

  def provisioning_check
    active = OperatorEntraIdentity.where(status_id: OperatorEntraIdentityState::ACTIVE).count
    total = OperatorEntraIdentity.count
    Check.new(
      name: "provisioning",
      ok: active.positive?,
      detail: active.positive? ? "#{active} of #{total} identities are active" : "no active identity; nobody can sign in yet",
    )
  end

  def fetch_discovery_document(tenant_id)
    uri = URI("https://login.microsoftonline.com/#{tenant_id}/v2.0/.well-known/openid-configuration")
    response = Net::HTTP.get_response(uri)
    raise MetadataError, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def safe
    yield
  rescue StandardError
    nil
  end
end
