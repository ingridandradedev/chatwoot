# app/controllers/api/v1/accounts/crm/tasks_controller.rb
module Api::V1::Accounts::Crm
  class TasksController < BaseController
    before_action :set_contact, only: [:index_for_contact, :create]
    before_action :set_task, only: [:show, :update, :destroy, :complete, :reopen]

    # GET /crm/contacts/:contact_id/tasks
    def index_for_contact
      @tasks = @contact.crm_tasks
                       .where(account: Current.account)
                       .pending_and_overdue
                       .order(due_date: :asc)
                       .page(params[:page]).per(15)
    end

    # GET /crm/tasks
    def index
      @tasks = Crm::Task.where(account: Current.account)
      @tasks = @tasks.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
      @tasks = @tasks.where(status: params[:status]) if params[:status].present?
      @tasks = @tasks.order(due_date: :asc).page(params[:page]).per(15)
    end

    def show; end

    def create
      @task = Crm::Task.new(task_params.merge(
        account: Current.account, created_by: current_user, contact: @contact
      ))
      authorize @task
      @task.save!
    end

    def update
      authorize @task
      if @task.completed?
        render json: { error: 'Cannot edit completed task' }, status: :unprocessable_entity
        return
      end
      old_status = @task.status
      @task.update!(task_params)
      # If due_date extended on overdue task, reset to pending
      @task.update!(status: :pending) if old_status == 'overdue' && @task.due_date > Time.current
      # Reset reminded if reminder_at changed
      @task.update!(reminded: false) if task_params[:reminder_at].present?
    end

    def destroy
      authorize @task
      @task.destroy!
      head :ok
    end

    # POST /crm/tasks/:id/complete
    def complete
      authorize @task, :update?
      @task.complete!(current_user)
    end

    # POST /crm/tasks/:id/reopen
    def reopen
      authorize @task, :update?
      @task.reopen!
    end

    private

    def set_contact
      @contact = Current.account.contacts.find(params[:contact_id])
    end

    def set_task
      @task = Crm::Task.where(account: Current.account).find(params[:id])
    end

    def task_params
      params.require(:task).permit(:title, :description, :assignee_id,
                                   :due_date, :reminder_at, :priority)
    end
  end
end
