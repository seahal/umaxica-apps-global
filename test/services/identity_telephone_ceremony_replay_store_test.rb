# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentityTelephoneCeremonyReplayStoreTest < ActiveSupport::TestCase
  test "for returns a store for each known surface" do
    assert_kind_of IdentityTelephoneCeremonyReplayStore, IdentityTelephoneCeremonyReplayStore.for(:app)
    assert_kind_of IdentityTelephoneCeremonyReplayStore, IdentityTelephoneCeremonyReplayStore.for(:com)
    assert_kind_of IdentityTelephoneCeremonyReplayStore, IdentityTelephoneCeremonyReplayStore.for(:org)
  end

  test "for raises when the surface is invalid" do
    assert_raises(IdentityTelephoneCeremony::Error) do
      IdentityTelephoneCeremonyReplayStore.for(:invalid)
    end
  end
end
