# typed: false
# frozen_string_literal: true

module CsrfRouteCoverageHelper
  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route_verbs(route)
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class = controller_class_for(controller)
      next unless controller_class

      {
        verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: controller_class,
      }
    end
  end

  private

  def route_verbs(route)
    route.verb.to_s.delete("^A-Z|").split("|")
  end

  def controller_class_for(controller)
    controller_class_name = "#{controller.camelize}Controller"
    return nil unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

    Object.const_get(controller_class_name)
  rescue NameError
    nil
  end
end
