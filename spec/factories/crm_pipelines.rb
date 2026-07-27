# frozen_string_literal: true

FactoryBot.define do
  factory :crm_pipeline, class: 'Crm::Pipeline' do
    sequence(:name) { |n| "Pipeline #{n}" }
    account
  end
end
