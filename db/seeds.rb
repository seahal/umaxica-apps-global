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
ensure_reference_rows(UserVisibility, UserVisibility::DEFAULTS)
ensure_reference_rows(UserStatus, UserStatus::DEFAULTS)
ensure_reference_rows(UserMultiFactor, UserMultiFactor::DEFAULTS)
ensure_reference_rows(UserEmailStatus, UserEmailStatus::DEFAULTS)
ensure_reference_rows(UserOneTimePasswordStatus, UserOneTimePasswordStatus::DEFAULTS)
ensure_reference_rows(UserSecretStatus, [UserSecretStatus::ACTIVE, UserSecretStatus::USED])
ensure_reference_rows(UserSecretKind, [UserSecretKind::PERMANENT])

ensure_reference_rows(OperatorVisibility, [OperatorVisibility::STAFF])
ensure_reference_rows(StaffStatus, [StaffStatus::ACTIVE])
ensure_reference_rows(StaffEmailStatus, [StaffEmailStatus::VERIFIED])
ensure_reference_rows(
  StaffSecretStatus,
  [StaffSecretStatus::ACTIVE, StaffSecretStatus::DELETED, StaffSecretStatus::EXPIRED,
   StaffSecretStatus::REVOKED, StaffSecretStatus::USED,],
)
ensure_reference_rows(StaffSecretKind, [StaffSecretKind::PERMANENT])

# Ensure reference rows using ensure_defaults! method
UserVisibility.ensure_defaults!
UserStatus.ensure_defaults!
UserMultiFactor.ensure_defaults!
UserEmailStatus.ensure_defaults!
UserOneTimePasswordStatus.ensure_defaults!
UserSecretStatus.ensure_defaults!
UserSecretKind.ensure_defaults!

OperatorVisibility.ensure_defaults!
StaffStatus.ensure_defaults!
StaffEmailStatus.ensure_defaults!
StaffSecretStatus.ensure_defaults!
StaffSecretKind.ensure_defaults!

user = User.find_or_initialize_by(public_id: "sample_user")
user.status_id = UserStatus::ACTIVE
user.save!

user_email = user.user_emails.find_or_initialize_by(address: "sample-user@example.test")
user_email.user_email_status_id = UserEmailStatus::VERIFIED
user_email.confirm_policy = true
user_email.save!

user_secret = user.user_secrets.find_or_initialize_by(name: "sample-user-secret")
user_secret.user_secret_kind_id = UserSecretKind::PERMANENT
user_secret.user_identity_secret_status_id = UserSecretStatus::ACTIVE
user_secret.uses_remaining = 10
user_secret.password = sample_user_secret
user_secret.save!

staff = Staff.find_or_initialize_by(public_id: sample_staff_public_id)
staff.status_id = StaffStatus::ACTIVE
staff.save!

staff_email = StaffEmail.find_or_initialize_by(address: sample_staff_email_address)
staff_email.staff = staff
staff_email.staff_email_status_id = StaffEmailStatus::VERIFIED
staff_email.save!

staff_secret = staff.staff_secrets.find_or_initialize_by(name: "sample-staff-secret")
staff_secret.staff_secret_kind_id = StaffSecretKind::PERMANENT
staff_secret.staff_identity_secret_status_id = StaffSecretStatus::ACTIVE
staff_secret.password = sample_staff_secret
staff_secret.save!
