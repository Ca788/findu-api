# frozen_string_literal: true

class UseCase::Financial::Transaction::UpdateTransactionUseCase
  # @param [User]
  # @param [String]
  # @param [BigDecimal, Numeric, String, nil]
  # @param [String, nil]
  # @param [String, nil]
  # @param [DateTime, String, nil]
  # @param [Date, String, nil]
  # @param [String, nil]
  # @param [String, nil]
  # @param [String, nil]
  # @param [String, nil]
  # @param [Hash, nil]
  # @return [Financial::Transaction]
  def call(user:, id:, amount: nil, transaction_type: nil, description: nil,
           occurred_at: nil, competency_month: nil, status: nil,
           category_id: nil, payer_name: nil, payer_phone: nil, metadata: nil)
    transaction = user.transactions.find(id)
    previous_category_id = transaction.category_id
    installment_related  = transaction.installment_plan_id.present?

    attributes = {
      amount:           amount,
      transaction_type: transaction_type,
      description:      description,
      occurred_at:      occurred_at,
      status:           status,
      payer_name:       payer_name,
      payer_phone:      payer_phone,
      metadata:         metadata
    }.compact

    if competency_month.present?
      parsed = Support::DateParser.parse(competency_month)
      attributes[:competency_month] = parsed.beginning_of_month if parsed
    end

    attributes[:category] = resolve_category(user, category_id) unless category_id.nil?

    transaction.update!(attributes)
    released = release_installment_categories(user, transaction, previous_category_id, installment_related)
    transaction.reload if released.present?
    transaction.budget_warnings = budget_warnings_for(transaction)
    UseCase::Notifications::NotifyBudgetWarningsUseCase.new.call(user: transaction.user, warnings: transaction.budget_warnings)
    transaction
  end

  private

  def release_installment_categories(user, transaction, previous_category_id, installment_related)
    return [] unless installment_related || transaction.installment_plan_id.present?

    UseCase::Financial::Category::PurgeCategoryWithoutInstallmentsUseCase.new.call(
      user:         user,
      category_ids: [previous_category_id, transaction.category_id]
    )
  end

  def budget_warnings_for(transaction)
    return [] unless transaction.expense?

    UseCase::Financial::Budget::CheckBudgetConsumptionUseCase.new.call(
      user:        transaction.user,
      occurred_at: transaction.occurred_at || transaction.competency_month
    )
  end

  def resolve_category(user, id)
    return nil if id.blank?

    user.categories.find(id)
  end
end
