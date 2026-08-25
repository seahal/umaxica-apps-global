# typed: false
# frozen_string_literal: true

# Shared behavior for sign-in check and check-cancellation controllers on the com surface.
# Include this instead of inheriting from Sign::Com::Sign::In::ChecksController.
module SignComInCheckControllerSupport
  extend ActiveSupport::Concern

  def show
    @checkpoint_items ||= []
  end

  private

  def sign_in_sequence_required_for_participant?(participant)
    participant.to_sym == :checkpoint
  end

  def sign_in_sequence_surface
    :com
  end
end
