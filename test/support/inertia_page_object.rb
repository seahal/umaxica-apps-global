# typed: false
# frozen_string_literal: true

# Reads the Inertia page object out of an HTML response.
#
# `use_script_element_for_initial_page` is on, so the initial render embeds the page object as JSON
# in a `<script data-page="app" type="application/json">` element rather than as a `data-page`
# attribute. Assertions about what a page shows read that object, because an Inertia page carries
# its content in props and renders the markup on the client.
module InertiaPageObject
  # The whole page object: component, props, url, version, encryptHistory.
  def inertia_page
    element = css_select("script[data-page='app']").first

    assert element, "expected an Inertia page object in the response"

    JSON.parse(element.text)
  end

  def inertia_props
    inertia_page.fetch("props")
  end

  def inertia_component
    inertia_page.fetch("component")
  end

  # The select choices a preference screen offers, as [label, value] pairs.
  def inertia_choice_pairs
    inertia_props.fetch("form").fetch("choices").map { |choice| [choice.fetch("label"), choice.fetch("value")] }
  end

  def inertia_choice_labels
    inertia_choice_pairs.map(&:first)
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) { include InertiaPageObject }
