module Crm
  class Activity < ApplicationRecord
    self.table_name = 'crm_activities'

    belongs_to :account
    belongs_to :contact
    belongs_to :user

    enum activity_type: { call: 0, email: 1, meeting: 2, note: 3, stage_change: 4, task_completed: 5 }

    MANUAL_TYPES = %w[call email meeting note].freeze
    SYSTEM_TYPES = %w[stage_change task_completed].freeze

    validates :account_id, presence: true
    validates :contact_id, presence: true
    validates :user_id, presence: true
    validates :activity_type, presence: true
    validates :description, presence: true, length: { maximum: 10_000 }

    # Immutable: no updates allowed
    def readonly?
      persisted?
    end

    scope :recent_first, -> { order(created_at: :desc) }
  end
end
