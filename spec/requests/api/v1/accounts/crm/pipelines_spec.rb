require 'rails_helper'

RSpec.describe 'CRM Pipelines API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v1/accounts/:account_id/crm/pipelines' do
    before { create(:crm_pipeline, account: account, name: 'Sales Pipeline') }

    context 'when authenticated as admin' do
      it 'returns all pipelines for the account' do
        get "/api/v1/accounts/#{account.id}/crm/pipelines",
            headers: admin.create_new_auth_token

        expect(response).to have_http_status(:success)
      end
    end

    context 'when authenticated as agent' do
      it 'returns pipelines (agents have read access)' do
        get "/api/v1/accounts/#{account.id}/crm/pipelines",
            headers: agent.create_new_auth_token

        expect(response).to have_http_status(:success)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/crm/pipelines"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/accounts/:account_id/crm/pipelines/:id' do
    let(:pipeline) { create(:crm_pipeline, account: account) }

    context 'when authenticated as agent' do
      it 'returns the pipeline' do
        get "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}",
            headers: agent.create_new_auth_token

        expect(response).to have_http_status(:success)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/crm/pipelines' do
    let(:valid_params) { { pipeline: { name: 'New Pipeline' } } }

    context 'when authenticated as admin' do
      it 'creates a pipeline' do
        expect do
          post "/api/v1/accounts/#{account.id}/crm/pipelines",
               params: valid_params,
               headers: admin.create_new_auth_token,
               as: :json
        end.to change(Crm::Pipeline, :count).by(1)

        expect(response).to have_http_status(:success)
      end
    end

    context 'when authenticated as agent' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/crm/pipelines",
             params: valid_params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/crm/pipelines",
             params: valid_params,
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when params are invalid' do
      it 'returns unprocessable_entity for blank name' do
        post "/api/v1/accounts/#{account.id}/crm/pipelines",
             params: { pipeline: { name: '' } },
             headers: admin.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/crm/pipelines/:id' do
    let(:pipeline) { create(:crm_pipeline, account: account, name: 'Old Name') }

    context 'when authenticated as admin' do
      it 'updates the pipeline' do
        patch "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}",
              params: { pipeline: { name: 'Updated Name' } },
              headers: admin.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:success)
        expect(pipeline.reload.name).to eq('Updated Name')
      end
    end

    context 'when authenticated as agent' do
      it 'returns unauthorized' do
        patch "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}",
              params: { pipeline: { name: 'Updated Name' } },
              headers: agent.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        patch "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}",
              params: { pipeline: { name: 'Updated Name' } },
              as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/crm/pipelines/:id' do
    let!(:pipeline) { create(:crm_pipeline, account: account) }

    context 'when authenticated as admin' do
      it 'destroys the pipeline' do
        expect do
          delete "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}",
                 headers: admin.create_new_auth_token
        end.to change(Crm::Pipeline, :count).by(-1)

        expect(response).to have_http_status(:success)
      end
    end

    context 'when authenticated as agent' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}",
               headers: agent.create_new_auth_token

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
