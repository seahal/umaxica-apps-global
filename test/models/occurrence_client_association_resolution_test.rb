# typed: false
# frozen_string_literal: true

require "test_helper"

class OccurrenceClientAssociationResolutionTest < ActiveSupport::TestCase
  test "client occurrence join associations resolve to the explicit join models" do
    assert_equal AreaClientOccurrence, ClientOccurrence.reflect_on_association(:area_user_occurrences).klass
    assert_equal DomainClientOccurrence, ClientOccurrence.reflect_on_association(:domain_user_occurrences).klass
    assert_equal EmailClientOccurrence, ClientOccurrence.reflect_on_association(:email_user_occurrences).klass
    assert_equal IpClientOccurrence, ClientOccurrence.reflect_on_association(:ip_user_occurrences).klass
    assert_equal TelephoneClientOccurrence, ClientOccurrence.reflect_on_association(:telephone_user_occurrences).klass
  end

  test "occurrence parents resolve client occurrences through user occurrence joins" do
    [
      AreaOccurrence,
      DomainOccurrence,
      EmailOccurrence,
      IpOccurrence,
      OperatorOccurrence,
      TelephoneOccurrence,
      ZipOccurrence,
    ].each do |model|
      association = model.reflect_on_association(:client_occurrences)

      assert_not_nil association, "#{model.name} should define client_occurrences"
      assert_equal ClientOccurrence, association.klass,
                   "#{model.name} should resolve client_occurrences to ClientOccurrence"
    end
  end
end
