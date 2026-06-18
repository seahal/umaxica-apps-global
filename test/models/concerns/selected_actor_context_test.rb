# typed: false
# frozen_string_literal: true

require "test_helper"

class SelectedActorContextTest < ActiveSupport::TestCase
  fixtures_none!

  class FakeSelectedActor
    include SelectedActorContext

    attr_accessor :selected_account_public_id, :selected_collective_public_id,
                  :selected_collective_unit_public_id, :selected_avatar_public_id, :selected_at

    def update!(attributes)
      attributes.each do |key, value|
        public_send("#{key}=", value)
      end
    end
  end

  test "selected_actor_context? returns true when all context public ids are present" do
    actor = FakeSelectedActor.new
    actor.selected_account_public_id = "account"
    actor.selected_collective_public_id = "collective"
    actor.selected_collective_unit_public_id = "unit"

    assert_predicate actor, :selected_actor_context?
  end

  test "clear_selected_actor_context! clears all selected context attributes" do
    actor = FakeSelectedActor.new
    actor.selected_account_public_id = "account"
    actor.selected_collective_public_id = "collective"
    actor.selected_collective_unit_public_id = "unit"
    actor.selected_avatar_public_id = "avatar"
    actor.selected_at = Time.current

    actor.clear_selected_actor_context!

    assert_nil actor.selected_account_public_id
    assert_nil actor.selected_collective_public_id
    assert_nil actor.selected_collective_unit_public_id
    assert_nil actor.selected_avatar_public_id
    assert_nil actor.selected_at
  end
end
