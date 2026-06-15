# typed: false
# frozen_string_literal: true

module Palm
  module App
    module Oauth
      module Callback
        class AndroidController < Palm::App::Oauth::CallbacksController
          def index
            render_callback_stub
          end
        end
      end
    end
  end
end
