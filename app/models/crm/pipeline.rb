module Crm
  class Pipeline < ApplicationRecord
    self.table_name = 'crm_pipelines'

    belongs_to :account
    has_many :stages, class_name: 'Crm::Stage', dependent: :restrict_with_error
    has_many :deals, through: :stages

    validates :name, presence: true, length: { maximum: 255 },
                     uniqueness: { scope: :account_id }
    validates :account_id, presence: true

    after_create :create_default_stages

    private

    def create_default_stages
      %w[Novo Qualificando Proposta].each_with_index do |name, i|
        stages.create!(name: name, position: i + 1, account: account)
      end
      stages.create!(name: 'Fechado Ganho', position: 4, account: account)
      stages.create!(name: 'Fechado Perdido', position: 5, account: account)
    end
  end
end
