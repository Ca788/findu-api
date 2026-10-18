# frozen_string_literal: true

class UseCase::Financial::InstallmentPlan::UpdateInstallmentPlanUseCase
  # Allows updating description, category, and monthly amount only.
  # Changes apply only to future pending installments.
  # To change count/start month, cancel and create a new plan.
  #
  # @param [User]
  # @param [String] plan id
  # @param [Hash]
  # @return [Financial::InstallmentPlan]
  def call(user:, id:, attributes:)
    plan = user.installment_plans.find(id)
    permitted = attributes.symbolize_keys.slice(:description, :category_id, :monthly_amount)
    previous_category_id = plan.category_id

    ApplicationRecord.transaction do
      plan.update!(permitted)
      propagate_to_future_pending(plan, permitted)
    end

    release_previous_category(user, previous_category_id, plan.category_id)
    plan
  end

  private

  def release_previous_category(user, previous_category_id, current_category_id)
    return if previous_category_id.blank?
    return if previous_category_id == current_category_id

    UseCase::Financial::Category::PurgeCategoryWithoutInstallmentsUseCase.new.call(
      user:         user,
      category_ids: previous_category_id,
      orphaned:     true
    )
  end

  def propagate_to_future_pending(plan, permitted)
    future = plan.transactions
                 .where(status: "pending")
                 .where("competency_month >= ?", Date.current.beginning_of_month)

    payload = {}
    payload[:amount]      = permitted[:monthly_amount] if permitted.key?(:monthly_amount)
    payload[:category_id] = permitted[:category_id]    if permitted.key?(:category_id)

    if permitted.key?(:description)
      future.find_each do |t|
        t.update_columns(
          description: rebuild_description(permitted[:description], plan, t.installment_number),
          updated_at:  Time.current
        )
      end
    end

    future.update_all(payload.merge(updated_at: Time.current)) if payload.any?
  end

  def rebuild_description(base, plan, installment_number)
    label = base.presence || "Parcelamento"
    "#{label} #{installment_number}/#{plan.total_installments}"
  end
end
