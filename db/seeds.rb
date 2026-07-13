# typed: false
# frozen_string_literal: true

# Reference data (lookup / status tables) is owned by migrations, which insert the fixed rows
# with `INSERT ... ON CONFLICT DO NOTHING` (see adr/reference-table-discipline.md). This file is
# only responsible for development/test sample fixtures (sample Client / Operator and their
# email/secret), and is a no-op in production. The sample fixtures below rely on the reference
# rows already being present from migrations.

return if Rails.env.production?

sample_user_secret = "00000000000000000000000000000000"
sample_staff_public_id = "2222222222222222"
sample_staff_secret = "22222222222222222222222222222222"
sample_staff_email_address = "sample-staff@example.test"

user = Client.find_or_initialize_by(public_id: "sample_user")
user.status_id = ClientStatus::ACTIVE
user.visibility_id = ClientVisibility::USER
user.mfa_level_id = ClientMfaLevel::NOTHING
user.mfa_status_id = ClientMfaStatus::UNCONFIGURED
user.save!

user_email = user.client_emails.find_or_initialize_by(address: "sample-user@example.test")
user_email.user_email_status_id = ClientEmailStatus::VERIFIED
user_email.confirm_policy = true
user_email.save!

user_secret = user.client_secret_credentials.find_or_initialize_by(name: "sample-user-secret")
user_secret.user_secret_kind_id = ClientSecretCredentialKind::PERMANENT
user_secret.user_identity_secret_status_id = ClientSecretCredentialStatus::ACTIVE
user_secret.uses_remaining = 10
user_secret.password = sample_user_secret
user_secret.save!

staff = Operator.find_or_initialize_by(public_id: sample_staff_public_id)
staff.status_id = OperatorStatus::ACTIVE
staff.save!

staff_email = OperatorEmail.find_or_initialize_by(address: sample_staff_email_address)
staff_email.staff = staff
staff_email.staff_email_status_id = OperatorEmailStatus::VERIFIED
staff_email.save!

staff_secret = staff.operator_secret_credentials.find_or_initialize_by(name: "sample-staff-secret")
staff_secret.staff_secret_kind_id = OperatorSecretCredentialKind::PERMANENT
staff_secret.staff_identity_secret_status_id = OperatorSecretCredentialStatus::ACTIVE
staff_secret.password = sample_staff_secret
staff_secret.save!

if Rails.env.development? && ENV["SEED_CMS_SAMPLES"] == "1"
  require_relative "seeds/cms_samples"
  CmsSamples.load!
end
