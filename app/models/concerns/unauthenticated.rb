# typed: false
# frozen_string_literal: true

module Unauthenticated
  module_function

  def instance
    self
  end

  def id
    nil
  end

  def user?
    false
  end

  def visitor?
    false
  end

  def staff?
    false
  end

  def unauthenticated?
    true
  end

  def authenticated?
    false
  end
end
