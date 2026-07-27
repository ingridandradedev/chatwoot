# app/jobs/crm/backfill_deals_job.rb
module Crm
  class BackfillDealsJob < ApplicationJob
    queue_as :default

    def perform(pipeline_id)
      pipeline = Crm::Pipeline.find(pipeline_id)
      return unless pipeline.auto_create_deals

      first_stage = pipeline.first_stage
      return unless first_stage

      account = pipeline.account
      default_user_id = account.users.first&.id || 1

      # Find contacts that don't already have a deal in this pipeline
      existing_contact_ids = pipeline.deals.pluck(:contact_id)

      account.contacts.where.not(id: existing_contact_ids).find_each do |contact|
        Crm::Deal.create!(
          account: account,
          contact: contact,
          stage: first_stage,
          created_by_id: default_user_id
        )
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("CRM BackfillDealsJob failed for contact##{contact.id}: #{e.message}")
      end
    end
  end
end
