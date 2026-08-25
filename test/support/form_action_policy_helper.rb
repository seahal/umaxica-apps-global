# frozen_string_literal: true

# Guards the invariant that keeps breaking the social ceremony: a form the
# browser submits must aim at an origin the page's own Content-Security-Policy
# allows under form-action.
#
# When the two drift apart the browser blocks the submission silently. Nothing
# fails server-side, the ceremony stalls on the page that rendered the form, and
# the next attempt fails with a consumed checkpoint ("ticket is required"), which
# points at the wrong place entirely. Two ways to drift:
#
#   - the form target moves to an internal host (a PRIVATE_* origin) that is
#     correctly absent from the allowlist
#   - the allowlist drops an origin a form still targets
#
# Both are caught here, against the response actually rendered.
module FormActionPolicyHelper
  DEFAULT_PORTS = { "http" => 80, "https" => 443 }.freeze

  # Asserts every form in the current response can be submitted under the
  # response's own CSP. Relative actions are same-origin and always allowed.
  def assert_forms_submittable_under_policy(message = nil)
    policy = form_action_sources(response.headers["Content-Security-Policy"])

    assert_predicate policy, :present?, "response carries no form-action policy to check against"

    form_action_origins.each do |action, origin|
      assert_includes(
        policy,
        origin,
        [
          message,
          "form action #{action.inspect} targets #{origin}, which form-action does not allow, " \
          "so the browser blocks the submission and the ceremony stalls on this page",
        ].compact.join(" "),
      )
    end
  end

  # Absolute form actions in the current response, as [action, origin] pairs.
  def form_action_origins
    return [] unless response.media_type == "text/html"

    response.parsed_body.css("form[action]").filter_map do |form|
      action = form["action"].to_s
      next unless action.start_with?("http://", "https://")

      [action, policy_origin(URI.parse(action))]
    rescue URI::InvalidURIError
      nil
    end
  end

  private

  def form_action_sources(header)
    directive =
      header.to_s.split(";").map(&:strip).find { |part| part.start_with?("form-action ") }

    directive.to_s.split(/\s+/).drop(1)
  end

  # CSP source expressions omit the default port, so origins need the same
  # normalization before they can be compared.
  def policy_origin(uri)
    port = (uri.port.nil? || uri.port == DEFAULT_PORTS[uri.scheme]) ? "" : ":#{uri.port}"

    "#{uri.scheme}://#{uri.host}#{port}"
  end
end
