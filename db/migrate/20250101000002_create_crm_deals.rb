class CreateCrmDeals < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_deals do |t|
      t.bigint :account_id, null: false
      t.bigint :contact_id, null: false
      t.bigint :stage_id, null: false
      t.string :title, limit: 255
      t.decimal :value, precision: 15, scale: 2
      t.bigint :created_by_id, null: false

      t.timestamps
    end

    add_index :crm_deals, :account_id
    add_index :crm_deals, :contact_id
    add_index :crm_deals, :stage_id
    add_index :crm_deals, [:contact_id, :stage_id], unique: true

    add_foreign_key :crm_deals, :accounts
    add_foreign_key :crm_deals, :contacts
    add_foreign_key :crm_deals, :crm_stages, column: :stage_id
    add_foreign_key :crm_deals, :users, column: :created_by_id
  end
end
