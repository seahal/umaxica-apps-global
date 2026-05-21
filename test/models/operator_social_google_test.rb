# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_social_googles
# Database name: org_principal
#
#  id                    :bigint           not null, primary key
#  last_authenticated_at :datetime
#  provider              :string           default("google_org"), not null
#  refresh_token         :string           default(""), not null
#  token                 :string           default(""), not null
#  token_expires_at      :integer          not null
#  uid                   :string           default(""), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  staff_id              :bigint           not null
#  status_id             :bigint           default(1), not null
#
# Indexes
#
#  index_operator_social_googles_on_staff_id_unique   (staff_id) UNIQUE WHERE (staff_id IS NOT NULL)
#  index_operator_social_googles_on_status_id         (status_id)
#  index_operator_social_googles_on_token_expires_at  (token_expires_at)
#  index_operator_social_googles_on_uid_and_provider  (uid,provider) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#  fk_rails_...  (status_id => operator_social_google_statuses.id)
#
require "test_helper"

class OperatorSocialGoogleTest < ActiveSupport::TestCase
  fixtures :operators, :operator_social_google_statuses

  test "allows only one google identity per operator" do
    staff = operators(:one)
    OperatorSocialGoogle.create!(
      staff: staff,
      uid: "operator-google-unique",
      provider: "google_org",
      token: "token",
      token_expires_at: 1.week.from_now.to_i,
    )

    duplicate = OperatorSocialGoogle.new(
      staff: staff, uid: "other-uid", provider: "google_org", token: "token",
      token_expires_at: 1.week.from_now.to_i,
    )

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:staff_id]
  end

  test "requires uid token and token expiration" do
    identity = OperatorSocialGoogle.new(staff: operators(:one), provider: "google_org")

    assert_not identity.valid?
    assert_not_empty identity.errors[:uid]
    assert_not_empty identity.errors[:token]
    assert_not_empty identity.errors[:token_expires_at]
  end

  test "find_or_create_from_auth_hash initializes identity from provider uid" do
    auth = OpenStruct.new(
      provider: "google_org",
      uid: "operator-google-auth",
      credentials: OpenStruct.new(token: "token", refresh_token: "refresh", expires_at: 123),
    )

    identity = OperatorSocialGoogle.find_or_create_from_auth_hash(auth)

    assert_predicate identity, :new_record?
    assert_equal "operator-google-auth", identity.uid
    assert_equal "google_org", identity.provider
    assert_equal "token", identity.token
    assert_equal "refresh", identity.refresh_token
    assert_equal 123, identity.token_expires_at
  end
end
