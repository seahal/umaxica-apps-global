# typed: false
# == Schema Information
#
# Table name: app_preferences
# Database name: principal
#
#  id                       :bigint           not null, primary key
#  compromised_at           :datetime
#  dbsc_challenge           :text
#  dbsc_challenge_issued_at :datetime
#  dbsc_public_key          :jsonb
#  device_id_digest         :string
#  expires_at               :datetime
#  jti                      :string
#  revoked_at               :datetime
#  token_digest             :binary
#  used_at                  :datetime
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  binding_method_id        :bigint           default(0), not null
#  dbsc_session_id          :string
#  dbsc_status_id           :bigint           default(0), not null
#  device_id                :string
#  public_id                :string           not null
#  replaced_by_id           :bigint
#  status_id                :bigint           default(0), not null
#
# Indexes
#
#  index_app_preferences_on_binding_method_id  (binding_method_id)
#  index_app_preferences_on_dbsc_session_id    (dbsc_session_id) UNIQUE
#  index_app_preferences_on_dbsc_status_id     (dbsc_status_id)
#  index_app_preferences_on_device_id          (device_id)
#  index_app_preferences_on_device_id_digest   (device_id_digest)
#  index_app_preferences_on_jti                (jti) UNIQUE
#  index_app_preferences_on_public_id          (public_id) UNIQUE
#  index_app_preferences_on_replaced_by_id     (replaced_by_id)
#  index_app_preferences_on_revoked_at         (revoked_at)
#  index_app_preferences_on_status_id          (status_id)
#  index_app_preferences_on_token_digest       (token_digest)
#  index_app_preferences_on_used_at            (used_at)
#
# Foreign Keys
#
#  fk_app_preferences_on_binding_method_id  (binding_method_id => app_preference_binding_methods.id)
#  fk_app_preferences_on_dbsc_status_id     (dbsc_status_id => app_preference_dbsc_statuses.id)
#  fk_app_preferences_on_status_id          (status_id => app_preference_statuses.id)
#  fk_rails_...                             (replaced_by_id => app_preferences.id) ON DELETE => nullify
#

# frozen_string_literal: true

require "test_helper"

