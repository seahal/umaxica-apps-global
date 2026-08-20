# typed: false
# frozen_string_literal: true

module Help
  module App
    class RootsController < Help::App::BareController
      AUTHENTICATION_MODE = :bare

      # Declared here rather than on BareController: that base is also the parent of the
      # /api/v0/entries, health probe, revision, and CSP report endpoints, where a browser-version
      # gate would answer a machine client with public/406-unsupported-browser.html.
      allow_browser versions: :modern
      layout false

      def index
      end
    end
  end
end
