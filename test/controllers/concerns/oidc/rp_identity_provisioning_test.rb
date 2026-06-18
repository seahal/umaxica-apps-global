# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcRpIdentityProvisioningTest < ActiveSupport::TestCase
  setup do
    ClientIdentityState.ensure_defaults!
    VisitorIdentityState.ensure_defaults!
    OperatorIdentityState.ensure_defaults!
  end

  test "core app callback provisioning records id token identity and core bridge" do
    client = clients(:one)
    ClientIdentity.where(source_record_id: client.id).delete_all
    CoreAppClientBridge.where(client_id: client.id).delete_all
    controller = Core::App::Auth::CallbacksController.new

    actor = controller.send(
      :provision_rp_account_from_id_token!, {
      "iss" => OidcIssuer.for_client(OidcClientRegistry.find!("core-next-rp")),
      "sub" => OidcSubject.for(client, resource_type: "client"),
      "aud" => "core-next-rp",
    },
    )

    identity = ClientIdentity.find_by!(source_record_id: client.id)
    bridge = CoreAppClientBridge.find_by!(client_id: client.id)

    assert_equal client, actor
    assert_equal OidcIssuer.for_client(OidcClientRegistry.find!("core-next-rp")), identity.issuer
    assert_equal OidcSubject.for(client, resource_type: "client"), identity.subject
    assert_equal "core-next-rp", identity.audience
    assert_equal ClientIdentityState::ACTIVE, identity.status_id
    assert_equal "core-next-rp", bridge.rp_client_id
    assert_equal client.public_id, bridge.subject
  end

  test "core app callback provisioning can resolve an opaque subject through an existing identity" do
    client = clients(:two)
    ClientIdentity.where(source_record_id: client.id).delete_all
    CoreAppClientBridge.where(client_id: client.id).delete_all
    ClientIdentity.create!(
      issuer: "umaxica-auth:client",
      subject: "opaque-idp-subject",
      audience: "core-next-rp",
      source_record_id: client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    controller = Core::App::Auth::CallbacksController.new

    actor = controller.send(
      :provision_rp_account_from_id_token!, {
      "iss" => "umaxica-auth:client",
      "sub" => "opaque-idp-subject",
      "aud" => "core-next-rp",
    },
    )

    assert_equal client, actor
    assert_equal 1, ClientIdentity.where(source_record_id: client.id).count
    assert_predicate CoreAppClientBridge.find_by!(client_id: client.id), :core?
  end

  test "acme com callback provisioning records visitor identity without a core bridge" do
    visitor = Visitor.create!
    VisitorIdentity.where(source_record_id: visitor.id).delete_all
    controller = Acme::Com::Auth::CallbacksController.new

    actor = controller.send(
      :provision_rp_account_from_id_token!, {
      "iss" => OidcIssuer.for_client(OidcClientRegistry.find!("base-rails-rp")),
      "sub" => OidcSubject.for(visitor, resource_type: "visitor"),
      "aud" => "base-rails-rp",
    },
    )

    identity = VisitorIdentity.find_by!(source_record_id: visitor.id)

    assert_equal visitor, actor
    assert_equal "base-rails-rp", identity.audience
    assert_equal VisitorIdentityState::ACTIVE, identity.status_id
    assert_nil CoreComVisitorBridge.find_by(visitor_id: visitor.id)
  end
end
