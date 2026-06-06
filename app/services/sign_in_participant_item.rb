# typed: false
# frozen_string_literal: true

class SignInParticipantItem
  attr_reader :key, :blocking, :cleared, :message

  def initialize(key:, blocking:, cleared:, message: nil)
    @key = key.to_sym
    @blocking = blocking
    @cleared = cleared
    @message = message
  end

  def blocking?
    blocking == true
  end

  def cleared?
    cleared == true
  end
end
