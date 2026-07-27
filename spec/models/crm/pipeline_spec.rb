# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::Pipeline do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:stages).class_name('Crm::Stage').dependent(:restrict_with_error) }
    it { is_expected.to have_many(:deals).through(:stages) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_presence_of(:account_id) }

    describe 'uniqueness of name scoped to account' do
      let(:account) { create(:account) }

      it 'does not allow duplicate pipeline names within the same account' do
        create(:crm_pipeline, name: 'Sales Pipeline', account: account)
        duplicate = build(:crm_pipeline, name: 'Sales Pipeline', account: account)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:name]).to include('has already been taken')
      end

      it 'allows the same pipeline name in different accounts' do
        other_account = create(:account)
        create(:crm_pipeline, name: 'Sales Pipeline', account: account)
        pipeline = build(:crm_pipeline, name: 'Sales Pipeline', account: other_account)
        expect(pipeline).to be_valid
      end
    end
  end

  describe 'callbacks' do
    describe '#create_default_stages' do
      let(:account) { create(:account) }

      it 'creates 5 default stages after pipeline creation' do
        pipeline = create(:crm_pipeline, account: account)
        expect(pipeline.stages.count).to eq(5)
      end

      it 'creates stages with correct names in order' do
        pipeline = create(:crm_pipeline, account: account)
        stage_names = pipeline.stages.order(:position).pluck(:name)
        expect(stage_names).to eq(['Novo', 'Qualificando', 'Proposta', 'Fechado Ganho', 'Fechado Perdido'])
      end

      it 'assigns sequential positions starting at 1' do
        pipeline = create(:crm_pipeline, account: account)
        positions = pipeline.stages.order(:position).pluck(:position)
        expect(positions).to eq([1, 2, 3, 4, 5])
      end

      it 'assigns the correct account to each stage' do
        pipeline = create(:crm_pipeline, account: account)
        pipeline.stages.each do |stage|
          expect(stage.account).to eq(account)
        end
      end
    end
  end
end
