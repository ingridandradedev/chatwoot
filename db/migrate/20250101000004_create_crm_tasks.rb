class CreateCrmTasks < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_tasks do |t|
      t.references :account, null: false, index: true
      t.references :contact, null: false, index: true
      t.bigint :assignee_id, null: false
      t.bigint :created_by_id, null: false
      t.string :title, null: false, limit: 255
      t.text :description
      t.datetime :due_date, null: false
      t.datetime :reminder_at
      t.boolean :reminded, null: false, default: false
      t.integer :priority, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :completed_at
      t.bigint :completed_by_id

      t.timestamps
    end

    add_index :crm_tasks, :assignee_id
    add_index :crm_tasks, [:status, :due_date], name: 'index_crm_tasks_on_status_and_due_date'
    add_index :crm_tasks, [:reminded, :reminder_at, :status], name: 'index_crm_tasks_on_reminded_reminder_at_status'

    add_foreign_key :crm_tasks, :users, column: :assignee_id
    add_foreign_key :crm_tasks, :users, column: :created_by_id
    add_foreign_key :crm_tasks, :users, column: :completed_by_id
  end
end
