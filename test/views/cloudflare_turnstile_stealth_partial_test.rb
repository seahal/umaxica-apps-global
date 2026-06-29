# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CloudflareTurnstileStealthPartialTest < ActionView::TestCase
  test "renders widget controls without loading the api script" do
    render partial: "shared/cloudflare_turnstile_stealth"

    assert_select "[data-controller='turnstile'][data-turnstile-mode-value='execute']"
    assert_select ".cf-turnstile[data-sitekey]"
    assert_select "input[name='cf-turnstile-response'][type='hidden']"
    assert_no_match(/challenges\.cloudflare\.com\/turnstile\/v0\/api\.js/, rendered)
  end
end
