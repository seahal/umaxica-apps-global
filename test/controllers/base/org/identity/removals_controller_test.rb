# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::Identity::RemovalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_staff)
    ensure_operator_reference_records!
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE)
  end

  test "removes the secret credential when another sign-in method still remains" do
    target = create_active_secret_credential(@operator)
    create_active_secret_credential(@operator)

    post base_org_identity_secret_removal_url(target.public_id, ri: "jp", host: @host),
         headers: as_staff_headers(@operator, host: @host)

    assert_response :see_other
    assert_redirected_to base_org_identity_secrets_path(ri: "jp")
    assert_not_equal OperatorSecretCredentialStatus::ACTIVE, target.reload.staff_secret_status_id
  end

  test "refuses to remove the credential that carries the only remaining sign-in method" do
    only = create_active_secret_credential(@operator)

    post base_org_identity_secret_removal_url(only.public_id, ri: "jp", host: @host),
         headers: as_staff_headers(@operator, host: @host)

    assert_response :see_other
    assert_redirected_to base_org_identity_secrets_path(ri: "jp")
    assert_equal OperatorSecretCredentialStatus::ACTIVE, only.reload.staff_secret_status_id
  end

  test "a credential owned by another operator is not found" do
    other = Operator.create!(status_id: OperatorStatus::ACTIVE)
    other_secret = create_active_secret_credential(other)
    create_active_secret_credential(other)

    post base_org_identity_secret_removal_url(other_secret.public_id, ri: "jp", host: @host),
         headers: as_staff_headers(@operator, host: @host)

    assert_response :not_found
    assert_equal OperatorSecretCredentialStatus::ACTIVE, other_secret.reload.staff_secret_status_id
  end

  private

  def create_active_secret_credential(operator)
    OperatorSecretCredential.create!(
      staff: operator,
      name: "Removal test secret credential #{SecureRandom.hex(4)}",
      password_digest: "digest",
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
    )
  end

  def ensure_operator_reference_records!
    OperatorStatus.find_or_create_by!(id: OperatorStatus::ACTIVE)
    [
      OperatorSecretCredentialStatus::ACTIVE,
      OperatorSecretCredentialStatus::DELETED,
      OperatorSecretCredentialStatus::REVOKED,
    ].each { |id| OperatorSecretCredentialStatus.find_or_create_by!(id: id) }
    OperatorSecretCredentialKind.find_or_create_by!(id: OperatorSecretCredentialKind::LOGIN)
  end

  # DAMP local helper copy for former shared test support.
  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end
end
