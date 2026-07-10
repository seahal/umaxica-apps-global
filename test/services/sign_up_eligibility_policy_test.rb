# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignUpEligibilityPolicyTest < ActiveSupport::TestCase
  test "app client direct signup minimum age is sixteen" do
    today = Date.new(2026, 6, 25)

    assert_equal 16, SignUpEligibilityPolicy.minimum_age(surface: :app)
    assert_not SignUpEligibilityPolicy.minimum_age_reached?("2010-06-26", surface: :app, today: today)
    assert SignUpEligibilityPolicy.minimum_age_reached?("2010-06-25", surface: :app, today: today)
    assert SignUpEligibilityPolicy.minimum_age_reached?("2000-01-01", surface: :app, today: today)
  end

  test "com visitor account signup keeps its existing minimum age" do
    today = Date.new(2026, 6, 25)

    assert_equal 13, SignUpEligibilityPolicy.minimum_age(surface: :com)
    assert_not SignUpEligibilityPolicy.minimum_age_reached?("2013-06-26", surface: :com, today: today)
    assert SignUpEligibilityPolicy.minimum_age_reached?("2013-06-25", surface: :com, today: today)
  end
end
