# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class CloudflareTurnstileVisiblePartialTest < ActionView::TestCase
  test "renders optional ceremony binding attributes" do
    render(
      partial: "shared/cloudflare_turnstile_visible",
      locals: {
        turnstile_action: "social_signup_confirmation",
        turnstile_cdata: "cycle-public-id",
      },
    )

    assert_select "[data-controller='turnstile'][data-turnstile-mode-value='render']"
    assert_select "[data-turnstile-action-value='social_signup_confirmation']"
    assert_select "[data-turnstile-cdata-value='cycle-public-id']"
    assert_select "input[name='cf-turnstile-response'][type='hidden']"
    assert_no_match(/challenges\.cloudflare\.com\/turnstile\/v0\/api\.js/, rendered)
  end

  test "omits ceremony binding attributes by default" do
    render partial: "shared/cloudflare_turnstile_visible"

    assert_select "[data-controller='turnstile'][data-turnstile-mode-value='render']"
    assert_select "[data-turnstile-action-value]", false
    assert_select "[data-turnstile-cdata-value]", false
    assert_no_match(/challenges\.cloudflare\.com\/turnstile\/v0\/api\.js/, rendered)
  end
end
