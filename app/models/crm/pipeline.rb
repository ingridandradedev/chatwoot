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
    after_update :trigger_backfill_deals, if: :auto_create_deals_turned_on?

    # Returns the first stage (lowest position) — used for auto-creating deals
    def first_stage
      stages.ordered.first
    end

    private

    def auto_create_deals_turned_on?
      saved_change_to_auto_create_deals? && auto_create_deals?
    end

    def trigger_backfill_deals
      Crm::BackfillDealsJob.perform_later(id)
    end

    def create_default_stages
      %w[Novo Qualificando Proposta].each_with_index do |name, i|
        stages.create!(name: name, position: i + 1, account: account)
      end
      stages.create!(name: 'Fechado Ganho', position: 4, account: account)
      stages.create!(name: 'Fechado Perdido', position: 5, account: account)
    end
  end
end
