# typed: false
# frozen_string_literal: true

require "test_helper"

# Recovery-passcode reveal on the corporate identity surface. The passcodes are
# shown once, after IdentityOneTimeReveal consumes the token issued at
# registration; a missing or already-consumed token still renders the page so
# the visitor is told the codes are gone rather than seeing a 404.
class Base::Com::Identity::SecretsControllerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < Base::Com::Identity::SecretsController
    attr_accessor :visitor, :params_hash, :rendered, :authorized

    def current_visitor = visitor

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def t(key, **) = key

    def base_com_identity_url(**)
      "/identity"
    end

    def render(**kwargs)
      self.rendered = kwargs
    end

    def authorize!(resource, to: nil)
      self.authorized = [resource, to]
      true
    end

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    @visitor = Visitor.create!(
      status_id: VisitorStatus::NOTHING,
      visibility_id: VisitorVisibility::VISITOR,
      mfa_level_id: VisitorMfaLevel::NOTHING,
      mfa_status_id: VisitorMfaStatus::UNCONFIGURED,
    )
    @harness = Harness.new
    @harness.visitor = @visitor
    @harness.params_hash = { token: "reveal-token", ri: "jp" }
  end

  test "show renders the consumed recovery passcodes for a valid reveal token" do
    payload = IdentityOneTimeReveal::Payload.new(value: %w(alpha bravo), metadata: {})

    IdentityOneTimeReveal.stub(:consume!, payload) do
      @harness.invoke(:show)
    end

    assert_equal({ inertia: true, props: @harness.invoke(:show_page_props) }, @harness.rendered)
    assert_equal %w(alpha bravo), @harness.invoke(:show_page_props).fetch(:passcodes)
    assert_equal "/identity", @harness.invoke(:show_page_props).dig(:back_link, :href)
  end

  test "show renders the missing-passcodes page when the reveal token is already spent" do
    IdentityOneTimeReveal.stub(:consume!, nil) do
      @harness.invoke(:show)
    end

    props = @harness.invoke(:show_page_props)

    assert_equal({ inertia: true, props: props }, @harness.rendered)
    assert_empty props.fetch(:passcodes)
    assert_equal "sign.recovery_passcodes.show.missing", props.fetch(:missing_message)
  end

  test "authorize_secrets! asks the policy whether the visitor may see the reveal" do
    @harness.invoke(:authorize_secrets!)

    assert_equal [@visitor, :show?], @harness.authorized
  end
end
