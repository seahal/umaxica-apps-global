# typed: false
# frozen_string_literal: true

require "test_helper"

# The last set of one-line delegations: the identity-authority alias each OIDC
# concern exposes, the preference index each surface returns to, the DBSC
# registration endpoint of the corporate token surface, and the staff Entra
# settings page payload.
class RemainingSurfaceSeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "the oidc concerns expose the identity authority host under their acme alias" do
    [OidcRpLogoutLauncher, OidcSsoInitiator].each do |concern|
      # These concerns register surface callbacks on inclusion, so they are
      # included into a surface controller that already provides them.
      subject = Class.new(Base::App::ApplicationController) do
        include concern

        def oidc_base_authority_host = "www.example"
      end.new

      assert_equal "www.example", subject.send(:oidc_acme_host), concern.name
    end
  end

  test "the preference index path is the preference index url of the same surface" do
    subject = Class.new(ApplicationController) do
      include PreferenceSignScreenActions

      def preference_index_url = "https://auth.example/preferences"
    end.new

    assert_equal "https://auth.example/preferences", subject.send(:preference_index_path)
  end

  test "the corporate token surface registers dbsc against its own endpoint" do
    subject = Class.new(Auth::Com::Edge::V0::Token::DbscController) do
      def invoke(name, ...) = send(name, ...)
    end.new
    subject.request = ActionDispatch::TestRequest.create

    assert_includes subject.invoke(:dbsc_url), "/edge/v0/token/dbsc"
  end

  test "the staff entra settings page reports whether the account is connected" do
    subject = Class.new(Auth::Org::Settings::EntrasController) do
      attr_accessor :params_hash

      def params
        ActionController::Parameters.new(params_hash || {})
      end

      def entra_start_available? = true

      def invoke(name, ...) = send(name, ...)
    end.new
    subject.params_hash = { ri: "jp" }
    subject.request = ActionDispatch::TestRequest.create
    subject.instance_variable_set(:@entra_identity, nil)

    props = subject.invoke(:entra_edit_props)

    assert_equal "Microsoft Entra ID", props.fetch(:title)
  end
end
