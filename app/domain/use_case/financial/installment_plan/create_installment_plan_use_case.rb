# frozen_string_literal: true

class UseCase::Financial::InstallmentPlan::CreateInstallmentPlanUseCase
  # Creates an installment plan and materializes all installments at once
  # (fixed horizon = total_installments).
  #
  # @param [User]
  # @param [Hash]
  # @return [Financial::InstallmentPlan]
  def call(user:, attributes:)
    plan = nil

    ApplicationRecord.transaction do
      plan = user.installment_plans.create!(
        attributes.symbolize_keys.slice(*::Financial::InstallmentPlan::PERMITTED_ATTRIBUTES).merge(
          total_amount: derive_total_amount(attributes),
          started_at:   Time.current
        )
      )

      materialize_installments(plan)
    end

    plan
  end

  private

  def derive_total_amount(attributes)
    total = attributes[:total_amount] || attributes["total_amount"]
    return total if total.present?

    monthly = attributes[:monthly_amount] || attributes["monthly_amount"]
    count   = attributes[:total_installments] || attributes["total_installments"]
    return nil if monthly.blank? || count.blank?

    monthly.to_d * count.to_i
  end

  def materialize_installments(plan)
    (1..plan.total_installments).each do |n|
      competency = plan.first_competency + (n - 1).months

      plan.transactions.create!(
        user_id:            plan.user_id,
        transaction_type:   plan.transaction_type,
        amount:             plan.monthly_amount,
        description:        installment_description(plan, n),
        category_id:        plan.category_id,
        competency_month:   competency,
        occurred_at:        competency.in_time_zone.noon,
        installment_number: n,
        status:             "pending"
      )
    end
  end

  def installment_description(plan, n)
    base = plan.description.presence || "Parcelamento"
    "#{base} #{n}/#{plan.total_installments}"
  end
end
