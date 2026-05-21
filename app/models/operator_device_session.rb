# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_device_sessions
# Database name: org_ticket
#
#  id                         :bigint           not null, primary key
#  dbsc_bound_at              :datetime
#  dbsc_public_key_thumbprint :string
#  dbsc_session_id_digest     :string
#  device_id_digest           :string
#  dpop_jkt                   :string
#  last_seen_at               :datetime
#  revoke_reason              :string
#  revoked_at                 :datetime
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  current_refresh_token_id   :bigint
#  public_id                  :string(21)       not null
#  refresh_token_family_id    :string
#  staff_id                   :bigint           not null
#  status_id                  :bigint           default(1), not null
#
# Indexes
#
#  index_operator_device_sessions_on_current_refresh_token_id  (current_refresh_token_id)
#  index_operator_device_sessions_on_dbsc_session_id_digest    (dbsc_session_id_digest)
#  index_operator_device_sessions_on_device_id_digest          (device_id_digest)
#  index_operator_device_sessions_on_public_id                 (public_id) UNIQUE
#  index_operator_device_sessions_on_refresh_token_family_id   (refresh_token_family_id)
#  index_operator_device_sessions_on_revoked_at                (revoked_at)
#  index_operator_device_sessions_on_staff_id                  (staff_id)
#
class OperatorDeviceSession < OrgTicketRecord
  include DeviceSessionable

  belongs_to :staff, class_name: "Operator", inverse_of: :operator_device_sessions
  belongs_to :current_refresh_token, class_name: "OperatorToken"
  has_many :staff_tokens, class_name: "OperatorToken", foreign_key: :device_session_id,
                          dependent: :nullify, inverse_of: :device_session
end
