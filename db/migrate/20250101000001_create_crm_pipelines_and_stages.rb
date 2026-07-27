class CreateCrmPipelinesAndStages < ActiveRecord::Migration[7.1]
  def change
    create_crm_pipelines
    create_crm_stages
  end

  private

  def create_crm_pipelines
    create_table :crm_pipelines do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :crm_pipelines, :account_id
    add_index :crm_pipelines, [:account_id, :name], unique: true
    add_foreign_key :crm_pipelines, :accounts
  end

  def create_crm_stages
    create_table :crm_stages do |t|
      t.bigint :account_id, null: false
      t.bigint :pipeline_id, null: false
      t.string :name, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :crm_stages, :account_id
    add_index :crm_stages, :pipeline_id
    add_index :crm_stages, [:pipeline_id, :position]
    add_foreign_key :crm_stages, :accounts
    add_foreign_key :crm_stages, :crm_pipelines, column: :pipeline_id
  end
end
