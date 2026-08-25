# frozen_string_literal: true

# Applies the outbound email kill switch to every mailer, including ones added later.
ActiveSupport.on_load(:action_mailer) do
  register_interceptor("OutboundEmailSuspensionInterceptor")
end
