# typed: false
# frozen_string_literal: true

require "test_helper"

# Two seams are redeclared once per surface controller: the host an OIDC hand-off
# is addressed to, and the path the sign-out confirmation form posts back to. Each
# is a single line, so a copy that names the wrong surface reads as plausible and
# only shows up as a cross-surface redirect in production. This sweep calls every
# copy and pins which surface it answers.
class SurfaceUrlSeamSweepTest < ActiveSupport::TestCase
  OIDC_AUTHORITY_HOSTS = {
    "Base::App::ApplicationController" => "PUBLIC_BASE_SERVICE_URL",
    "Base::Com::ApplicationController" => "PUBLIC_BASE_CORPORATE_URL",
    "Base::Org::ApplicationController" => "PUBLIC_BASE_STAFF_URL",
    "Core::App::ApplicationController" => "PRIVATE_BASE_SERVICE_URL",
    "Core::Com::ApplicationController" => "PRIVATE_BASE_CORPORATE_URL",
    "Core::Org::ApplicationController" => "PRIVATE_BASE_STAFF_URL",
    "Side::App::ApplicationController" => "PRIVATE_BASE_SERVICE_URL",
    "Side::Com::ApplicationController" => "PRIVATE_BASE_CORPORATE_URL",
    "Side::Org::ApplicationController" => "PRIVATE_BASE_STAFF_URL",
    "Palm::App::Oidc::AuthorizationsController" => "PUBLIC_BASE_SERVICE_URL",
  }.freeze

  # Every surface mounts sign-out at the same path on its own host, so the path
  # alone cannot show a mix-up. The route helper prefix is what differs, and it is
  # what decides which host the form posts to.
  SIGN_OUT_FORM_PREFIXES = {
    "Auth::Com::Sign::OutsController" => "auth_com",
    "Base::App::SignOutsController" => "base_app",
    "Base::Com::SignOutsController" => "base_com",
    "Base::Org::SignOutsController" => "base_org",
    "Core::Com::Sign::OutsController" => "core_com",
    "Core::Org::Sign::OutsController" => "core_org",
    "Side::App::Sign::OutsController" => "side_app",
    "Side::Com::Sign::OutsController" => "side_com",
    "Side::Org::Sign::OutsController" => "side_org",
  }.freeze

  def allocate_context(class_name)
    context = class_name.constantize.allocate
    context.set_request!(ActionDispatch::TestRequest.create)
    context.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    context
  end

  OIDC_AUTHORITY_HOSTS.each do |class_name, env_name|
    test "#{class_name} addresses the OIDC hand-off at #{env_name}" do
      context = allocate_context(class_name)

      assert_equal ENV.fetch(env_name), context.send(:oidc_acme_host)
      assert_equal ENV.fetch(env_name), context.send(:oidc_base_authority_host)
    end
  end

  SIGN_OUT_FORM_PREFIXES.each do |class_name, expected_prefix|
    test "#{class_name} posts its sign-out confirmation back to its own surface" do
      context = allocate_context(class_name)

      assert_equal expected_prefix, context.send(:sign_out_route_helper_prefix)
      assert_equal "/sign/out?ri=jp", context.send(:sign_out_confirmation_form_path),
                   "the confirmation form must carry the region through to the post target"
    end
  end
end
