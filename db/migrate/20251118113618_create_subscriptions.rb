class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :restrict }
      t.string :transaction_id, null: false
      t.string :product_id, null: false
      t.integer :status, null: false, default: 0
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.datetime :cancelled_at
      t.timestamps
    end

    # user can only have one active/provisional subscription at a time
    add_index :subscriptions, :user_id,
      unique: true,
      where: "status IN (0, 1)",
      name: "index_current_active_subscription"

    # transaction_id must be globally unique
    add_index :subscriptions, :transaction_id, unique: true
  end
end
