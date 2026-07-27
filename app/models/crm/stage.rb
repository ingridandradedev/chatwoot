module Crm
  class Stage < ApplicationRecord
    self.table_name = 'crm_stages'

    belongs_to :account
    belongs_to :pipeline, class_name: 'Crm::Pipeline'
    has_many :deals, class_name: 'Crm::Deal', dependent: :restrict_with_error

    validates :name, presence: true, length: { maximum: 255 }
    validates :position, presence: true, numericality: { only_integer: true }
    validates :account_id, presence: true

    scope :ordered, -> { order(position: :asc) }
  end
end
