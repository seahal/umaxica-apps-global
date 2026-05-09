# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_tokens
# Database name: token
#
#  id                            :bigint           not null, primary key
#  dbsc_challenge                :text
#  dbsc_challenge_issued_at      :datetime
#  dbsc_public_key               :jsonb
#  device_id_digest              :string
#  dpop_jkt                      :string
#  lapses_at                     :datetime         default(Infinity), not null
#  last_step_up_at               :datetime
#  last_step_up_scope            :string
#  last_used_at                  :datetime
#  purge_at                      :datetime         default(Infinity), not null
#  refresh_token_digest          :binary
#  refresh_token_generation      :integer          default(0), not null
#  rotated_at                    :datetime
#  status                        :string(20)       default("active"), not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  dbsc_session_id               :string
#  device_id                     :string           default(""), not null
#  public_id                     :string(21)       default(""), not null
#  refresh_token_family_id       :string
#  session_id                    :string
#  staff_id                      :bigint           not null
#  staff_token_binding_method_id :bigint           default(0), not null
#  staff_token_dbsc_status_id    :bigint           default(0), not null
#  staff_token_kind_id           :bigint           default(1), not null
#  staff_token_status_id         :bigint           default(0), not null
#
# Indexes
#
#  index_staff_tokens_on_dbsc_session_id                (dbsc_session_id) UNIQUE
#  index_staff_tokens_on_device_id                      (device_id)
#  index_staff_tokens_on_device_id_digest               (device_id_digest)
#  index_staff_tokens_on_public_id                      (public_id) UNIQUE
#  index_staff_tokens_on_purge_at                       (purge_at)
#  index_staff_tokens_on_refresh_token_digest           (refresh_token_digest) UNIQUE
#  index_staff_tokens_on_refresh_token_family_id        (refresh_token_family_id)
#  index_staff_tokens_on_session_id                     (session_id)
#  index_staff_tokens_on_staff_id_and_last_step_up_at   (staff_id,last_step_up_at)
#  index_staff_tokens_on_staff_token_binding_method_id  (staff_token_binding_method_id)
#  index_staff_tokens_on_staff_token_dbsc_status_id     (staff_token_dbsc_status_id)
#  index_staff_tokens_on_staff_token_kind_id            (staff_token_kind_id)
#  index_staff_tokens_on_staff_token_status_id          (staff_token_status_id)
#  index_staff_tokens_on_status                         (status)
#
# Foreign Keys
#
#  fk_staff_tokens_on_staff_token_binding_method_id  (staff_token_binding_method_id => staff_token_binding_methods.id)
#  fk_staff_tokens_on_staff_token_dbsc_status_id     (staff_token_dbsc_status_id => staff_token_dbsc_statuses.id)
#  fk_staff_tokens_on_staff_token_kind_id            (staff_token_kind_id => staff_token_kinds.id)
#  fk_staff_tokens_on_staff_token_status_id          (staff_token_status_id => staff_token_statuses.id)
#
require "test_helper"

