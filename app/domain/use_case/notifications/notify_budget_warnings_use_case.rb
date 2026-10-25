# frozen_string_literal: true

class UseCase::Notifications::NotifyBudgetWarningsUseCase
  def initialize(dispatcher: UseCase::Notifications::DispatchNotificationUseCase.new)
    @dispatcher = dispatcher
  end

  def call(user:, warnings:)
    warnings.filter_map do |warning|
      exceeded = warning[:status] == "exceeded"
      kind     = exceeded ? :budget_exceeded : :budget_warning

      @dispatcher.call(
        user:       user,
        kind:       kind,
        title:      title_for(exceeded, warning),
        body:       body_for(warning),
        data:       { route: "/budgets", budget_id: warning[:budget_id] },
        dedupe_key: "#{kind}:#{warning[:budget_id]}:#{warning[:period_start]}"
      )
    end
  end

  private

  def title_for(exceeded, warning)
    percent = warning[:usage_percent].round
    exceeded ? "Orçamento estourado: #{percent}% do limite" : "Orçamento em #{percent}% do limite"
  end

  def body_for(warning)
    spent = Support::Money.brl(warning[:spent_amount])
    limit = Support::Money.brl(warning[:limit_amount])
    "#{spent} de #{limit} no período #{warning[:period_start].strftime('%d/%m')} a #{warning[:period_end].strftime('%d/%m')}"
  end
end
