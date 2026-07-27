# app/controllers/api/v1/accounts/crm/deals_controller.rb
module Api::V1::Accounts::Crm
  class DealsController < BaseController
    before_action :set_pipeline
    before_action :set_deal, only: [:show, :update, :destroy]

    def index
      @deals = @pipeline.deals.where(account: Current.account)
      @deals = @deals.where(stage_id: params[:stage_id]) if params[:stage_id].present?
      @deals = @deals.includes(:contact, :stage).page(params[:page]).per(15)
    end

    def show; end

    def create
      @deal = Crm::Deal.new(deal_params.merge(
        account: Current.account, created_by: current_user
      ))
      authorize @deal
      @deal.save!
    end

    def update
      authorize @deal
      old_stage_id = @deal.stage_id
      @deal.update!(deal_params)
      create_stage_change_activity(old_stage_id) if old_stage_id != @deal.stage_id
    end

    def destroy
      authorize @deal
      @deal.destroy!
      head :ok
    end

    private

    def set_pipeline
      @pipeline = crm_pipelines.find(params[:pipeline_id])
    end

    def set_deal
      @deal = @pipeline.deals.find(params[:id])
    end

    def deal_params
      params.require(:deal).permit(:contact_id, :stage_id, :title, :value)
    end

    def create_stage_change_activity(old_stage_id)
      old_stage = Crm::Stage.find(old_stage_id)
      new_stage = @deal.stage
      Crm::Activity.create!(
        account: Current.account,
        contact: @deal.contact,
        user: current_user,
        activity_type: :stage_change,
        description: "Movido de '#{old_stage.name}' para '#{new_stage.name}'",
        metadata: { from_stage_id: old_stage_id, to_stage_id: new_stage.id }
      )
    end
  end
end
