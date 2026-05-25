# typed: false
# frozen_string_literal: true

return if Rails.env.production?

sample_user_secret = "00000000000000000000000000000000"
sample_staff_public_id = "2222222222222222"
sample_staff_secret = "22222222222222222222222222222222"
sample_staff_email_address = "sample-staff@example.test"

def ensure_reference_rows(model_class, ids)
  ids.each do |id|
    model_class.find_or_create_by!(id: id)
  end
end

# Reference tables with ReferenceRecord concern
ensure_reference_rows(ClientVisibility, ClientVisibility::DEFAULTS)
ensure_reference_rows(ClientStatus, ClientStatus::DEFAULTS)
ensure_reference_rows(ClientMultiFactor, ClientMultiFactor::DEFAULTS)
ensure_reference_rows(ClientMultiFactorStatus, ClientMultiFactorStatus::DEFAULTS)
ensure_reference_rows(ClientEmailStatus, ClientEmailStatus::DEFAULTS)
ensure_reference_rows(ClientTelephoneStatus, ClientTelephoneStatus::DEFAULTS)
ensure_reference_rows(ClientOneTimePasswordStatus, ClientOneTimePasswordStatus::DEFAULTS)
ensure_reference_rows(ClientSecretStatus, [ClientSecretStatus::ACTIVE, ClientSecretStatus::USED])
ensure_reference_rows(ClientSecretKind, [ClientSecretKind::PERMANENT])
ensure_reference_rows(VisitorStatus, VisitorStatus::DEFAULTS)
ensure_reference_rows(VisitorVisibility, VisitorVisibility::DEFAULTS)
ensure_reference_rows(VisitorMultiFactor, VisitorMultiFactor::DEFAULTS)
ensure_reference_rows(VisitorMultiFactorStatus, VisitorMultiFactorStatus::DEFAULTS)

ensure_reference_rows(OperatorVisibility, [OperatorVisibility::STAFF])
ensure_reference_rows(OperatorIdentityStatus, [OperatorIdentityStatus::ACTIVE])
ensure_reference_rows(OperatorMultiFactor, OperatorMultiFactor::DEFAULTS)
ensure_reference_rows(OperatorMultiFactorStatus, OperatorMultiFactorStatus::DEFAULTS)
ensure_reference_rows(OperatorEmailStatus, [OperatorEmailStatus::VERIFIED])
ensure_reference_rows(
  OperatorSecretStatus,
  [OperatorSecretStatus::ACTIVE, OperatorSecretStatus::DELETED, OperatorSecretStatus::EXPIRED,
   OperatorSecretStatus::REVOKED, OperatorSecretStatus::USED,],
)
ensure_reference_rows(OperatorSecretKind, [OperatorSecretKind::PERMANENT])

# Ensure reference rows using ensure_defaults! method
ClientVisibility.ensure_defaults!
ClientStatus.ensure_defaults!
ClientMultiFactor.ensure_defaults!
ClientMultiFactorStatus.ensure_defaults!
ClientEmailStatus.ensure_defaults!
ClientTelephoneStatus.ensure_defaults!
ClientOneTimePasswordStatus.ensure_defaults!
ClientSecretStatus.ensure_defaults!
ClientSecretKind.ensure_defaults!

VisitorStatus.ensure_defaults!
VisitorVisibility.ensure_defaults!
VisitorMultiFactor.ensure_defaults!
VisitorMultiFactorStatus.ensure_defaults!

OperatorVisibility.ensure_defaults!
OperatorIdentityStatus.ensure_defaults!
OperatorMultiFactor.ensure_defaults!
OperatorMultiFactorStatus.ensure_defaults!
OperatorEmailStatus.ensure_defaults!
OperatorSecretKind.ensure_defaults!

user = Client.find_or_initialize_by(public_id: "sample_user")
user.status_id = ClientStatus::ACTIVE
user.save!

user_email = user.client_emails.find_or_initialize_by(address: "sample-user@example.test")
user_email.user_email_status_id = ClientEmailStatus::VERIFIED
user_email.confirm_policy = true
user_email.save!

user_secret = user.client_secrets.find_or_initialize_by(name: "sample-user-secret")
user_secret.user_secret_kind_id = ClientSecretKind::PERMANENT
user_secret.user_secret_status_id = ClientSecretStatus::ACTIVE
user_secret.uses_remaining = 10
user_secret.password = sample_user_secret
user_secret.save!

staff = Operator.find_or_initialize_by(public_id: sample_staff_public_id)
staff.status_id = OperatorIdentityStatus::ACTIVE
staff.save!

staff_email = OperatorEmail.find_or_initialize_by(address: sample_staff_email_address)
staff_email.staff = staff
staff_email.staff_email_status_id = OperatorEmailStatus::VERIFIED
staff_email.save!

staff_secret = staff.operator_secrets.find_or_initialize_by(name: "sample-staff-secret")
staff_secret.staff_secret_kind_id = OperatorSecretKind::PERMANENT
staff_secret.staff_secret_status_id = OperatorSecretStatus::ACTIVE
staff_secret.password = sample_staff_secret
staff_secret.save!
