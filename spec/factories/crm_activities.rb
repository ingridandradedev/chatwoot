# frozen_string_literal: true

FactoryBot.define do
  factory :crm_activity, class: 'Crm::Activity' do
    account
    activity_type { :note }
    description { 'Activity description' }

    after(:build) do |activity|
      activity.contact ||= create(:contact, account: activity.account)
      activity.user ||= create(:user)
    end
  end
end
