# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceWebCookieEndpointHarness < ApplicationController
  class << self
    def before_action(*) = nil
  end

  include PreferenceWebCookieEndpoint

  attr_accessor :consent_state_stub

  def consent_state_for_test(consented:, functional: false, performant: false, targetable: false)
    self.consent_state_stub = {
      consented: consented,
      functional: functional,
      performant: performant,
      targetable: targetable,
    }
  end

  private

  def cookie_consent_state
    consent_state_stub
  end
end

class PreferenceWebCookieEndpointTest < ActiveSupport::TestCase
  test "show_banner? is true when consent has not been recorded" do
    harness = PreferenceWebCookieEndpointHarness.new
    harness.consent_state_for_test(consented: false)

    assert harness.send(:show_banner?), "banner must show until the visitor has made a consent choice"
  end

  test "show_banner? is false once consent has been recorded" do
    harness = PreferenceWebCookieEndpointHarness.new
    harness.consent_state_for_test(consented: true)

    assert_not harness.send(:show_banner?), "banner must not show once consent has already been recorded"
  end
end
