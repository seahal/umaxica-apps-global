# typed: false
# frozen_string_literal: true

module Preference::SignScreenActions
  extend ActiveSupport::Concern
  include Preference::Core

  class_methods do
    def preference_screen(screen)
      case screen
      when :region then define_region_preference_screen
      when :language then define_language_preference_screen
      when :timezone then define_timezone_preference_screen
      when :theme then define_theme_preference_screen
      when :cookie then define_cookie_preference_screen
      when :reset then define_reset_preference_screen
      when :currency, :date_format, :time_format, :motion, :density, :items_per_page
        define_selectable_preference_screen(screen)
      else
        raise ArgumentError, "Unknown preference screen: #{screen.inspect}"
      end
    end

    private

    def define_region_preference_screen
      define_method(:edit) do
        set_region_preferences_edit
      end

      define_method(:update) do
        set_region_preferences_update
        redirect_to(
          preference_edit_url(:region, updated_region_redirect_params),
          notice: preference_update_notice,
        )
      end
    end

    def define_language_preference_screen
      define_method(:edit) do
        set_language_preferences_edit
      end

      define_method(:update) do
        set_language_preferences_update
        apply_language_preference_to_session
        redirect_to(
          preference_edit_url(:language, language_preference_redirect_params),
          notice: preference_update_notice,
        )
      end
    end

    def define_timezone_preference_screen
      define_method(:edit) do
        set_timezone_preferences_edit
      end

      define_method(:update) do
        set_timezone_preferences_update
        redirect_to(
          preference_edit_url(:timezone),
          notice: preference_update_notice,
        )
      rescue PreferenceOperationError
        redirect_to(
          preference_edit_url(:timezone),
          alert: preference_operation_failed_alert,
        )
      end
    end

    def define_theme_preference_screen
      define_method(:edit) do
        set_colortheme_preferences_edit
        @preference_theme = @preference_colortheme
      end

      define_method(:update) do
        set_colortheme_preferences_update
        @preference_theme = @preference_colortheme
        return render_preference_update_response if request.format.json?

        redirect_to(
          safe_return_to_path || preference_edit_url(:theme),
          notice: preference_update_notice,
        )
      end
    end

    def define_cookie_preference_screen
      define_method(:edit) do
        set_cookie_preferences_edit
      end

      define_method(:update) do
        set_cookie_preferences_update
        return render_preference_update_response if request.format.json?

        redirect_to(
          preference_edit_url(:cookie, preference_context_redirect_params),
          notice: preference_update_notice,
        )
      end
    end

    def define_reset_preference_screen
      define_method(:edit) do
        @preference = @preferences
      end

      define_method(:destroy) do
        @preference = @preferences
        @preference.require_reset_confirmation(params[:confirm_reset])

        unless @preference.valid?(:reset)
          render :edit, status: :unprocessable_content
          return
        end

        reset_preference_to_defaults!
        redirect_to(
          preference_edit_url(:reset, preference_context_redirect_params.slice(:ri)),
          notice: preference_reset_destroyed_notice,
        )
      end
    end

    def define_selectable_preference_screen(screen)
      define_method(:edit) do
        set_selectable_preference_edit(screen)
        set_selectable_preference_view_context(screen)
        render "sign/shared/preference/selectable"
      end

      define_method(:update) do
        set_selectable_preference_update(screen)
        return render_preference_update_response if request.format.json?

        redirect_to(
          preference_edit_url(screen),
          notice: preference_update_notice,
        )
      rescue PreferenceOperationError
        redirect_to(
          preference_edit_url(screen),
          alert: preference_operation_failed_alert,
        )
      end
    end
  end
end
