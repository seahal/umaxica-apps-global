# typed: false
# frozen_string_literal: true

class SignInParticipantResult
  attr_reader :participant, :stack, :next_status, :message

  def initialize(participant:, stack:, next_status:, message: nil)
    @participant = participant.to_sym
    @stack = stack
    @next_status = next_status
    @message = message
  end

  delegate :empty?, to: :stack

  def blocking?
    stack.any? { |item| item.blocking? && !item.cleared? }
  end

  def cleared?
    !blocking?
  end
end
