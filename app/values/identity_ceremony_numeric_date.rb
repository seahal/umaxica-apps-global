# typed: false
# frozen_string_literal: true

module IdentityCeremonyNumericDate
  module_function

  def value(input)
    if input.is_a?(Time) || input.is_a?(DateTime) || input.is_a?(ActiveSupport::TimeWithZone)
      return Integer(input.strftime("%s"), 10)
    end

    return input if input.is_a?(Integer)
    return Integer(input, 10) if input.is_a?(Numeric)

    Integer(input.to_s, 10)
  end
end
