# typed: false
# frozen_string_literal: true

require "test_helper"

class VerificationCookieableTest < ActiveSupport::TestCase
  test "cookie_name is secure only in production" do
    {
      UserVerification => "verification",
      OperatorVerification => "verification",
      VisitorVerification => "verification",
    }.each do |klass, plain_name|
      Rails.env.stub(:production?, false) do
        assert_equal plain_name, klass.cookie_name
      end

      Rails.env.stub(:production?, true) do
        assert_equal "__Secure-#{plain_name}", klass.cookie_name
      end
    end
  end
end
