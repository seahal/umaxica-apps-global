# typed: false
# frozen_string_literal: true

module Palm
  module App
    module Oauth
      module Callback
        class IosController < Palm::App::Oauth::CallbacksController
          AUTHENTICATION_MODE = :bare

          def index
            render_callback_stub
          end
        end
      end
    end
  end
end
