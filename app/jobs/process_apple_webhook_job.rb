class ProcessAppleWebhookJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(event_id)
    event = SubscriptionEvent.find(event_id)

    Subscriptions::ProcessEventService.process(event)

    Rails.logger.info("successfully processed event #{event.id}")
  end

  discard_on StandardError do |job, error|
    Rails.logger.error("permanently failed to process subscription event #{job.arguments.first}: #{error.message}")
  end
end
