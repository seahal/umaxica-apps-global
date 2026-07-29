# frozen_string_literal: true

require Rails.root.join("app/subscribers/csrf_notification_subscriber").to_s

subscriber = CsrfNotificationSubscriber.new
CsrfNotificationSubscriber::EVENT_CONFIG.each_key do |event_name|
  ActiveSupport::Notifications.subscribe(event_name) do |event|
    subscriber.emit(event)
  end
end
