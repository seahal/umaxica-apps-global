# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_tokens
# Database name: com_ticket
#
#  id                              :bigint           not null, primary key
#  dbsc_challenge                  :text
#  dbsc_challenge_issued_at        :datetime
#  dbsc_public_key                 :jsonb
#  device_id_digest                :string
#  discarded_at                    :datetime         default(Infinity), not null
#  dpop_jkt                        :string
#  last_step_up_at                 :datetime
#  last_step_up_scope              :string
#  last_used_at                    :datetime
#  oidc_jti                        :uuid
#  oidc_scope                      :string
#  oidc_sid                        :uuid
#  purged_at                       :datetime         default(Infinity), not null
#  refresh_token_digest            :binary
#  refresh_token_generation        :integer          default(0), not null
#  rotated_at                      :datetime
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  dbsc_session_id                 :string
#  device_id                       :string           default(""), not null
#  device_session_id               :bigint
#  oidc_client_id                  :string(64)
#  oidc_connection_id              :bigint
#  public_id                       :string(21)       default(""), not null
#  refresh_token_family_id         :string
#  visitor_id                      :bigint           not null
#  visitor_token_binding_method_id :bigint           default(0), not null
#  visitor_token_dbsc_status_id    :bigint           default(0), not null
#  visitor_token_kind_id           :bigint           default(1), not null
#  visitor_token_status_id         :bigint           default(1), not null
#
# Indexes
#
#  index_visitor_tokens_on_created_at                       (created_at)
#  index_visitor_tokens_on_dbsc_session_id                  (dbsc_session_id) UNIQUE
#  index_visitor_tokens_on_device_id                        (device_id)
#  index_visitor_tokens_on_device_id_digest                 (device_id_digest)
#  index_visitor_tokens_on_device_session_id                (device_session_id)
#  index_visitor_tokens_on_discarded_at                     (discarded_at)
#  index_visitor_tokens_on_oidc_connection_id               (oidc_connection_id)
#  index_visitor_tokens_on_oidc_jti                         (oidc_jti)
#  index_visitor_tokens_on_oidc_sid                         (oidc_sid)
#  index_visitor_tokens_on_public_id                        (public_id) UNIQUE
#  index_visitor_tokens_on_purged_at                        (purged_at)
#  index_visitor_tokens_on_refresh_token_digest             (refresh_token_digest) UNIQUE
#  index_visitor_tokens_on_refresh_token_family_id          (refresh_token_family_id)
#  index_visitor_tokens_on_rotated_at                       (rotated_at)
#  index_visitor_tokens_on_visitor_id_and_last_step_up_at   (visitor_id,last_step_up_at)
#  index_visitor_tokens_on_visitor_id_and_oidc_client_id    (visitor_id,oidc_client_id)
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

  test "inherits from ComTicketRecord" do
    assert_operator VisitorToken, :<, ComTicketRecord
    assert_operator VisitorToken, :<, ApplicationRecord
    assert_not_operator VisitorToken, :<, OrgTicketRecord
  end

  test "signed ref lookup uses symbol connection owner" do
    assert_equal ComTicketRecord, VisitorToken.send(:connection_owner)
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

  test "does not expose legacy session_id column" do
    assert_not_includes VisitorToken.column_names, "session_id"
  end

  test "enforces maximum concurrent sessions per visitor" do
    visitor = Visitor.create!
    token_status = VisitorTokenStatus.find(VisitorTokenStatus::ACTIVE)
    token_kind = VisitorTokenKind.find(VisitorTokenKind::BROWSER_WEB)
    binding_method = VisitorTokenBindingMethod.find(VisitorTokenBindingMethod::NOTHING)
    dbsc_status = VisitorTokenDbscStatus.find(VisitorTokenDbscStatus::NOTHING)

    VisitorToken::MAX_TOTAL_SESSIONS_PER_VISITOR.times do
      VisitorToken.create!(
        visitor: visitor,
        visitor_token_status: token_status,
        visitor_token_kind: token_kind,
        visitor_token_binding_method: binding_method,
        visitor_token_dbsc_status: dbsc_status,
      )
    end

    extra_token = VisitorToken.new(
      visitor: visitor,
      visitor_token_status: token_status,
      visitor_token_kind: token_kind,
      visitor_token_binding_method: binding_method,
      visitor_token_dbsc_status: dbsc_status,
    )

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
        discarded_at: 12.hours.from_now,
        purged_at: 4.days.from_now,
      )
      token.rotate_refresh_token!

      result = VisitorToken.rotate_refresh!(
        presented_refresh_digest: token.refresh_token_digest,
        device_id: token.device_id,
        now: Time.current,
      )
      replacement = result[:token]

      assert_equal :rotated, result[:status]
      assert_equal token.discarded_at.to_i, replacement.discarded_at.to_i
      assert_equal token.purged_at.to_i, replacement.purged_at.to_i
    end
  end
end
