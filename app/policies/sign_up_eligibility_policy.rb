# typed: false
# frozen_string_literal: true

class SignUpEligibilityPolicy
  APP_CLIENT_DIRECT_SIGN_UP_MINIMUM_AGE = 16
  COM_VISITOR_ACCOUNT_SIGN_UP_MINIMUM_AGE = 13

  MINIMUM_AGES = {
    app: APP_CLIENT_DIRECT_SIGN_UP_MINIMUM_AGE,
    com: COM_VISITOR_ACCOUNT_SIGN_UP_MINIMUM_AGE,
  }.freeze
  private_constant :MINIMUM_AGES

  def self.minimum_age(surface:)
    MINIMUM_AGES.fetch(surface.to_sym)
  rescue KeyError
    raise ArgumentError, "unsupported sign-up eligibility surface: #{surface.inspect}"
  end

  def self.minimum_age_reached?(birthdate, surface:, today: Time.zone.today)
    AgeEligibility.minimum_age_reached?(
      birthdate,
      minimum_age: minimum_age(surface: surface),
      today: today,
    )
  end
end
