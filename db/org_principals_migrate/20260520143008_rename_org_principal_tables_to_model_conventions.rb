# frozen_string_literal: true

class RenameOrgPrincipalTablesToModelConventions < ActiveRecord::Migration[8.2]
  def up
    rename_table_strict :staff_banners, :operator_banners
    rename_table_strict :staff_bulletins, :operator_bulletins
    rename_table_strict :staff_email_statuses, :operator_email_statuses
    rename_table_strict :staff_emails, :operator_emails
    rename_table_strict :staff_multi_factor_statuses, :operator_multi_factor_statuses
    rename_table_strict :staff_multi_factors, :operator_multi_factors
    rename_table_strict :staff_passkey_statuses, :operator_passkey_statuses
    rename_table_strict :staff_passkeys, :operator_passkeys
    rename_table_strict :staff_preference_currencies, :operator_preference_currencies
    rename_table_strict :staff_preference_currency_options, :operator_preference_currency_options
    rename_table_strict :staff_preference_date_format_options, :operator_preference_date_format_options
    rename_table_strict :staff_preference_date_formats, :operator_preference_date_formats
    rename_table_strict :staff_preference_densities, :operator_preference_densities
    rename_table_strict :staff_preference_density_options, :operator_preference_density_options
    rename_table_strict :staff_preference_items_per_page_options, :operator_preference_items_per_page_options
    rename_table_strict :staff_preference_items_per_pages, :operator_preference_items_per_pages
    rename_table_strict :staff_preference_language_options, :operator_preference_language_options
    rename_table_strict :staff_preference_languages, :operator_preference_languages
    rename_table_strict :staff_preference_motion_options, :operator_preference_motion_options
    rename_table_strict :staff_preference_motions, :operator_preference_motions
    rename_table_strict :staff_preference_region_options, :operator_preference_region_options
    rename_table_strict :staff_preference_regions, :operator_preference_regions
    rename_table_strict :staff_preference_theme_options, :operator_preference_theme_options
    rename_table_strict :staff_preference_themes, :operator_preference_themes
    rename_table_strict :staff_preference_time_format_options, :operator_preference_time_format_options
    rename_table_strict :staff_preference_time_formats, :operator_preference_time_formats
    rename_table_strict :staff_preference_timezone_options, :operator_preference_timezone_options
    rename_table_strict :staff_preference_timezones, :operator_preference_timezones
    rename_table_strict :staff_preferences, :operator_preferences
    rename_table_strict :staff_secret_kinds, :operator_secret_kinds
    rename_table_strict :staff_secret_statuses, :operator_secret_statuses
    rename_table_strict :staff_secrets, :operator_secrets
    rename_table_strict :staff_statuses, :operator_identity_statuses
    rename_table_strict :staff_telephone_statuses, :operator_telephone_statuses
    rename_table_strict :staff_telephones, :operator_telephones
    rename_table_strict :staff_visibilities, :operator_visibilities
  end

  def down
    rename_table_strict :operator_visibilities, :staff_visibilities
    rename_table_strict :operator_telephones, :staff_telephones
    rename_table_strict :operator_telephone_statuses, :staff_telephone_statuses
    rename_table_strict :operator_identity_statuses, :staff_statuses
    rename_table_strict :operator_secrets, :staff_secrets
    rename_table_strict :operator_secret_statuses, :staff_secret_statuses
    rename_table_strict :operator_secret_kinds, :staff_secret_kinds
    rename_table_strict :operator_preferences, :staff_preferences
    rename_table_strict :operator_preference_timezones, :staff_preference_timezones
    rename_table_strict :operator_preference_timezone_options, :staff_preference_timezone_options
    rename_table_strict :operator_preference_time_formats, :staff_preference_time_formats
    rename_table_strict :operator_preference_time_format_options, :staff_preference_time_format_options
    rename_table_strict :operator_preference_themes, :staff_preference_themes
    rename_table_strict :operator_preference_theme_options, :staff_preference_theme_options
    rename_table_strict :operator_preference_regions, :staff_preference_regions
    rename_table_strict :operator_preference_region_options, :staff_preference_region_options
    rename_table_strict :operator_preference_motions, :staff_preference_motions
    rename_table_strict :operator_preference_motion_options, :staff_preference_motion_options
    rename_table_strict :operator_preference_languages, :staff_preference_languages
    rename_table_strict :operator_preference_language_options, :staff_preference_language_options
    rename_table_strict :operator_preference_items_per_pages, :staff_preference_items_per_pages
    rename_table_strict :operator_preference_items_per_page_options, :staff_preference_items_per_page_options
    rename_table_strict :operator_preference_density_options, :staff_preference_density_options
    rename_table_strict :operator_preference_densities, :staff_preference_densities
    rename_table_strict :operator_preference_date_formats, :staff_preference_date_formats
    rename_table_strict :operator_preference_date_format_options, :staff_preference_date_format_options
    rename_table_strict :operator_preference_currency_options, :staff_preference_currency_options
    rename_table_strict :operator_preference_currencies, :staff_preference_currencies
    rename_table_strict :operator_passkeys, :staff_passkeys
    rename_table_strict :operator_passkey_statuses, :staff_passkey_statuses
    rename_table_strict :operator_multi_factors, :staff_multi_factors
    rename_table_strict :operator_multi_factor_statuses, :staff_multi_factor_statuses
    rename_table_strict :operator_emails, :staff_emails
    rename_table_strict :operator_email_statuses, :staff_email_statuses
    rename_table_strict :operator_bulletins, :staff_bulletins
    rename_table_strict :operator_banners, :staff_banners
  end
end
