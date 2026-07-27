# frozen_string_literal: true

FactoryBot.define do
  factory :crm_stage, class: 'Crm::Stage' do
    sequence(:name) { |n| "Stage #{n}" }
    sequence(:position) { |n| n }
    account

    after(:build) do |stage|
      stage.pipeline ||= create(:crm_pipeline, account: stage.account)
    end
  end
end
