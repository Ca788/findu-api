# frozen_string_literal: true

module Financial
  # Daily job that:
  #   - Keeps 12 months of transactions materialized for each active recurrence rule.
  #   - Marks installment plans as "completed" when all installments are paid.
  #
  # Does not recreate transactions the user manually deleted in the past.
  class MaterializeFutureEntriesJob < ApplicationJob
    queue_as :default

    def perform
      materialize_recurrences
      complete_installment_plans
    end

    private

    def materialize_recurrences
      Financial::RecurrenceRule.active_only.find_each do |rule|
        UseCase::Financial::Recurrence::MaterializeRecurrenceRuleUseCase.new.call(rule: rule)
      end
    end

    def complete_installment_plans
      Financial::InstallmentPlan.status_active.find_each do |plan|
        next if plan.remaining_count > 0

        plan.update!(status: "completed")
        notify_completed(plan)
      end
    end

    def notify_completed(plan)
      UseCase::Notifications::DispatchNotificationUseCase.new.call(
        user:       plan.user,
        kind:       :installment_completed,
        title:      "Parcelamento quitado: #{plan.description.presence || 'sem descrição'}",
        body:       "#{plan.total_installments} parcelas pagas, #{Support::Money.brl(plan.paid_amount)} no total.",
        data:       { route: "/installments", installment_plan_id: plan.id },
        dedupe_key: "installment_completed:#{plan.id}"
      )
    end
  end
end
