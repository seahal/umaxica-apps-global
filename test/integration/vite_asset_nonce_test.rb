# typed: false
# frozen_string_literal: true

require "test_helper"

# `script-src` carries `'strict-dynamic'`, which makes the browser ignore every host and scheme
# source in that directive. A nonce is therefore the only thing that admits an asset tag, including
# the `<link rel="modulepreload">` tags `vite_javascript_tag` emits alongside the entrypoint script.
#
# Rails resolves `nonce: true` inside `javascript_include_tag` and `stylesheet_link_tag`, but
# vite_rails builds the preload links with `tag.link` and forwards the option untouched, so
# `nonce: true` renders the literal string "true" and the preload is refused. The layouts pass
# `content_security_policy_nonce` for that reason; this test is what keeps them from drifting back.
class ViteAssetNonceTest < ActionDispatch::IntegrationTest
  setup do
    @host = Rails.configuration.x.boot_config.fetch(:hosts).base_service.host
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
  end

  test "every Vite asset tag on an Inertia page carries the response nonce" do
    get(base_app_groups_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host))

    assert_response :success

    nonce = response_nonce

    assert_predicate nonce, :present?

    tags = asset_tags

    assert_operator tags.count { |tag| tag["rel"] == "modulepreload" }, :>=, 1,
                    "expected the entrypoint to emit modulepreload links, otherwise this test proves nothing"

    tags.each do |tag|
      assert_equal nonce, tag["nonce"],
                   "#{tag.name} tag for #{tag["src"] || tag["href"]} does not carry the response CSP nonce"
    end
  end

  private

  def response_nonce
    response.headers["Content-Security-Policy"][/script-src[^;]*'nonce-([^']+)'/, 1]
  end

  def asset_tags
    document = response.parsed_body

    document.css("script[src], link[rel='modulepreload'], link[rel='stylesheet']").to_a
  end
end
