# frozen_string_literal: true

class UseCase::Chat::BuildUserContextUseCase
  Context = Struct.new(
    :statement, :budgets, :recent_transactions, :reference_date, :goals, :investments,
    keyword_init: true
  )

  RECENT_TRANSACTIONS_LIMIT = 10
  CACHE_TTL                 = 15.minutes

  def initialize(statement_use_case: UseCase::Financial::Statements::ShowMonthlyStatementUseCase.new,
                 budgets_use_case:   UseCase::Financial::Budget::ListCurrentBudgetsUseCase.new)
    @statement_use_case = statement_use_case
    @budgets_use_case   = budgets_use_case
  end

  # @param [User] user
  # @param [Hash, nil] timings
  # @return [Context]
  def call(user:, timings: nil)
    today = Date.current

    fingerprint_started = Support::ChatPipelineTiming.monotonic
    key = cache_key(user, today)
    if timings
      timings["context_fingerprint_ms"] = Support::ChatPipelineTiming.elapsed_ms(fingerprint_started)
    end

    cache_hit = true
    context = Rails.cache.fetch(key, expires_in: CACHE_TTL) do
      cache_hit = false
      build_context(user, today)
    end
    timings["context_cache_hit"] = cache_hit if timings
    context
  end

  private

  def build_context(user, today)
    Context.new(
      statement:           @statement_use_case.call(user: user),
      budgets:             @budgets_use_case.call(user: user, date: today).budgets,
      recent_transactions: recent_transactions(user, today),
      reference_date:      today,
      goals:               active_goals(user),
      investments:         active_investments(user)
    )
  end

  def cache_key(user, today)
    fingerprint = [
      Financial::Transaction.where(user_id: user.id).maximum(:updated_at),
      Financial::Budget.where(user_id: user.id).maximum(:updated_at),
      Financial::Category.where(user_id: user.id).maximum(:updated_at),
      Financial::RecurrenceRule.where(user_id: user.id).maximum(:updated_at),
      Financial::InstallmentPlan.where(user_id: user.id).maximum(:updated_at),
      Financial::Goal.where(user_id: user.id).maximum(:updated_at),
      Financial::Investment.where(user_id: user.id).maximum(:updated_at),
      today
    ].join(":")

    "chat:user_context:#{user.id}:#{Digest::MD5.hexdigest(fingerprint)}"
  end

  def active_goals(user)
    user.goals.where(status: "active").order(deadline: :asc).limit(8).to_a
  end

  def active_investments(user)
    user.investments.where(status: "active").order(invested_on: :desc).limit(8).to_a
  end

  def recent_transactions(user, today)
    user.transactions
        .includes(:category)
        .in_competency(today)
        .order(status: :asc, paid_at: :desc, created_at: :desc)
        .limit(RECENT_TRANSACTIONS_LIMIT)
        .to_a
  end
end
