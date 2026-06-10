# typed: false
# frozen_string_literal: true

# Dedicated OTP redelivery (resend) endpoint for in-settings email registration.
# The `resend` action was split out of Sign::App::Settings::Emails::RegistrationsController
# into this RESTful redelivery resource: POST /settings/emails/registration/redelivery.
#
# Inherits RegistrationsController to reuse its concern set and the surface-specific
# registration path/helpers (e.g. #new_email_registration_path) the resend flow depends on.
# The route exposes a single #create action that runs the inherited resend flow.
module Sign
  module App
    module Settings
      module Emails
        class RedeliveriesController < RegistrationsController
          AUTHENTICATION_MODE = :private

          def create = resend
        end
      end
    end
  end
end
