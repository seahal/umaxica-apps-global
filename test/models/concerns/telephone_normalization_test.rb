# typed: false
# frozen_string_literal: true

require "test_helper"

class TelephoneNormalizationTest < ActiveSupport::TestCase
  # Test the normalization logic directly without model integration

  test "normalize_to_e164 handles nil input" do
    assert_nil TelephoneNormalization.normalize_to_e164(nil)
    assert_nil TelephoneNormalization.normalize_to_e164("")
    assert_nil TelephoneNormalization.normalize_to_e164("   ")
  end

  # Normalization: removes formatting characters
  test "normalize_to_e164 removes hyphens" do
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("090-1234-5678")
  end

  test "normalize_to_e164 removes spaces" do
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("090 1234 5678")
  end

  test "normalize_to_e164 removes parentheses" do
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("(090)1234-5678")
  end

  test "normalize_to_e164 removes full-width parentheses" do
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("（090）1234-5678")
  end

  test "normalize_to_e164 removes dots and slashes" do
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("090.1234.5678")
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("090/1234/5678")
  end

  test "normalize_to_e164 removes a full-width middle dot" do
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("090・1234・5678")
  end

  test "normalize_to_e164 removes full-width spaces" do
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("090　1234　5678")
  end

  test "normalize_to_e164 removes various hyphens" do
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("090‐1234‐5678") # U+2010
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("090−1234−5678") # U+2212
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("090–1234–5678") # U+2013
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("090—1234—5678") # U+2014
  end

  test "normalize_to_e164 handles mixed formatting" do
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("+81 (90) 1234-5678")
  end

  # International dialing prefixes
  test "normalize_to_e164 converts 00 prefix to +" do
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("0081 90 1234 5678")
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("00819012345678")
  end

  test "normalize_to_e164 converts 010 prefix to +" do
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("010 81 90 1234 5678")
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("010819012345678")
  end

  test "normalize_to_e164 removes domestic 0 after country code from 00 prefix" do
    # "0081090..." -> "+81090..." -> "+8190..."
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("0081(0)90-1234-5678")
  end

  test "normalize_to_e164 removes domestic 0 after country code from 010 prefix" do
    # "010810901234..." -> "+8109012345..." -> "+819012345..."
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("01081(0)90-1234-5678")
  end

  test "normalize_to_e164 removes domestic zero after non Japan country code patterns" do
    assert_equal "+442012345678", TelephoneNormalization.normalize_to_e164("004402012345678")
    assert_equal "+123456789", TelephoneNormalization.normalize_to_e164("001023456789")
    assert_equal "+99923456789", TelephoneNormalization.normalize_to_e164("00999023456789")
  end

  # Domestic format (Japan)
  test "normalize_to_e164 converts domestic format to +81" do
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("09012345678")
    assert_equal "+81312345678", TelephoneNormalization.normalize_to_e164("0312345678")
  end

  test "normalize_to_e164 handles domestic format with formatting" do
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("090-1234-5678")
    assert_equal "+81312345678", TelephoneNormalization.normalize_to_e164("03-1234-5678")
  end

  # International format (already has +)
  test "normalize_to_e164 preserves existing + prefix" do
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("+819012345678")
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("+81 90 1234 5678")
  end

  test "normalize_to_e164 handles US numbers" do
    assert_equal "+15551234567", TelephoneNormalization.normalize_to_e164("+1 555 123 4567")
    assert_equal "+15551234567", TelephoneNormalization.normalize_to_e164("+1 (555) 123-4567")
  end

  # Invalid formats (should return as-is and let validation fail)
  test "normalize_to_e164 returns invalid format when no leading 0 or +" do
    # Ambiguous: could be domestic without 0, or international without +
    # Return as-is and let E.164 validation fail
    result = TelephoneNormalization.normalize_to_e164("9012345678")

    assert_equal "9012345678", result
  end

  test "normalize_to_e164 returns nil when only formatting characters" do
    assert_nil TelephoneNormalization.normalize_to_e164("(---)")
    assert_nil TelephoneNormalization.normalize_to_e164("......")
    assert_nil TelephoneNormalization.normalize_to_e164("( )")
  end

  test "normalize_to_e164 handles only zeros" do
    # "0" alone -> "+81" (domestic 0 removed, but no number left)
    # This should return invalid and fail E.164 validation
    result = TelephoneNormalization.normalize_to_e164("0")

    assert_equal "+81", result # Will fail E.164 validation (needs at least 2 more digits)
  end

  test "normalize_to_e164 handles double zeros alone" do
    # "00" alone -> "+" (international prefix with no number)
    # Should return invalid
    result = TelephoneNormalization.normalize_to_e164("00")

    assert_equal "+", result # Will fail E.164 validation
  end

  # Edge cases
  test "normalize_to_e164 handles maximum length numbers" do
    # E.164 allows up to 15 digits (excluding +)
    # Example: +999999999999999 (15 digits)
    assert_equal "+999999999999999", TelephoneNormalization.normalize_to_e164("+999999999999999")
  end

  test "normalize_to_e164 handles numbers with country code +0 (invalid)" do
    # Country codes cannot start with 0
    # Return as-is, let validation fail
    result = TelephoneNormalization.normalize_to_e164("+0123456789")

    assert_equal "+0123456789", result
  end

  # Real-world examples
  test "normalize_to_e164 handles common Japanese mobile formats" do
    assert_equal "+819012345678", TelephoneNormalization.normalize_to_e164("090-1234-5678")
    assert_equal "+818012345678", TelephoneNormalization.normalize_to_e164("080-1234-5678")
    assert_equal "+817012345678", TelephoneNormalization.normalize_to_e164("070-1234-5678")
  end

  test "normalize_to_e164 handles Japanese landline formats" do
    assert_equal "+81312345678", TelephoneNormalization.normalize_to_e164("03-1234-5678")
    assert_equal "+81612345678", TelephoneNormalization.normalize_to_e164("06-1234-5678")
  end

  test "normalize_to_e164 handles international formats from various countries" do
    assert_equal "+15551234567", TelephoneNormalization.normalize_to_e164("+1-555-123-4567") # US
    assert_equal "+442012345678", TelephoneNormalization.normalize_to_e164("+44 20 1234 5678") # UK
    assert_equal "+861012345678", TelephoneNormalization.normalize_to_e164("+86 10 1234 5678") # China
  end

  test "normalize_to_e164 preserves international prefix numbers without a domestic zero" do
    # "+1" country code has no domestic 0 to strip after the 00 prefix conversion,
    # exercising the remove_domestic_zero_after_country_code fallback return.
    assert_equal "+15551234567", TelephoneNormalization.normalize_to_e164("0015551234567")
    assert_equal "+15551234567", TelephoneNormalization.normalize_to_e164("01015551234567")
  end

  test "normalize_telephone_field installs callbacks and validations" do
    klass =
      Class.new do
        include ActiveModel::Model
        include ActiveModel::Validations::Callbacks
        include TelephoneNormalization

        attr_accessor :number

        normalize_telephone_field :number
      end
    self.class.const_set(:TelephoneNormalizationDummy, klass)

    record = klass.new(number: "090-1234-5678")

    assert_predicate record, :valid?
    assert_equal "+819012345678", record.number

    blank = klass.new(number: "")

    assert_not blank.valid?
    assert_includes blank.errors.details[:number].pluck(:error), :blank
  ensure
    self.class.send(:remove_const, :TelephoneNormalizationDummy) if self.class.const_defined?(
      :TelephoneNormalizationDummy, false,
    )
  end
end
