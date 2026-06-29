# typed: false
# frozen_string_literal: true

module PreferenceSignScreenActions
  extend ActiveSupport::Concern
  include PreferenceCore

  protected

  def edit_region_preference_screen
    set_region_preferences_edit
  end

  def update_region_preference_screen
    ensure_preference_access_token_audience_for_write!
    set_region_preferences_update
    redirect_to(
      preference_edit_url(:region, preference_write_redirect_params),
      notice: preference_update_notice,
    )
  end

  def edit_language_preference_screen
    set_language_preferences_edit
  end

  def update_language_preference_screen
    ensure_preference_access_token_audience_for_write!
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
    ensure_preference_access_token_audience_for_write!
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
    set_theme_preferences_edit
  end

  def update_theme_preference_screen
    ensure_preference_access_token_audience_for_write!
    set_theme_preferences_update
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
    ensure_preference_access_token_audience_for_write!
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
    ensure_preference_access_token_audience_for_write!
    @preference = @preferences
    @preference.require_reset_confirmation(params[:confirm_reset])

    unless @preference.valid?(:reset)
      # Render the same shared reset template the edit action uses. Acme routes
      # every preference screen through shared templates and has no per-surface
      # resets/edit view, so `render :edit` would raise MissingTemplate.
      render "acme/shared/preference/resets", status: :unprocessable_content
      return
    end

    reset_preference_by_rebootstrap!
    redirect_to(preference_index_path_without_context, notice: preference_reset_destroyed_notice, status: :see_other)
  end

  def edit_selectable_preference_screen(screen)
    set_selectable_preference_edit(screen)
    set_selectable_preference_view_context(screen)
    render "auth/shared/preference/selectable"
  end

  def update_selectable_preference_screen(screen)
    ensure_preference_access_token_audience_for_write!
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
    preference_index_url
  end

  def preference_index_path_without_context
    preference_index_url(PreferenceGlobal::PARAM_CONTEXT_KEYS.index_with { nil })
  end
end
