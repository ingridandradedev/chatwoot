require 'rails_helper'

RSpec.describe 'CRM Deals API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:crm_pipeline, account: account) }
  let(:stage) { create(:crm_stage, pipeline: pipeline, account: account) }
  let(:contact) { create(:contact, account: account) }

  describe 'GET /api/v1/accounts/:account_id/crm/pipelines/:pipeline_id/deals' do
    before { create(:crm_deal, account: account, stage: stage, contact: contact) }

    context 'when authenticated as agent' do
      it 'returns deals for the pipeline' do
        get "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/deals",
            headers: agent.create_new_auth_token

        expect(response).to have_http_status(:success)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/deals"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/accounts/:account_id/crm/pipelines/:pipeline_id/deals/:id' do
    let(:deal) { create(:crm_deal, account: account, stage: stage, contact: contact) }

    context 'when authenticated as agent' do
      it 'returns the deal' do
        get "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/deals/#{deal.id}",
            headers: agent.create_new_auth_token

        expect(response).to have_http_status(:success)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/deals/#{deal.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/crm/pipelines/:pipeline_id/deals' do
    let(:valid_params) { { deal: { contact_id: contact.id, stage_id: stage.id, title: 'New Deal', value: 5000 } } }

    context 'when authenticated as agent' do
      it 'creates a deal' do
        expect do
          post "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/deals",
               params: valid_params,
               headers: agent.create_new_auth_token,
               as: :json
        end.to change(Crm::Deal, :count).by(1)

        expect(response).to have_http_status(:success)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/deals",
             params: valid_params,
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when contact already has a deal in the same pipeline' do
      before { create(:crm_deal, account: account, stage: stage, contact: contact) }

      it 'returns unprocessable_entity' do
        post "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/deals",
             params: { deal: { contact_id: contact.id, stage_id: stage.id, title: 'Dup Deal', value: 100 } },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when params are invalid' do
      it 'returns unprocessable_entity for missing contact_id' do
        post "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/deals",
             params: { deal: { stage_id: stage.id, title: 'No Contact' } },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/crm/pipelines/:pipeline_id/deals/:id' do
    let(:deal) { create(:crm_deal, account: account, stage: stage, contact: contact) }

    context 'when authenticated as agent' do
      it 'updates the deal' do
        patch "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/deals/#{deal.id}",
              params: { deal: { title: 'Updated Deal' } },
              headers: agent.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:success)
        expect(deal.reload.title).to eq('Updated Deal')
      end

      it 'creates a stage_change activity when stage changes' do
        new_stage = create(:crm_stage, pipeline: pipeline, account: account, position: 2)

        expect do
          patch "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/deals/#{deal.id}",
                params: { deal: { stage_id: new_stage.id } },
                headers: agent.create_new_auth_token,
                as: :json
        end.to change(Crm::Activity, :count).by(1)

        expect(response).to have_http_status(:success)
        activity = Crm::Activity.last
        expect(activity.activity_type).to eq('stage_change')
        expect(activity.contact_id).to eq(contact.id)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        patch "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/deals/#{deal.id}",
              params: { deal: { title: 'Updated' } },
              as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/crm/pipelines/:pipeline_id/deals/:id' do
    let!(:deal) { create(:crm_deal, account: account, stage: stage, contact: contact) }

    context 'when authenticated as admin' do
      it 'destroys the deal' do
        expect do
          delete "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/deals/#{deal.id}",
                 headers: admin.create_new_auth_token
        end.to change(Crm::Deal, :count).by(-1)

        expect(response).to have_http_status(:success)
      end
    end

    context 'when authenticated as agent' do
      it 'returns unauthorized (admin-only delete)' do
        delete "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/deals/#{deal.id}",
               headers: agent.create_new_auth_token

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/deals/#{deal.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
