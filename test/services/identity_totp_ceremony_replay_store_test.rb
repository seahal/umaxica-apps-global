# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentityTotpCeremonyReplayStoreTest < ActiveSupport::TestCase
  test "for returns a store for app and rejects an unknown surface" do
    assert_kind_of IdentityTotpCeremonyReplayStore, IdentityTotpCeremonyReplayStore.for(:app)
    assert_raises(IdentityTotpCeremonyContract::Error) do
      IdentityTotpCeremonyReplayStore.for(:invalid)
    end
  end

  test "delegates creation and lookup and translates a missing transaction" do
    model = Object.new
    model.define_singleton_method(:create_transaction!) { |**attributes| attributes }
    model.define_singleton_method(:find_by!) do |transaction_id:|
      raise ActiveRecord::RecordNotFound if transaction_id == "missing"

      { transaction_id: transaction_id }
    end
    store = IdentityTotpCeremonyReplayStore.new(model)

    assert_equal({ transaction_id: "created" }, store.create_transaction!(transaction_id: "created"))
    assert_equal({ transaction_id: "found" }, store.find_transaction!("found"))
    error = assert_raises(IdentityTotpCeremonyContract::Error) { store.find_transaction!("missing") }
    assert_equal "transaction is not found", error.message
  end
end
