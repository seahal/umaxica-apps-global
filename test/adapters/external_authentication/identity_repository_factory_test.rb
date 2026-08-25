# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationIdentityRepositoryFactoryTest < ActiveSupport::TestCase
  test "builds the current common-schema adapter" do
    repository = ExternalAuthentication::IdentityRepositoryFactory.current.build("google")

    assert_instance_of ExternalAuthentication::ClientExternalIdentityRepositoryAdapter, repository
  end

  test "has no legacy storage switch" do
    assert_not_respond_to ExternalAuthentication::IdentityRepositoryFactory, :legacy
    assert_not_respond_to ExternalAuthentication::IdentityRepositoryFactory, :common
  end
end
