class AddCardFieldsToCrmPipelines < ActiveRecord::Migration[7.1]
  def change
    add_column :crm_pipelines, :card_fields, :jsonb, null: false, default: ['name', 'email', 'phone_number']
  end
end