class StaffTokenTest < ActiveSupport::TestCase
  def setup
    @staff = Staff.create!(staff_status: StaffStatus.find(StaffStatus::NOTHING))

    @token = StaffToken.create!(staff: @staff, staff_token_status_id: StaffTokenStatus::ACTIVE)
  end

  test "inherits from TokenRecord" do
    assert_operator StaffToken, :<, TokenRecord
  end

  test "signed ref lookup uses token connection owner" do
    assert_equal TokenRecord, StaffToken.send(:connection_owner)
  end

  test "belongs to staff" do
    association = StaffToken.reflect_on_association(:staff)

    assert_not_nil association
    assert_equal :belongs_to, association.macro
  end

  test "can be created with staff" do
    assert_not_nil @token
    assert_equal @staff.id, @token.staff_id
  end

  test "session_id copies from public_id on create when blank" do
    staff = Staff.create!(staff_status: StaffStatus.find(StaffStatus::NOTHING))
    token = StaffToken.create!(staff: staff)

    assert_equal token.public_id, token.session_id
  end

  test "session_id preserves explicit value on create" do
    staff = Staff.create!(staff_status: StaffStatus.find(StaffStatus::NOTHING))
    token = StaffToken.create!(staff: staff, session_id: "custom_sid")

    assert_equal "custom_sid", token.session_id
  end

  test "assigns numeric id automatically" do
    assert_not_nil @token.id
    assert_kind_of Integer, @token.id
  end

  test "has created_at timestamp" do
    assert_not_nil @token.created_at
    assert_kind_of Time, @token.created_at
  end

  test "has updated_at timestamp" do
    assert_not_nil @token.updated_at
    assert_kind_of Time, @token.updated_at
  end

  test "staff association loads staff correctly" do
    assert_equal @staff, @token.staff
    assert_equal @staff.id, @token.staff.id
  end

  test "can load one fixture" do
    token_one = StaffToken.find_by!(public_id: "one_staff_token_00001")

    assert_not_nil token_one
    assert_not_nil token_one.staff_id
  end

  test "can load two fixture" do
    token_two = StaffToken.find_by!(public_id: "two_staff_token_00001")

    assert_not_nil token_two
    assert_not_nil token_two.staff_id
  end

  test "timestamp is set on creation" do
    assert_not_nil @token.created_at
    assert_not_nil @token.updated_at
    assert_operator @token.created_at, :<=, @token.updated_at
  end

  test "timestamp updates on save" do
    original_updated_at = @token.updated_at
    sleep(0.1)
    @token.update!(updated_at: Time.current)

    assert_operator @token.updated_at, :>, original_updated_at
  end

  test "enforces maximum concurrent sessions per staff" do
    staff = Staff.create!(staff_status: StaffStatus.find(StaffStatus::NOTHING))

    StaffToken::MAX_TOTAL_SESSIONS_PER_STAFF.times do
      StaffToken.create!(staff: staff)
    end

    extra_token = StaffToken.new(staff: staff)

    assert_not extra_token.valid?
    assert_includes extra_token.errors[:base],
                    "exceeds maximum concurrent sessions per staff (#{StaffToken::MAX_TOTAL_SESSIONS_PER_STAFF})"
  end

  test "refresh token digest updates and authenticates" do
    @token.refresh_token = "verifier-value"
    @token.save!

    assert_predicate @token.refresh_token_digest, :present?
    assert @token.authenticate_refresh_token("verifier-value")
    assert_not @token.authenticate_refresh_token("wrong-value")
  end

  test "active state reflects revoked and expired refresh tokens" do
    freeze_time do
      token = StaffToken.create!(staff: @staff)

      assert_predicate token, :active?

      travel 1.minute
      token.update!(lapses_at: 30.seconds.from_now)

      assert_not token.expired_refresh?
      assert_predicate token, :active?

      token.update_columns(lapses_at: 30.seconds.ago)

      assert_predicate token, :expired_refresh?
      assert_not token.active?
    end
  end

  test "rotate_refresh_token! updates digest and timestamps" do
    old_digest = @token.refresh_token_digest

    new_token = @token.rotate_refresh_token!

    assert_match(/\A#{@token.public_id}\./, new_token)
    assert_not_equal old_digest, @token.refresh_token_digest
    assert_predicate @token.last_used_at, :present?
  end

  test "rotate_refresh_token! generates token that authenticates" do
    raw = @token.rotate_refresh_token!

    public_id, verifier = StaffToken.parse_refresh_token(raw)

    assert_equal @token.public_id, public_id
    assert @token.authenticate_refresh_token(verifier)
    assert_not @token.authenticate_refresh_token("wrong-value")
  end

  test "rotated replacement preserves forced logout window" do
    freeze_time do
      token = StaffToken.create!(
        staff: @staff,
        staff_token_kind_id: StaffTokenKind::BROWSER_WEB,
        lapses_at: 12.hours.from_now,
        purge_at: 4.days.from_now,
      )
      token.rotate_refresh_token!

      result = StaffToken.rotate_refresh!(
        presented_refresh_digest: token.refresh_token_digest,
        device_id: token.device_id,
        now: Time.current,
      )
      replacement = result[:token]

      assert_equal :rotated, result[:status]
      assert_equal token.lapses_at.to_i, replacement.lapses_at.to_i
      assert_equal token.purge_at.to_i, replacement.purge_at.to_i
    end
  end

  test "parse_refresh_token splits public_id and verifier" do
    raw = @token.rotate_refresh_token!

    public_id, verifier = StaffToken.parse_refresh_token(raw)

    assert_equal @token.public_id, public_id
    assert_predicate verifier, :present?
  end

  test "purge_at persists on create when provided" do
    purge_at = 2.days.from_now
    token = StaffToken.create!(
      staff: @staff,
      staff_token_kind_id: StaffTokenKind::BROWSER_WEB,
      lapses_at: 1.day.from_now,
      purge_at: purge_at,
    )

    assert_equal purge_at.to_i, token.purge_at.to_i
  end

  test "purge_at is preserved when lapses_at changes" do
    purge_at = 4.days.from_now
    token = StaffToken.create!(
      staff: @staff,
      staff_token_kind_id: StaffTokenKind::BROWSER_WEB,
      lapses_at: 1.day.from_now,
      purge_at: purge_at,
    )
    new_lapses_at = 2.days.from_now

    token.update!(lapses_at: new_lapses_at)

    assert_equal purge_at.to_i, token.purge_at.to_i
  end

  test "purgeability query returns only tokens purgeable at or before now" do
    staff = Staff.create!(staff_status: StaffStatus.find(StaffStatus::NOTHING))
    past_token = StaffToken.create!(staff: staff, lapses_at: 20.minutes.ago, purge_at: 10.minutes.ago)
    future_token = StaffToken.create!(staff: staff, lapses_at: 10.minutes.ago, purge_at: 10.minutes.from_now)

    purgeable_ids = StaffToken.where(purge_at: ..Time.current).pluck(:id)

    assert_includes purgeable_ids, past_token.id
    assert_not_includes purgeable_ids, future_token.id
  end

  test "sha3 digest matches hexdigest packed bytes" do
    raw1 = @token.send(:digest_refresh_token, "B")
    hex = SHA3::Digest::SHA3_384.hexdigest("B")
    raw2 = [hex].pack("H*")

    assert ActiveSupport::SecurityUtils.secure_compare(raw1, raw2)
  end

  test "rotate_refresh! consumes old row and creates new generation in same family" do
    token = StaffToken.create!(
      staff: @staff, staff_token_kind_id: StaffTokenKind::BROWSER_WEB,
      device_id: "device-staff",
    )
    raw = token.rotate_refresh_token!
    _, verifier = StaffToken.parse_refresh_token(raw)
    digest = StaffToken.digest_refresh_token(verifier)

    result = StaffToken.rotate_refresh!(presented_refresh_digest: digest, device_id: "device-staff", now: Time.current)

    assert_equal :rotated, result[:status]
    new_token = result[:token]

    assert_predicate new_token, :present?
    assert_not_equal token.id, new_token.id
    assert_equal token.refresh_token_family_id, new_token.refresh_token_family_id
    assert_equal token.refresh_token_generation + 1, new_token.refresh_token_generation
    assert_predicate token.reload.rotated_at, :present?
  end

  test "rotate_refresh! classifies second attempt as replay" do
    token = StaffToken.create!(
      staff: @staff, staff_token_kind_id: StaffTokenKind::BROWSER_WEB,
      device_id: "device-staff",
    )
    raw = token.rotate_refresh_token!
    _, verifier = StaffToken.parse_refresh_token(raw)
    digest = StaffToken.digest_refresh_token(verifier)

    first = StaffToken.rotate_refresh!(presented_refresh_digest: digest, device_id: "device-staff", now: Time.current)

    assert_equal :rotated, first[:status]

    second = StaffToken.rotate_refresh!(presented_refresh_digest: digest, device_id: "device-staff", now: Time.current)

    assert_equal :replay, second[:status]
    assert_predicate token.reload.rotated_at, :present?
  end

  test "rotate_refresh! rejects revoked compromised and expired tokens" do
    revoked_staff = Staff.create!(staff_status: StaffStatus.find(StaffStatus::NOTHING))
    compromised_staff = Staff.create!(staff_status: StaffStatus.find(StaffStatus::NOTHING))
    expired_staff = Staff.create!(staff_status: StaffStatus.find(StaffStatus::NOTHING))
    revoked = StaffToken.create!(
      staff: revoked_staff, staff_token_kind_id: StaffTokenKind::BROWSER_WEB,
      device_id: "sd1",
    )
    compromised = StaffToken.create!(
      staff: compromised_staff,
      staff_token_kind_id: StaffTokenKind::BROWSER_WEB,
      device_id: "sd2",
    )
    expired = StaffToken.create!(
      staff: expired_staff, staff_token_kind_id: StaffTokenKind::BROWSER_WEB,
      device_id: "sd3",
    )
    revoked_raw = revoked.rotate_refresh_token!
    compromised_raw = compromised.rotate_refresh_token!
    expired_raw = expired.rotate_refresh_token!
    travel 1.minute do
      revoked.update_columns(lapses_at: 30.seconds.ago)
      expired.update_columns(lapses_at: 30.seconds.ago)
      compromised.update!(lapses_at: Time.current)

      revoked_digest = StaffToken.digest_refresh_token(StaffToken.parse_refresh_token(revoked_raw).last)
      compromised_digest = StaffToken.digest_refresh_token(StaffToken.parse_refresh_token(compromised_raw).last)
      expired_digest = StaffToken.digest_refresh_token(StaffToken.parse_refresh_token(expired_raw).last)

      assert_equal :invalid,
                   StaffToken.rotate_refresh!(
                     presented_refresh_digest: revoked_digest, device_id: "sd1",
                     now: Time.current,
                   )[:status]
      assert_equal :invalid,
                   StaffToken.rotate_refresh!(
                     presented_refresh_digest: compromised_digest, device_id: "sd2",
                     now: Time.current,
                   )[:status]
      assert_equal :invalid,
                   StaffToken.rotate_refresh!(
                     presented_refresh_digest: expired_digest, device_id: "sd3",
                     now: Time.current,
                   )[:status]
    end
  end

  test "find_from_signed_ref resolves token when verifier payload has string keys" do
    token = StaffToken.create!(staff: @staff, staff_token_kind_id: StaffTokenKind::BROWSER_WEB)
    signed_ref = Rails.application.message_verifier(:session_ref).generate(
      { "id" => token.id, "pid" => token.public_id },
      expires_in: 1.hour,
    )

    found = StaffToken.find_from_signed_ref(signed_ref)

    assert_equal token.id, found&.id
  end

  test "find_from_signed_ref returns nil for invalid signature" do
    assert_nil StaffToken.find_from_signed_ref("invalid-signed-ref")
  end
end
