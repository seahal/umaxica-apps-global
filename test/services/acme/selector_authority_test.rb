# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Selector::AuthorityTest < ActiveSupport::TestCase
  setup do
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    Acme::Selector::BootstrapAuthority.call(surface: :app, principal: @user)
  end

  test "auto selects when only one valid candidate exists" do
    result = Acme::Selector::Authority.prepare(surface: :app, principal: @user, session: @token)

    assert_equal "selected", result[:status]
    assert_equal "/dashboard", result[:next]
    assert_predicate @token.reload, :selected_actor_context?
    assert_predicate @token.selected_avatar_public_id, :present?
  end

  test "returns selection required when multiple valid candidates exist" do
    persona = Persona.first
    enterprise = Enterprise.create!(name: "Second")
    unit = EnterpriseUnit.create!(enterprise: enterprise, name: "Default")
    PersonaMembership.create!(
      persona: persona,
      enterprise: enterprise,
      enterprise_unit: unit,
      membership_kind_id: PersonaMembershipKind::OWNER,
      membership_state_id: PersonaMembershipState::ACTIVE,
      primary: false,
      metadata: {},
    )
    handle = Handle.create!(
      handle: "second-#{SecureRandom.hex(5)}", handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
    )
    Avatar.create_with_owner(
      {
        moniker: "Second Avatar",
        active_handle: handle,
        capability_id: AvatarCapability::NORMAL,
        client_id: @user.id,
        owner_organization_id: enterprise.public_id,
        representing_organization_id: enterprise.public_id,
        image_data: {},
      },
      @user,
    )

    result = Acme::Selector::Authority.prepare(surface: :app, principal: @user, session: @token)

    assert_equal "selection_required", result[:status]
    assert_equal 2, result[:accounts].size
  end

  test "rejects another identity selection" do
    other = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    Acme::Selector::BootstrapAuthority.call(surface: :app, principal: other)
    other_candidate = Acme::Selector::Authority.new(
      surface: :app, principal: other,
      session: ClientToken.create!(user: other),
    )
      .selectable_candidates
      .first

    assert_raises Acme::Selector::Authority::InvalidSelection do
      Acme::Selector::Authority.select(
        surface: :app,
        principal: @user,
        session: @token,
        params: other_candidate[:public],
      )
    end
  end

  test "rejects inconsistent account organization avatar combination" do
    candidate = Acme::Selector::Authority.new(
      surface: :app, principal: @user,
      session: @token,
    ).selectable_candidates.first
    enterprise = Enterprise.create!(name: "Foreign Combination")
    unit = EnterpriseUnit.create!(enterprise: enterprise, name: "Default")

    params = candidate[:public].merge(
      organization_public_id: enterprise.public_id,
      organization_unit_public_id: unit.public_id,
    )

    assert_raises Acme::Selector::Authority::InvalidSelection do
      Acme::Selector::Authority.select(surface: :app, principal: @user, session: @token, params: params)
    end
  end
end
