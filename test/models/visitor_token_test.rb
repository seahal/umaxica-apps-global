# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_tokens
# Database name: symbol
#
#  id                              :bigint           not null, primary key
#  dbsc_challenge                  :text
#  dbsc_challenge_issued_at        :datetime
#  dbsc_public_key                 :jsonb
#  device_id_digest                :string
#  dpop_jkt                        :string
#  lapses_at                       :datetime         default(Infinity), not null
#  last_step_up_at                 :datetime
#  last_step_up_scope              :string
#  last_used_at                    :datetime
#  purge_at                        :datetime         default(Infinity), not null
#  refresh_token_digest            :binary
#  refresh_token_generation        :integer          default(0), not null
#  rotated_at                      :datetime
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  dbsc_session_id                 :string
#  device_id                       :string           default(""), not null
#  public_id                       :string(21)       default(""), not null
#  refresh_token_family_id         :string
#  session_id                      :string
#  visitor_id                      :bigint           not null
#  visitor_token_binding_method_id :bigint           default(0), not null
#  visitor_token_dbsc_status_id    :bigint           default(0), not null
#  visitor_token_kind_id           :bigint           default(1), not null
#  visitor_token_status_id         :bigint           default(1), not null
#
# Indexes
#
#  index_visitor_tokens_on_dbsc_session_id                  (dbsc_session_id) UNIQUE
#  index_visitor_tokens_on_device_id                        (device_id)
#  index_visitor_tokens_on_device_id_digest                 (device_id_digest)
#  index_visitor_tokens_on_public_id                        (public_id) UNIQUE
#  index_visitor_tokens_on_purge_at                         (purge_at)
#  index_visitor_tokens_on_refresh_token_digest             (refresh_token_digest) UNIQUE
#  index_visitor_tokens_on_refresh_token_family_id          (refresh_token_family_id)
#  index_visitor_tokens_on_session_id                       (session_id)
#  index_visitor_tokens_on_visitor_id_and_last_step_up_at   (visitor_id,last_step_up_at)
#  index_visitor_tokens_on_visitor_token_binding_method_id  (visitor_token_binding_method_id)
#  index_visitor_tokens_on_visitor_token_dbsc_status_id     (visitor_token_dbsc_status_id)
#  index_visitor_tokens_on_visitor_token_kind_id            (visitor_token_kind_id)
#  index_visitor_tokens_on_visitor_token_status_id          (visitor_token_status_id)
#
# Foreign Keys
#
#  fk_customer_tokens_on_customer_token_binding_method_id  (visitor_token_binding_method_id => visitor_token_binding_methods.id)
#  fk_customer_tokens_on_customer_token_dbsc_status_id     (visitor_token_dbsc_status_id => visitor_token_dbsc_statuses.id)
#  fk_customer_tokens_on_customer_token_kind_id            (visitor_token_kind_id => visitor_token_kinds.id)
#  fk_customer_tokens_on_customer_token_status_id          (visitor_token_status_id => visitor_token_statuses.id)
#
require "test_helper"

class VisitorTokenTest < ActiveSupport::TestCase
  def setup
    ensure_visitor_reference_records!
    ensure_visitor_token_reference_records!
    @visitor = Visitor.create!
    @token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
  end

  private

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorStatus.find_or_create_by!(id: VisitorStatus::RESERVED)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::NOBODY)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::STAFF)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::BOTH)
  end

  def ensure_visitor_token_reference_records!
    VisitorTokenStatus.ensure_defaults!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::CLIENT_IOS)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::CLIENT_ANDROID)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::DBSC)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::PENDING)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::ACTIVE)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::FAILED)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::REVOKE)
  end

  public

  test "inherits from SymbolRecord" do
    assert_operator VisitorToken, :<, SymbolRecord
    assert_operator VisitorToken, :<, ApplicationRecord
    assert_not_operator VisitorToken, :<, TokenRecord
  end

  test "signed ref lookup uses symbol connection owner" do
    assert_equal SymbolRecord, VisitorToken.send(:connection_owner)
  end

  test "belongs to visitor" do
    association = VisitorToken.reflect_on_association(:visitor)

    assert_not_nil association
    assert_equal :belongs_to, association.macro
  end

  test "can be created with visitor" do
    assert_not_nil @token
    assert_equal @visitor.id, @token.visitor_id
  end

  test "session_id copies from public_id on create when blank" do
    ensure_visitor_reference_records!
    visitor = Visitor.create!
    token = VisitorToken.create!(visitor: visitor)

    assert_equal token.public_id, token.session_id
  end

  test "session_id preserves explicit value on create" do
    ensure_visitor_reference_records!
    visitor = Visitor.create!
    token = VisitorToken.create!(visitor: visitor, session_id: "custom_sid")

    assert_equal "custom_sid", token.session_id
  end

  test "enforces maximum concurrent sessions per visitor" do
    visitor = Visitor.create!

    VisitorToken::MAX_TOTAL_SESSIONS_PER_VISITOR.times do
      VisitorToken.create!(visitor: visitor)
    end

    extra_token = VisitorToken.new(visitor: visitor)

    assert_not extra_token.valid?
    assert_includes(
      extra_token.errors[:base],
      "exceeds maximum concurrent sessions per visitor (#{VisitorToken::MAX_TOTAL_SESSIONS_PER_VISITOR})",
    )
  end

  test "rotate_refresh_token! generates token that authenticates" do
    raw = @token.rotate_refresh_token!

    public_id, verifier = VisitorToken.parse_refresh_token(raw)

    assert_equal @token.public_id, public_id
    assert @token.authenticate_refresh_token(verifier)
    assert_not @token.authenticate_refresh_token("wrong-value")
  end

  test "rotated replacement preserves forced logout window" do
    freeze_time do
      token = VisitorToken.create!(
        visitor: @visitor,
        visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
        lapses_at: 12.hours.from_now,
        purge_at: 4.days.from_now,
      )
      token.rotate_refresh_token!

      result = VisitorToken.rotate_refresh!(
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
end
