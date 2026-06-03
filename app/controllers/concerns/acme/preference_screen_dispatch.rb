# typed: false
# frozen_string_literal: true

module Acme
  module PreferenceScreenDispatch
    extend ActiveSupport::Concern
    include ::Preference::SignScreenActions

    SCREEN_ACTIONS = {
      "region" => %i(edit_region_preference_screen update_region_preference_screen),
      "timezone" => %i(edit_timezone_preference_screen update_timezone_preference_screen),
      "language" => %i(edit_language_preference_screen update_language_preference_screen),
      "currency" => [:currency, :selectable],
      "date" => [:date_format, :selectable],
      "time" => [:time_format, :selectable],
      "motion" => [:motion, :selectable],
      "density" => [:density, :selectable],
      "page_size" => [:page_size, :selectable],
      "adult_content_gate" => [:adult_content_gate, :selectable],
      "theme" => %i(edit_theme_preference_screen update_theme_preference_screen),
      "cookie" => %i(edit_cookie_preference_screen update_cookie_preference_screen),
    }.freeze

    def edit
      dispatch_preference_screen(:edit)
      render(preference_screen_template) unless performed?
    end

    def update
      dispatch_preference_screen(:update)
    end

    private

    def edit_selectable_preference_screen(screen)
      set_selectable_preference_edit(screen)
      set_selectable_preference_view_context(screen)
      render "acme/shared/preference/selectable"
    end

    def dispatch_preference_screen(action)
      screen = params[:preference_screen].to_s
      config = SCREEN_ACTIONS.fetch(screen)

      if config.last == :selectable
        if action == :edit
          edit_selectable_preference_screen(config.first)
        else
          update_selectable_preference_screen(config.first)
        end
      else
        send((action == :edit) ? config.first : config.second)
      end
    end

    def preference_screen_template
      "acme/shared/preference/#{preference_screen_template_name}"
    end

    def preference_screen_template_name
      case params[:preference_screen].to_s
      when "region", "timezone", "language", "theme"
        "option"
      when "cookie"
        "cookie"
      else
        params[:preference_screen].to_s.pluralize
      end
    end
  end
end
