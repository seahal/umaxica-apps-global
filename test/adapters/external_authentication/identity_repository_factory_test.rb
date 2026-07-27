# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationIdentityRepositoryFactoryTest < ActiveSupport::TestCase
  test "builds the current legacy adapter only when explicitly configured" do
    repository = ExternalAuthentication::IdentityRepositoryFactory.current.build("google")

    assert_instance_of ExternalAuthentication::LegacyIdentityRepositoryAdapter, repository
  end

  test "builds the common-schema adapter only when explicitly configured" do
    repository = ExternalAuthentication::IdentityRepositoryFactory.common.build("apple")

    assert_instance_of ExternalAuthentication::ClientExternalIdentityRepositoryAdapter, repository
  end

  test "rejects an unknown storage mode" do
    assert_raises(ArgumentError) do
      ExternalAuthentication::IdentityRepositoryFactory.new(storage: :unknown)
    end
  end
end
