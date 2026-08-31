# typed: false
# frozen_string_literal: true

require "test_helper"

# The repository adapter is bound to exactly one provider at construction. Every
# entry point re-checks that the principal or identity it is handed belongs to
# that provider, because a repository that accepted another provider's identity
# would let a Google subject be attached to an Apple link, and vice versa.
class ExternalIdentityRepositoryProviderBindingTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses

  setup do
    @adapter = ExternalAuthentication::ClientExternalIdentityRepositoryAdapter.new(provider: "google")
  end

  def other_provider_identity
    ClientExternalIdentity.new(provider: "apple", subject: "sub-1", issuer: "https://appleid.apple.com")
  end

  test "an identity from another provider is refused by every entry point that takes one" do
    identity = other_provider_identity

    %i(assign_to_user activate! destroy! refresh_token_for).each do |entry_point|
      error =
        assert_raises(ArgumentError, entry_point.to_s) do
          if entry_point == :assign_to_user
            @adapter.public_send(entry_point, identity, clients(:one))
          else
            @adapter.public_send(entry_point, identity)
          end
        end

      assert_match(/identity does not match repository provider/, error.message)
    end
  end

  test "a principal from another provider is refused before an identity is built" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "apple",
      subject: "sub-1",
      issuer: "https://appleid.apple.com",
      audience: "client-1",
      verified_at: Time.current,
      verification_authority: "id_token",
    )

    error =
      assert_raises(ArgumentError) do
        @adapter.build_for_user(user: clients(:one), principal: principal, credential_candidate: nil)
      end

    assert_match(/principal does not match repository provider/, error.message)
  end

  test "an identity from this provider is attached to the user it was assigned to" do
    identity = ClientExternalIdentity.new(provider: "google", subject: "sub-1")

    assigned = @adapter.assign_to_user(identity, clients(:one))

    assert_equal clients(:one), assigned.client
    assert_nil @adapter.refresh_token_for(identity),
               "this provider issues no refresh token to keep, so there is nothing to hand back"
    assert @adapter.ensure_active_status!
  end
end
