# typed: false
# frozen_string_literal: true

module Preference::SignScreenActions
  extend ActiveSupport::Concern
  include Preference::Core

  protected

  def edit_region_preference_screen
    set_region_preferences_edit
  end

  def update_region_preference_screen
    set_region_preferences_update
    redirect_to(
      preference_edit_url(:region, updated_region_redirect_params),
      notice: preference_update_notice,
    )
  end

  def edit_language_preference_screen
    set_language_preferences_edit
  end

  def update_language_preference_screen
    set_language_preferences_update
    apply_language_preference_to_session
    redirect_to(
      preference_edit_url(:language, language_preference_redirect_params),
      notice: preference_update_notice,
    )
  end

  def edit_timezone_preference_screen
    set_timezone_preferences_edit
  end

  def update_timezone_preference_screen
    set_timezone_preferences_update
    redirect_to(
      preference_edit_url(:timezone, preference_write_redirect_params(except: :tz)),
      notice: preference_update_notice,
    )
  rescue PreferenceOperationError
    redirect_to(
      preference_edit_url(:timezone, preference_write_redirect_params(except: :tz)),
      alert: preference_operation_failed_alert,
    )
  end

  def edit_theme_preference_screen
    set_colortheme_preferences_edit
    @preference_theme = @preference_colortheme
  end

  def update_theme_preference_screen
    set_colortheme_preferences_update
    @preference_theme = @preference_colortheme
    return render_preference_update_response if request.format.json?

    redirect_to(
      safe_pt_path || preference_edit_url(:theme, preference_write_redirect_params(except: :ct)),
      notice: preference_update_notice,
    )
  end

  def edit_cookie_preference_screen
    set_cookie_preferences_edit
  end

  def update_cookie_preference_screen
    set_cookie_preferences_update
    return render_preference_update_response if request.format.json?

    redirect_to(
      preference_edit_url(:cookie, preference_context_redirect_params),
      notice: preference_update_notice,
    )
  end

  def edit_reset_preference_screen
    @preference = @preferences
  end

  def destroy_reset_preference_screen
    @preference = @preferences
    @preference.require_reset_confirmation(params[:confirm_reset])

    unless @preference.valid?(:reset)
      render :edit, status: :unprocessable_content
      return
    end

    reset_preference_to_defaults!
    redirect_to(preference_index_path, notice: preference_reset_destroyed_notice, status: :see_other)
  end

  def edit_selectable_preference_screen(screen)
    set_selectable_preference_edit(screen)
    set_selectable_preference_view_context(screen)
    render "sign/shared/preference/selectable"
  end

  def update_selectable_preference_screen(screen)
    set_selectable_preference_update(screen)
    return render_preference_update_response if request.format.json?

    redirect_to(
      preference_edit_url(screen, preference_write_redirect_params(except: preference_context_key_for_screen(screen))),
      notice: preference_update_notice,
    )
  rescue PreferenceOperationError
    redirect_to(
      preference_edit_url(screen, preference_write_redirect_params(except: preference_context_key_for_screen(screen))),
      alert: preference_operation_failed_alert,
    )
  end

  def preference_index_path
    return sign_app_preference_path if respond_to?(:sign_app_preference_path, true)
    return sign_com_preference_path if respond_to?(:sign_com_preference_path, true)
    return sign_org_preference_path if respond_to?(:sign_org_preference_path, true)

    raise NotImplementedError, "preference index path is not configured for this surface"
  end
end
