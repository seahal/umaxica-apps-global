# typed: false
# frozen_string_literal: true

# Shared behavior for sign-in check and check-cancellation controllers on the app surface.
# Include this instead of inheriting from Sign::App::Sign::In::ChecksController.
module SignAppInCheckControllerSupport
  extend ActiveSupport::Concern

  def show
    @checkpoint_items ||= []
  end

  private

  def sign_in_sequence_required_for_participant?(participant)
    participant.to_sym == :checkpoint
  end

  def sign_in_sequence_surface
    :app
  end
end
