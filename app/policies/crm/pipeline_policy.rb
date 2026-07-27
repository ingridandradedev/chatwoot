module Crm
  class PipelinePolicy < ApplicationPolicy
    def index?
      true
    end

    def show?
      true
    end

    def create?
      @account_user.administrator?
    end

    def update?
      @account_user.administrator?
    end

    def destroy?
      @account_user.administrator?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.where(account_id: @account.id)
      end
    end
  end
end
