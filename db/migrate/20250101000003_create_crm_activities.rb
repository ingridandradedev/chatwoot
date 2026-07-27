class CreateCrmActivities < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_activities do |t|
      t.bigint :account_id, null: false
      t.bigint :contact_id, null: false
      t.bigint :user_id, null: false
      t.integer :activity_type, null: false
      t.text :description, null: false
      t.jsonb :metadata, null: false, default: '{}'

      t.datetime :created_at, null: false
    end

    add_index :crm_activities, :account_id
    add_index :crm_activities, [:contact_id, :created_at], order: { created_at: :desc }
    add_foreign_key :crm_activities, :accounts
    add_foreign_key :crm_activities, :contacts
    add_foreign_key :crm_activities, :users
  end
end
