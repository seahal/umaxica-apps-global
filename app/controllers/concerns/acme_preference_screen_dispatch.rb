# typed: false
# frozen_string_literal: true

module AcmePreferenceScreenDispatch
  extend ActiveSupport::Concern
  include ::PreferenceSignScreenActions

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

  def preference_key
    configured = self.class.const_get(:PREFERENCE_KEY, false) if self.class.const_defined?(:PREFERENCE_KEY, false)
    configured.presence || preference_key_from_controller || params[:preference_screen].to_s.presence
  end

  def preference_key_from_controller
    {
      "regions" => "region",
      "timezones" => "timezone",
      "languages" => "language",
      "currencies" => "currency",
      "dates" => "date",
      "times" => "time",
      "motions" => "motion",
      "densities" => "density",
      "page_sizes" => "page_size",
      "themes" => "theme",
      "cookies" => "cookie",
    }[controller_name.to_s]
  end

  def edit_selectable_preference_screen(screen)
    set_selectable_preference_edit(screen)
    set_selectable_preference_view_context(screen)
    render "acme/shared/preference/selectable"
  end

  def dispatch_preference_screen(action)
    screen = preference_key.to_s
    config = SCREEN_ACTIONS.fetch(screen)
    @preference_screen = screen

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
    case preference_key.to_s
    when "region", "timezone", "language", "theme"
      "option"
    when "cookie"
      "cookie"
    else
      preference_key.to_s.pluralize
    end
  end
end
