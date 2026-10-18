# frozen_string_literal: true

class UseCase::Financial::InstallmentPlan::CancelInstallmentPlanUseCase
  # Cancels the plan and removes future pending installments.
  # Past or paid installments keep the history.
  #
  # @param [User]
  # @param [String] plan id
  # @return [Financial::InstallmentPlan]
  def call(user:, id:)
    plan = user.installment_plans.find(id)

    category_id = plan.category_id

    ApplicationRecord.transaction do
      plan.update!(status: "canceled", canceled_at: Time.current)

      plan.transactions
          .where(status: "pending")
          .where("competency_month >= ?", Date.current.beginning_of_month)
          .destroy_all
    end

    UseCase::Financial::Category::PurgeCategoryWithoutInstallmentsUseCase.new.call(
      user:         user,
      category_ids: category_id
    )
    plan.reload
  end
end
