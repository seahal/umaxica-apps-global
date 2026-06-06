# typed: false
# frozen_string_literal: true

module SelectedActorContext
  extend ActiveSupport::Concern

  def selected_actor_context?
    selected_account_public_id.present? &&
      selected_collective_public_id.present? &&
      selected_collective_unit_public_id.present?
  end

  def clear_selected_actor_context!
    update!(
      selected_account_public_id: nil,
      selected_collective_public_id: nil,
      selected_collective_unit_public_id: nil,
      selected_avatar_public_id: nil,
      selected_at: nil,
    )
  end
end
