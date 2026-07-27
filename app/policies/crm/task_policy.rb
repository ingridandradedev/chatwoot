module Crm
  class TaskPolicy < ApplicationPolicy
    def index?
      true
    end

    def show?
      true
    end

    def create?
      true
    end

    def update?
      true
    end

    def destroy?
      @account_user.administrator? || record.created_by_id == @user.id
    end
  end
end
