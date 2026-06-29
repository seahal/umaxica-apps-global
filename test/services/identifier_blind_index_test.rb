# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class IdentifierBlindIndexTest < ActiveSupport::TestCase
  def with_env(overrides)
    saved = overrides.to_h { |key, _value| [key, ENV[key]] }
    overrides.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    saved.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  test "bidx_for_email returns nil for blank email" do
    assert_nil IdentifierBlindIndex.bidx_for_email("")
    assert_nil IdentifierBlindIndex.bidx_for_email("   ")
    assert_nil IdentifierBlindIndex.bidx_for_email(nil)
  end

  test "bidx_for_email returns consistent digest for normalized email" do
    Rails.app.creds.stub(:option, "email-address-secret_credential") do
      result1 = IdentifierBlindIndex.bidx_for_email("user@example.com")
      result2 = IdentifierBlindIndex.bidx_for_email("  USER@Example.COM  ")

      assert_not_nil result1
      assert_equal result1, result2
    end
  end

  test "bidx_for_email prefers email address hmac salt" do
    option =
      ->(key, default: nil) do
        (key == :EMAIL_ADDRESS_HMAC_SALT) ? "email-address-secret_credential" : default
      end

    Rails.app.creds.stub(:option, option) do
      expected = OpenSSL::HMAC.hexdigest("SHA256", "email-address-secret_credential", "email:user@example.com")

      assert_equal expected, IdentifierBlindIndex.bidx_for_email("USER@example.com")
    end
  end

  test "bidx_for_email raises when email address hmac salt is missing" do
    with_env("EMAIL_ADDRESS_HMAC_SALT" => nil) do
      Rails.app.creds.stub(:option, nil) do
        error =
          assert_raises(KeyError) do
            IdentifierBlindIndex.bidx_for_email("USER@example.com")
          end

        assert_equal "Missing key: [:EMAIL_ADDRESS_HMAC_SALT]", error.message
      end
    end
  end

  test "bidx_for_email raises when email address hmac salt is blank" do
    with_env("EMAIL_ADDRESS_HMAC_SALT" => nil) do
      Rails.app.creds.stub(:option, "") do
        error =
          assert_raises(KeyError) do
            IdentifierBlindIndex.bidx_for_email("USER@example.com")
          end

        assert_equal "Missing key: [:EMAIL_ADDRESS_HMAC_SALT]", error.message
      end
    end
  end

  test "bidx_for_email falls back to env salt when credentials are missing" do
    with_env("EMAIL_ADDRESS_HMAC_SALT" => "env-email-secret_credential") do
      Rails.app.creds.stub(:option, nil) do
        expected = OpenSSL::HMAC.hexdigest("SHA256", "env-email-secret_credential", "email:user@example.com")

        assert_equal expected, IdentifierBlindIndex.bidx_for_email("USER@example.com")
      end
    end
  end

  test "bidx_for_telephone returns nil for blank telephone" do
    assert_nil IdentifierBlindIndex.bidx_for_telephone("")
    assert_nil IdentifierBlindIndex.bidx_for_telephone("   ")
    assert_nil IdentifierBlindIndex.bidx_for_telephone(nil)
  end

  test "bidx_for_telephone returns consistent digest for normalized telephone" do
    Rails.app.creds.stub(:option, "telephone-number-secret_credential") do
      result1 = IdentifierBlindIndex.bidx_for_telephone("+819012345678")
      result2 = IdentifierBlindIndex.bidx_for_telephone("090-1234-5678")

      assert_not_nil result1
      assert_equal result1, result2
    end
  end

  test "bidx_for_telephone prefers telephone number hmac salt" do
    option =
      ->(key, default: nil) do
        (key == :TELEPHONE_NUMBER_HMAC_SALT) ? "telephone-number-secret_credential" : default
      end

    Rails.app.creds.stub(:option, option) do
      expected = OpenSSL::HMAC.hexdigest("SHA256", "telephone-number-secret_credential", "telephone:+819012345678")

      assert_equal expected, IdentifierBlindIndex.bidx_for_telephone("090-1234-5678")
    end
  end

  test "bidx_for_telephone raises when telephone number hmac salt is missing" do
    with_env("TELEPHONE_NUMBER_HMAC_SALT" => nil) do
      Rails.app.creds.stub(:option, nil) do
        error =
          assert_raises(KeyError) do
            IdentifierBlindIndex.bidx_for_telephone("090-1234-5678")
          end

        assert_equal "Missing key: [:TELEPHONE_NUMBER_HMAC_SALT]", error.message
      end
    end
  end

  test "bidx_for_telephone raises when telephone number hmac salt is blank" do
    with_env("TELEPHONE_NUMBER_HMAC_SALT" => nil) do
      Rails.app.creds.stub(:option, "") do
        error =
          assert_raises(KeyError) do
            IdentifierBlindIndex.bidx_for_telephone("090-1234-5678")
          end

        assert_equal "Missing key: [:TELEPHONE_NUMBER_HMAC_SALT]", error.message
      end
    end
  end

  test "bidx_for_telephone falls back to env salt when credentials are missing" do
    with_env("TELEPHONE_NUMBER_HMAC_SALT" => "env-telephone-secret_credential") do
      Rails.app.creds.stub(:option, nil) do
        expected = OpenSSL::HMAC.hexdigest("SHA256", "env-telephone-secret_credential", "telephone:+819012345678")

        assert_equal expected, IdentifierBlindIndex.bidx_for_telephone("090-1234-5678")
      end
    end
  end
end
