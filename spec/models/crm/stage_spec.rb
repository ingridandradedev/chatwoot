# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::Stage do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:pipeline).class_name('Crm::Pipeline') }
    it { is_expected.to have_many(:deals).class_name('Crm::Deal').dependent(:restrict_with_error) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_numericality_of(:position).only_integer }
    it { is_expected.to validate_presence_of(:account_id) }
  end

  describe 'scopes' do
    describe '.ordered' do
      let(:account) { create(:account) }
      let(:pipeline) { create(:crm_pipeline, account: account) }

      it 'returns stages ordered by position ascending' do
        # Pipeline creates 5 default stages (positions 1-5)
        stages = pipeline.stages.ordered
        positions = stages.pluck(:position)
        expect(positions).to eq(positions.sort)
      end

      it 'correctly orders manually created stages' do
        # Create a new pipeline to get fresh stages
        new_pipeline = create(:crm_pipeline, account: account, name: 'Test Pipeline')
        # Destroy default stages and create custom ones
        new_pipeline.stages.destroy_all
        stage_c = new_pipeline.stages.create!(name: 'C', position: 3, account: account)
        stage_a = new_pipeline.stages.create!(name: 'A', position: 1, account: account)
        stage_b = new_pipeline.stages.create!(name: 'B', position: 2, account: account)

        ordered_stages = new_pipeline.stages.ordered
        expect(ordered_stages).to eq([stage_a, stage_b, stage_c])
      end
    end
  end

  describe 'dependent restrictions' do
    let(:account) { create(:account) }
    let(:pipeline) { create(:crm_pipeline, account: account) }
    let(:stage) { pipeline.stages.first }

    it 'prevents deletion when deals exist' do
      create(:crm_deal, account: account, stage: stage)
      expect(stage.destroy).to be false
      expect(stage.errors[:base]).to be_present
    end
  end
end
