# typed: false
# frozen_string_literal: true

namespace :preference do
  desc "Migrate ClientAppPreference/StaffOrgPreference data to ClientPreference/StaffPreference"
  task migrate_to_user_staff: :environment do
    migrate_user_preferences!
    migrate_staff_preferences!
  end

  define_method(:migrate_user_preferences!) do
    puts I18n.t("tasks.preference_migration.migrating_user_app_preference")

    migrated = 0
    skipped = 0

    # Find the most recent ClientAppPreference for each user
    ClientAppPreference.select("DISTINCT ON (user_id) *")
      .order(:user_id, created_at: :desc)
      .find_each do |join_record|
      next if ClientPreference.exists?(user_id: join_record.user_id)

      app_pref = join_record.app_preference
      next if app_pref.blank?

      PrincipalRecord.connected_to(role: :writing) do
        user_pref = ClientPreference.create!(user_id: join_record.user_id)
        copy_preference_options!(app_pref, user_pref, "App", "User")
        copy_cookie_consent_to_user_pref!(app_pref, user_pref)
        migrated += 1
      end
    rescue StandardError => e
      puts I18n.t("tasks.preference_migration.warn_user") % {
        user_id: join_record.user_id,
        message: e.message,
      }
      skipped += 1
    end

    puts I18n.t("tasks.preference_migration.done_user") % { migrated: migrated, skipped: skipped }
  end

  define_method(:migrate_staff_preferences!) do
    puts I18n.t("tasks.preference_migration.migrating_staff_org_preference")

    migrated = 0
    skipped = 0

    StaffOrgPreference.select("DISTINCT ON (staff_id) *")
      .order(:staff_id, created_at: :desc)
      .find_each do |join_record|
      next if StaffPreference.exists?(staff_id: join_record.staff_id)

      org_pref = join_record.org_preference
      next if org_pref.blank?

      PrincipalRecord.connected_to(role: :writing) do
        staff_pref = StaffPreference.create!(staff_id: join_record.staff_id)
        copy_preference_options!(org_pref, staff_pref, "Org", "Staff")
        copy_cookie_consent_to_staff_pref!(org_pref, staff_pref)
        migrated += 1
      end
    rescue StandardError => e
      puts I18n.t("tasks.preference_migration.warn_staff") % {
        staff_id: join_record.staff_id,
        message: e.message,
      }
      skipped += 1
    end

    puts I18n.t("tasks.preference_migration.done_user") % { migrated: migrated, skipped: skipped }
  end

  define_method(:copy_preference_options!) do |source_pref, target_pref, _source_prefix, target_prefix|
    source_assoc = source_pref.class.name.underscore

    %w(language timezone region theme).each do |type|
      source_child = source_pref.public_send("#{source_assoc}_#{type}")
      next unless source_child&.option_id

      source_option = source_child.option
      next unless source_option&.name

      target_option_class = Preference::ClassRegistry.option_class(target_prefix, type)
      target_option_class.ensure_defaults!
      target_option = target_option_class.find_each.find { |o| o.name&.downcase == source_option.name.downcase }
      next unless target_option

      Preference::ClassRegistry.record_class(target_prefix, type).create!(
        preference_id: target_pref.id,
        option_id: target_option.id,
      )
    end
  end

  define_method(:copy_cookie_consent_to_user_pref!) do |app_pref, user_pref|
    cookie = app_pref.app_preference_cookie
    return unless cookie

    user_pref.update!(
      consented: cookie.consented,
      functional: cookie.functional,
      performant: cookie.performant,
      targetable: cookie.targetable,
      consented_at: cookie.consented_at,
      consent_version: cookie.consent_version,
    )
  end

  define_method(:copy_cookie_consent_to_staff_pref!) do |org_pref, staff_pref|
    cookie = org_pref.org_preference_cookie
    return unless cookie

    staff_pref.update!(
      consented: cookie.consented,
      functional: cookie.functional,
      performant: cookie.performant,
      targetable: cookie.targetable,
      consented_at: cookie.consented_at,
      consent_version: cookie.consent_version,
    )
  end
end
