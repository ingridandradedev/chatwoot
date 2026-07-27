module Crm
  class Deal < ApplicationRecord
    self.table_name = 'crm_deals'

    belongs_to :account
    belongs_to :contact
    belongs_to :stage, class_name: 'Crm::Stage'
    belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id'

    validates :account_id, presence: true
    validates :contact_id, presence: true
    validates :stage_id, presence: true
    validates :title, length: { maximum: 255 }, allow_blank: true
    validates :value, numericality: { greater_than_or_equal_to: 0, less_than: 1_000_000_000 }, allow_nil: true
    validate :one_deal_per_contact_per_pipeline

    private

    def one_deal_per_contact_per_pipeline
      return unless contact_id && stage_id

      pipeline_id = stage&.pipeline_id
      existing = self.class.joins(:stage)
                     .where(contact_id: contact_id, crm_stages: { pipeline_id: pipeline_id })
                     .where.not(id: id)
      errors.add(:contact_id, 'already has a deal in this pipeline') if existing.exists?
    end
  end
end
