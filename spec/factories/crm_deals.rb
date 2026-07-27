# frozen_string_literal: true

FactoryBot.define do
  factory :crm_deal, class: 'Crm::Deal' do
    account
    title { 'Sample Deal' }
    value { 1000.00 }

    after(:build) do |deal|
      deal.contact ||= create(:contact, account: deal.account)
      deal.stage ||= create(:crm_stage, account: deal.account)
      deal.created_by ||= create(:user)
    end
  end
end
