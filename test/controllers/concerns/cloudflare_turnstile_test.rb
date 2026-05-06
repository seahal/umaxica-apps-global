# typed: false
# frozen_string_literal: true

require "test_helper"

class CloudflareTurnstileTest < ActionDispatch::IntegrationTest
  class TestController < ApplicationController
    include CloudflareTurnstile

    public :cloudflare_turnstile_validation, :cloudflare_turnstile_stealth_validation, :verify_turnstile_stealth!
  end

  setup do
    @controller = TestController.new
    @request = ActionDispatch::TestRequest.create
    @controller.request = @request
  end

  test "validation in test mode" do
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }

    assert_equal({ "success" => true }, @controller.cloudflare_turnstile_validation)
  end

  test "validation in real mode calls verifier" do
    CloudflareTurnstile.test_mode = false
    @controller.stub(:params, { "cf-turnstile-response" => "tok" }) do
      Jit::Security::TurnstileVerifier.stub(:verify, { "success" => true }) do
        assert_equal({ "success" => true }, @controller.cloudflare_turnstile_validation)
      end
    end
  end

  test "verify_turnstile_stealth! failure" do
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => false }

    @controller.stub(:render, true) do
      assert_not @controller.verify_turnstile_stealth!
    end
  end
end
