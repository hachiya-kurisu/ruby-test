class CreateSubscriptionEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_events do |t|
      t.references :subscription, null: false, foreign_key: { on_delete: :restrict }
      t.integer :event_type, null: false
      t.string :transaction_id, null: false
      t.string :product_id
      t.integer :amount_cents
      t.string :amount_currency, default: "JPY"
      t.datetime :purchase_date
      t.datetime :expires_date
      t.jsonb :raw_payload, null: false, default: {}
      t.datetime :processed_at
      t.datetime :failed_at

      t.timestamp :created_at, null: false
    end

    add_index :subscription_events, :event_type
    add_index :subscription_events, :processed_at
    add_index :subscription_events, :failed_at
    add_index :subscription_events, :created_at

    add_index :subscription_events,
      [ :transaction_id, :event_type, :purchase_date ],
      unique: true,
      name: 'index_subscription_events_on_idempotency_key'
  end
end
