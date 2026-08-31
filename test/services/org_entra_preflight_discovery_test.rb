# typed: false
# frozen_string_literal: true

require "test_helper"

# The staff sign-in preflight is a diagnostic: it reports which parts of the
# Entra configuration are usable. Every check has to answer rather than raise,
# because a preflight that itself falls over tells an operator nothing about the
# thing they came to check.
class OrgEntraPreflightDiscoveryTest < ActiveSupport::TestCase
  fixtures :operators, :operator_statuses

  def check(result, name)
    result.checks.find { |candidate| candidate.name == name }
  end

  test "the discovery document is fetched over https from the tenant's own metadata endpoint" do
    requested = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:body) { %({"issuer":"https://login.microsoftonline.com/tenant/v2.0"}) }

    Net::HTTP.stub(:get_response, ->(uri) { requested = uri; response }) do
      document = OrgEntraSignInPreflight.new.send(:fetch_discovery_document, "tenant-1")

      assert_equal "https://login.microsoftonline.com/tenant/v2.0", document.fetch("issuer")
    end

    assert_equal "https", requested.scheme
    assert_equal "login.microsoftonline.com", requested.host
    assert_includes requested.path, "tenant-1"
    assert_includes requested.path, "/.well-known/openid-configuration"
  end

  test "a non-success response from the tenant is reported as a metadata error carrying the status" do
    response = Net::HTTPNotFound.new("1.1", "404", "Not Found")

    Net::HTTP.stub(:get_response, ->(_uri) { response }) do
      error =
        assert_raises(OrgEntraSignInPreflight::MetadataError) do
          OrgEntraSignInPreflight.new.send(:fetch_discovery_document, "tenant-1")
        end

      assert_match(/404/, error.message)
    end
  end

  # An unreachable tenant is a failed check with the reason, not a failed
  # preflight: the operator still needs to see the other checks.
  test "an unreachable tenant fails only the issuer check and the rest still report" do
    unreachable = ->(_tenant_id) { raise Errno::ECONNREFUSED, "tenant unreachable" }
    result = OrgEntraSignInPreflight.new(metadata_fetcher: unreachable).call

    issuer = check(result, "issuer")

    assert_not issuer.ok
    assert_match(/could not reach the tenant/, issuer.detail)
    assert_equal 5, result.checks.size
    assert check(result, "provisioning"), "the remaining checks still have to report"
  end

  test "provisioning reports how many identities are active rather than only whether any are" do
    result = OrgEntraSignInPreflight.new(metadata_fetcher: ->(_tenant_id) { {} }).call
    provisioning = check(result, "provisioning")

    assert_equal OperatorEntraIdentity.where(status_id: OperatorEntraIdentityState::ACTIVE).count.positive?,
                 provisioning.ok
    assert_predicate provisioning.detail, :present?
  end
end
