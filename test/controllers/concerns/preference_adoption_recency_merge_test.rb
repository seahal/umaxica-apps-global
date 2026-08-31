# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/preference_lifecycle_surfaces"

# At sign-in the browser-scoped preference and the account-scoped one are merged
# per key. When only one side was set on purpose that side wins outright; when
# both were, the more recently set one wins. That last case is the only one where
# the merge can silently discard a deliberate choice, and it had no coverage.
class PreferenceAdoptionRecencyMergeTest < ActiveSupport::TestCase
  fixtures :app_preference_statuses, :app_preference_binding_methods, :app_preference_dbsc_statuses

  class Harness
    include ::PreferenceAdoption

    attr_accessor :preferences

    def invoke(name, ...) = send(name, ...)

    def preference_class = AppPreference

    def preference_prefix(preference = nil) = preference.present? ? preference.class.name.gsub("Preference", "") : "App"

    def resource_pref_prefix = "Client"

    def with_preference_writing_connection(*) = yield

    # Both sides live in the same database under test, so there is no separate
    # connection to switch to; the branch that writes directly is the live one.
    def preference_connection_class(*) = nil
  end

  setup do
    PreferenceClassRegistry.option_class("App", :language).ensure_defaults!
    PreferenceClassRegistry.option_class("Client", :language).ensure_defaults!
    @browser = PreferenceLifecycleSurfaces.new_token_preference(:app, with_default_children: true)
    PreferenceLifecycleSurfaces.set_language!(@browser, PreferenceLifecycleSurfaces::JA)
    @client = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    @principal = ClientPreference.create!(user_id: @client.id)
    @principal.user_preference_language ||
      @principal.create_user_preference_language!(option_id: PreferenceLifecycleSurfaces::EN)
    @harness = Harness.new
    @harness.preferences = @browser
    @harness.instance_variable_set(:@preferences, @browser)
  end

  def mark_both_explicit!
    @browser.mark_field_explicit!(:language)
    @principal.mark_field_explicit!(:language)
  end

  test "when both sides were set on purpose the more recent one wins" do
    mark_both_explicit!
    @principal.user_preference_language.update!(updated_at: 2.hours.ago)
    @browser.app_preference_language.update!(updated_at: 1.minute.ago)

    @harness.invoke(:reconcile_preference_key!, @principal, :language)

    assert_equal PreferenceLifecycleSurfaces::JA, @principal.reload.user_preference_language.reload.option_id,
                 "the browser side was set more recently, so it wins"
  end

  test "when both sides were set on purpose the older browser choice does not overwrite the account" do
    mark_both_explicit!
    @principal.user_preference_language.update!(updated_at: 1.minute.ago)
    @browser.app_preference_language.update!(updated_at: 2.hours.ago)

    @harness.invoke(:reconcile_preference_key!, @principal, :language)

    assert_equal PreferenceLifecycleSurfaces::EN, @principal.reload.user_preference_language.reload.option_id
    assert_equal PreferenceLifecycleSurfaces::EN, @browser.reload.app_preference_language.reload.option_id,
                 "the account side wins, so it is the browser that is brought into line"
  end

  test "an account row with no timestamp is never overwritten by a browser marker" do
    mark_both_explicit!
    @browser.app_preference_language.update!(updated_at: 1.minute.ago)

    assert_equal :principal,
                 @harness.invoke(:key_recency_winner, @browser.app_preference_language, Struct.new(:updated_at).new(nil))
  end

  test "a key neither side carries is left alone" do
    assert_nil @harness.invoke(:reconcile_preference_key!, @principal, :not_a_preference_key)
  end
end