class AppPreferenceTest < ActiveSupport::TestCase
  setup do
    AppPreferenceStatus.find_or_create_by!(id: AppPreferenceStatus::NOTHING)
  end

  test "generates public_id on create" do
    preference = AppPreference.create!

    assert_not_nil preference.public_id
    assert_equal 21, preference.public_id.length
  end

  test "validates public_id maximum length" do
    preference = AppPreference.new(public_id: "a" * 22)

    assert_not preference.valid?
    assert_includes preference.errors[:public_id], "は21文字以内で入力してください"
  end

  test "does not overwrite existing public_id" do
    custom_id = "custom_public_id_123"
    preference = AppPreference.create!(public_id: custom_id)

    assert_equal custom_id, preference.public_id
  end

  test "has one app_preference_cookie" do
    preference = AppPreference.create!
    cookie = preference.create_app_preference_cookie!

    assert_equal cookie, preference.app_preference_cookie
  end

  test "destroys app_preference_cookie when destroyed" do
    preference = AppPreference.create!
    cookie = preference.create_app_preference_cookie!
    cookie_id = cookie.id
    preference.destroy!

    assert_nil AppPreferenceCookie.find_by(id: cookie_id)
  end

  test "has one app_preference_region" do
    preference = AppPreference.create!
    option = app_preference_region_options(:jp)
    region = preference.create_app_preference_region!(option: option)

    assert_equal region, preference.app_preference_region
  end

  test "destroys app_preference_region when destroyed" do
    preference = AppPreference.create!
    option = app_preference_region_options(:jp)
    region = preference.create_app_preference_region!(option: option)
    region_id = region.id
    preference.destroy!

    assert_nil AppPreferenceRegion.find_by(id: region_id)
  end

  test "has one app_preference_timezone" do
    preference = AppPreference.create!
    option = app_preference_timezone_options(:asia_tokyo)
    timezone = preference.create_app_preference_timezone!(option: option)

    assert_equal timezone, preference.app_preference_timezone
  end

  test "destroys app_preference_timezone when destroyed" do
    preference = AppPreference.create!
    option = app_preference_timezone_options(:asia_tokyo)
    timezone = preference.create_app_preference_timezone!(option: option)
    timezone_id = timezone.id
    preference.destroy!

    assert_nil AppPreferenceTimezone.find_by(id: timezone_id)
  end

  test "has one app_preference_language" do
    preference = AppPreference.create!
    option = app_preference_language_options(:ja)
    language = preference.create_app_preference_language!(option: option)

    assert_equal language, preference.app_preference_language
  end

  test "destroys app_preference_language when destroyed" do
    preference = AppPreference.create!
    option = app_preference_language_options(:ja)
    language = preference.create_app_preference_language!(option: option)
    language_id = language.id
    preference.destroy!

    assert_nil AppPreferenceLanguage.find_by(id: language_id)
  end

  test "has one app_preference_colortheme" do
    preference = AppPreference.create!
    option = app_preference_colortheme_options(:light)
    colortheme = preference.create_app_preference_colortheme!(option: option)

    assert_equal colortheme, preference.app_preference_colortheme
  end

  test "destroys app_preference_colortheme when destroyed" do
    preference = AppPreference.create!
    option = app_preference_colortheme_options(:light)
    colortheme = preference.create_app_preference_colortheme!(option: option)
    colortheme_id = colortheme.id
    preference.destroy!

    assert_nil AppPreferenceColortheme.find_by(id: colortheme_id)
  end

  test "consume_once_by_digest! marks token used only once" do
    digest = AppPreference.digest_refresh_token("app-consume-once")
    preference = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      expires_at: 1.day.from_now,
      token_digest: digest,
      jti: SecureRandom.uuid,
      device_id: SecureRandom.uuid,
    )

    consumed = AppPreference.consume_once_by_digest!(digest: digest)

    assert_equal preference.id, consumed.id
    assert_predicate consumed.used_at, :present?

    second = AppPreference.consume_once_by_digest!(digest: digest)

    assert_nil second
    assert_predicate preference.reload, :replay?
  end

  test "consume_once_by_digest! rejects revoked compromised and expired rows" do
    revoked_digest = AppPreference.digest_refresh_token("revoked")
    compromised_digest = AppPreference.digest_refresh_token("compromised")
    expired_digest = AppPreference.digest_refresh_token("expired")

    AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      expires_at: 1.day.from_now,
      token_digest: revoked_digest,
      revoked_at: Time.current,
      jti: SecureRandom.uuid,
      device_id: SecureRandom.uuid,
    )
    AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      expires_at: 1.day.from_now,
      token_digest: compromised_digest,
      compromised_at: Time.current,
      jti: SecureRandom.uuid,
      device_id: SecureRandom.uuid,
    )
    AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      expires_at: 1.minute.ago,
      token_digest: expired_digest,
      jti: SecureRandom.uuid,
      device_id: SecureRandom.uuid,
    )

    assert_nil AppPreference.consume_once_by_digest!(digest: revoked_digest)
    assert_nil AppPreference.consume_once_by_digest!(digest: compromised_digest)
    assert_nil AppPreference.consume_once_by_digest!(digest: expired_digest)
  end

  test "revoked? reflects revoked and compromised timestamps" do
    preference = AppPreference.new

    assert_not preference.revoked?

    preference.revoked_at = Time.current

    assert_predicate preference, :revoked?

    preference.revoked_at = nil
    preference.compromised_at = Time.current

    assert_predicate preference, :revoked?
  end

  test "rotate! creates replacement and links replaced_by_id" do
    digest = AppPreference.digest_refresh_token("rotate-me")
    preference = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      expires_at: 1.day.from_now,
      token_digest: digest,
      jti: SecureRandom.uuid,
      device_id: "device-1",
    )

    rotated = AppPreference.rotate!(presented_digest: digest, device_id: "device-1", now: Time.current)

    assert_predicate rotated, :present?
    assert_predicate rotated.issued_refresh_token, :present?
    assert_not_equal preference.id, rotated.id
    assert_equal preference.status_id, rotated.status_id
    assert_equal "device-1", rotated.device_id
    assert_predicate rotated.token_digest, :present?
    assert_equal rotated.id, preference.reload.replaced_by_id
  end

  test "migrate_preference_children! moves child preference reference" do
    child = Struct.new(:preference_id) do
      define_method(:update!) do |attributes|
        self.preference_id = attributes.fetch(:preference_id)
      end
    end.new(1)
    from = Struct.new(:app_preference_cookie) do
      define_singleton_method(:model_name) do
        ActiveModel::Name.new(AppPreference)
      end
    end.new(child)
    to = Struct.new(:id).new(2)

    AppPreference.send(:migrate_preference_children!, from: from, to: to)

    assert_equal 2, child.preference_id
  end
end
