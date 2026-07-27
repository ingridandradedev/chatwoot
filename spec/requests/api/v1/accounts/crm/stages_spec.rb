require 'rails_helper'

RSpec.describe 'CRM Stages API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:crm_pipeline, account: account) }

  describe 'GET /api/v1/accounts/:account_id/crm/pipelines/:pipeline_id/stages' do
    before { create(:crm_stage, pipeline: pipeline, account: account, name: 'Prospecting', position: 1) }

    context 'when authenticated as agent' do
      it 'returns stages ordered by position' do
        get "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages",
            headers: agent.create_new_auth_token

        expect(response).to have_http_status(:success)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/crm/pipelines/:pipeline_id/stages' do
    let(:valid_params) { { stage: { name: 'Negotiation', position: 3 } } }

    context 'when authenticated as admin' do
      it 'creates a stage' do
        expect do
          post "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages",
               params: valid_params,
               headers: admin.create_new_auth_token,
               as: :json
        end.to change(Crm::Stage, :count).by(1)

        expect(response).to have_http_status(:success)
      end
    end

    context 'when authenticated as agent' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages",
             params: valid_params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages",
             params: valid_params,
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when params are invalid' do
      it 'returns unprocessable_entity for blank name' do
        post "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages",
             params: { stage: { name: '', position: 1 } },
             headers: admin.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/crm/pipelines/:pipeline_id/stages/:id' do
    let(:stage) { create(:crm_stage, pipeline: pipeline, account: account, name: 'Old Stage') }

    context 'when authenticated as admin' do
      it 'updates the stage' do
        patch "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages/#{stage.id}",
              params: { stage: { name: 'Renamed Stage' } },
              headers: admin.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:success)
        expect(stage.reload.name).to eq('Renamed Stage')
      end
    end

    context 'when authenticated as agent' do
      it 'returns unauthorized' do
        patch "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages/#{stage.id}",
              params: { stage: { name: 'Renamed Stage' } },
              headers: agent.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        patch "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages/#{stage.id}",
              params: { stage: { name: 'Renamed Stage' } },
              as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/crm/pipelines/:pipeline_id/stages/:id' do
    let!(:stage) { create(:crm_stage, pipeline: pipeline, account: account) }

    context 'when authenticated as admin' do
      it 'destroys the stage when no deals exist' do
        expect do
          delete "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages/#{stage.id}",
                 headers: admin.create_new_auth_token
        end.to change(Crm::Stage, :count).by(-1)

        expect(response).to have_http_status(:success)
      end

      it 'returns unprocessable_entity when stage has deals' do
        create(:crm_deal, account: account, stage: stage)

        delete "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages/#{stage.id}",
               headers: admin.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Reassign deals before deleting')
      end
    end

    context 'when authenticated as agent' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages/#{stage.id}",
               headers: agent.create_new_auth_token

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages/#{stage.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/crm/pipelines/:pipeline_id/stages/reorder' do
    let!(:stage_a) { create(:crm_stage, pipeline: pipeline, account: account, position: 1) }
    let!(:stage_b) { create(:crm_stage, pipeline: pipeline, account: account, position: 2) }

    context 'when authenticated as admin' do
      it 'reorders stages' do
        post "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages/reorder",
             params: { positions: [{ id: stage_a.id, position: 2 }, { id: stage_b.id, position: 1 }] },
             headers: admin.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(stage_a.reload.position).to eq(2)
        expect(stage_b.reload.position).to eq(1)
      end
    end

    context 'when authenticated as agent' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages/reorder",
             params: { positions: [{ id: stage_a.id, position: 2 }, { id: stage_b.id, position: 1 }] },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages/reorder",
             params: { positions: [{ id: stage_a.id, position: 2 }] },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
