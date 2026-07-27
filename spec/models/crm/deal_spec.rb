# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::Deal do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:contact) }
    it { is_expected.to belong_to(:stage).class_name('Crm::Stage') }
    it { is_expected.to belong_to(:created_by).class_name('User') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:account_id) }
    it { is_expected.to validate_presence_of(:contact_id) }
    it { is_expected.to validate_presence_of(:stage_id) }
    it { is_expected.to validate_length_of(:title).is_at_most(255) }

    describe 'value numericality' do
      let(:deal) { build(:crm_deal) }

      it 'allows nil value' do
        deal.value = nil
        expect(deal).to be_valid
      end

      it 'allows value of 0' do
        deal.value = 0
        expect(deal).to be_valid
      end

      it 'allows positive value' do
        deal.value = 500_000
        expect(deal).to be_valid
      end

      it 'rejects negative value' do
        deal.value = -1
        expect(deal).not_to be_valid
        expect(deal.errors[:value]).to be_present
      end

      it 'rejects value >= 1 billion' do
        deal.value = 1_000_000_000
        expect(deal).not_to be_valid
        expect(deal.errors[:value]).to be_present
      end
    end

    describe '#one_deal_per_contact_per_pipeline' do
      let(:account) { create(:account) }
      let(:pipeline) { create(:crm_pipeline, account: account) }
      let(:contact) { create(:contact, account: account) }
      let(:stage) { pipeline.stages.first }
      let(:other_stage) { pipeline.stages.second }

      it 'allows a contact to have one deal in a pipeline' do
        deal = build(:crm_deal, account: account, contact: contact, stage: stage)
        expect(deal).to be_valid
      end

      it 'rejects a second deal for the same contact in the same pipeline (same stage)' do
        create(:crm_deal, account: account, contact: contact, stage: stage)
        duplicate = build(:crm_deal, account: account, contact: contact, stage: stage)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:contact_id]).to include('already has a deal in this pipeline')
      end

      it 'rejects a second deal for the same contact in a different stage of the same pipeline' do
        create(:crm_deal, account: account, contact: contact, stage: stage)
        duplicate = build(:crm_deal, account: account, contact: contact, stage: other_stage)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:contact_id]).to include('already has a deal in this pipeline')
      end

      it 'allows the same contact to have deals in different pipelines' do
        other_pipeline = create(:crm_pipeline, account: account, name: 'Other Pipeline')
        other_pipeline_stage = other_pipeline.stages.first

        create(:crm_deal, account: account, contact: contact, stage: stage)
        deal_in_other_pipeline = build(:crm_deal, account: account, contact: contact, stage: other_pipeline_stage)
        expect(deal_in_other_pipeline).to be_valid
      end
    end
  end
end
