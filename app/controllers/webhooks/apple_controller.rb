module Webhooks
  class AppleController < ApplicationController
    EVENTS = {
      'PURCHASE': :confirmed,
      'RENEW': :renewed,
      'CANCEL': :cancelled
    }

    # POST /webhooks/apple
    def create
      # completely skip jwt handling 🙃
      payload = request.body.read
      subscription = Subscription.find_by!(transaction_id: params[:transaction_id])

      if subscription.product_id != params[:product_id]
        Rails.logger.warn("product_id mismatch for #{params[:transaction_id]}. expected #{subscription.product_id}, got #{params[:product_id]}")
        return head :unprocessable_entity
      end

      event_type = EVENTS.fetch(params[:type].to_sym)
      purchase_date = DateTime.parse(params[:purchase_date])

      # check if event already exists - ideally we'd have an id 🤔
      existing_event = subscription.subscription_events.find_by(
        event_type: event_type,
        transaction_id: params[:transaction_id],
        purchase_date: purchase_date
      )
      return head :ok if existing_event

      money = Monetize.parse(params[:amount], params[:currency])
      event = subscription.subscription_events.create!(
        event_type: event_type,
        transaction_id: params[:transaction_id],
        product_id: params[:product_id],
        amount_cents: money.cents,
        amount_currency: money.currency.to_s,
        purchase_date: purchase_date,
        expires_date: DateTime.parse((params[:expires_date])),
        raw_payload: payload
      )

      ProcessAppleWebhookJob.perform_later(event.id)

      head :ok
    rescue ActiveRecord::RecordNotFound
      head :unprocessable_entity
    end
  end
end
