# frozen_string_literal: true

class UseCase::Financial::Transaction::CreateTransactionUseCase
  # @param [UseCase::Financial::Category::FindOrCreateByNameUseCase]
  def initialize(category_finder: UseCase::Financial::Category::FindOrCreateByNameUseCase.new)
    @category_finder = category_finder
  end

  # @param [User]
  # @param [BigDecimal, Numeric, String]
  # @param [String]
  # @param [String, nil]
  # @param [DateTime, String, nil]
  # @param [Date, String, nil]
  # @param [String, nil]
  # @param [String, nil]
  # @param [String, nil]
  # @param [String, nil]
  # @param [String, nil]
  # @param [String, nil]
  # @param [Hash, nil]
  # @return [Financial::Transaction]
  def call(user:, amount:, transaction_type:,
           description: nil, occurred_at: nil,
           competency_month: nil, status: "pending",
           category_id: nil, category_name: nil, artifact_id: nil,
           payer_name: nil, payer_phone: nil, metadata: nil)
    category = resolve_category(user, category_id, category_name)
    artifact = resolve_artifact(user, artifact_id)

    transaction = user.transactions.create!(
      amount:           amount,
      transaction_type: transaction_type,
      description:      description,
      occurred_at:      occurred_at,
      competency_month: resolve_competency(competency_month, occurred_at),
      status:           status.presence || "pending",
      category:         category,
      artifact:         artifact,
      payer_name:       payer_name,
      payer_phone:      payer_phone,
      metadata:         metadata
    )

    transaction.budget_warnings = budget_warnings_for(transaction)
    UseCase::Notifications::NotifyBudgetWarningsUseCase.new.call(user: transaction.user, warnings: transaction.budget_warnings)
    transaction
  end

  private

  # @return [Date]
  def resolve_competency(explicit, occurred_at)
    parsed = Support::DateParser.parse(explicit) || Support::DateParser.parse(occurred_at)
    (parsed || Date.current).beginning_of_month
  end

  def budget_warnings_for(transaction)
    return [] unless transaction.expense?

    UseCase::Financial::Budget::CheckBudgetConsumptionUseCase.new.call(
      user:        transaction.user,
      occurred_at: transaction.occurred_at || transaction.competency_month
    )
  end

  # @return [Financial::Category, nil]
  def resolve_category(user, id, name)
    return user.categories.find(id) if id.present?

    @category_finder.call(user: user, name: name)
  end

  def resolve_artifact(user, id)
    return nil if id.blank?

    user.artifacts.find(id)
  end
end
