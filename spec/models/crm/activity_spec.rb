# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::Activity do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:contact) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:account_id) }
    it { is_expected.to validate_presence_of(:contact_id) }
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:activity_type) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_length_of(:description).is_at_most(10_000) }
  end

  describe 'enums' do
    it {
      is_expected.to define_enum_for(:activity_type)
        .with_values(call: 0, email: 1, meeting: 2, note: 3, stage_change: 4, task_completed: 5)
    }
  end

  describe '#readonly?' do
    it 'returns false for a new record' do
      activity = build(:crm_activity)
      expect(activity.readonly?).to be false
    end

    it 'returns true for a persisted record' do
      activity = create(:crm_activity)
      expect(activity.readonly?).to be true
    end

    it 'prevents updates on a persisted record' do
      activity = create(:crm_activity)
      expect { activity.update!(description: 'Updated') }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  describe 'scopes' do
    describe '.recent_first' do
      let(:account) { create(:account) }
      let(:contact) { create(:contact, account: account) }
      let(:user) { create(:user) }

      it 'orders activities by created_at descending' do
        old_activity = create(:crm_activity, account: account, contact: contact, user: user,
                                             created_at: 2.days.ago)
        new_activity = create(:crm_activity, account: account, contact: contact, user: user,
                                             created_at: 1.hour.ago)

        activities = Crm::Activity.recent_first
        expect(activities.first).to eq(new_activity)
        expect(activities.last).to eq(old_activity)
      end
    end
  end

  describe 'constants' do
    it 'defines MANUAL_TYPES' do
      expect(Crm::Activity::MANUAL_TYPES).to eq(%w[call email meeting note])
    end

    it 'defines SYSTEM_TYPES' do
      expect(Crm::Activity::SYSTEM_TYPES).to eq(%w[stage_change task_completed])
    end
  end
end
