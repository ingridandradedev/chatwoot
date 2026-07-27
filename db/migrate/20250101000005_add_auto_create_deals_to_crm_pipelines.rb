class AddAutoCreateDealsToCrmPipelines < ActiveRecord::Migration[7.1]
  def change
    add_column :crm_pipelines, :auto_create_deals, :boolean, null: false, default: false
  end
end
