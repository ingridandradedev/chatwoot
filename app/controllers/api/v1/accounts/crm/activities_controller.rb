# app/controllers/api/v1/accounts/crm/activities_controller.rb
module Api::V1::Accounts::Crm
  class ActivitiesController < BaseController
    before_action :set_contact

    def index
      @activities = @contact.crm_activities
                            .where(account: Current.account)
                            .recent_first
                            .page(params[:page]).per(20)
    end

    def create
      unless Crm::Activity::MANUAL_TYPES.include?(params[:activity][:activity_type])
        render json: { error: 'Only manual types allowed' }, status: :unprocessable_entity
        return
      end
      @activity = Crm::Activity.new(activity_params.merge(
        account: Current.account, user: current_user, contact: @contact
      ))
      authorize @activity
      @activity.save!
    end

    private

    def set_contact
      @contact = Current.account.contacts.find(params[:contact_id])
    end

    def activity_params
      params.require(:activity).permit(:activity_type, :description)
    end
  end
end
