# frozen_string_literal: true

class UseCase::Notifications::NotifyDueEntriesUseCase
  DUE_SOON_DAYS = 3
  OVERDUE_GRACE = 30

  def initialize(dispatcher: UseCase::Notifications::DispatchNotificationUseCase.new)
    @dispatcher = dispatcher
  end

  def call(user:, today: Date.current)
    pending = user.transactions.expense.pending.where.not(occurred_at: nil)

    [
      *notify(user, pending.where(occurred_at: today.all_day), :entry_due_today, today),
      *notify(user, pending.where(occurred_at: (today + 1).beginning_of_day..(today + DUE_SOON_DAYS).end_of_day), :entry_due_soon, today),
      *notify(user, pending.where(occurred_at: (today - OVERDUE_GRACE).beginning_of_day...today.beginning_of_day), :entry_overdue, today)
    ]
  end

  private

  def notify(user, scope, kind, today)
    scope.includes(:category).find_each.filter_map do |entry|
      @dispatcher.call(
        user:       user,
        kind:       kind,
        title:      title_for(kind, entry, today),
        body:       body_for(entry),
        data:       { route: "/statements/detail", month: entry.competency_month.strftime("%Y-%m"), transaction_id: entry.id },
        dedupe_key: "#{kind}:#{entry.id}"
      )
    end
  end

  def title_for(kind, entry, today)
    amount = Support::Money.brl(entry.amount)
    case kind
    when :entry_due_today then "#{label(entry)} vence hoje: #{amount}"
    when :entry_due_soon  then "#{label(entry)} vence em #{(entry.occurred_at.to_date - today).to_i} dias: #{amount}"
    when :entry_overdue   then "#{label(entry)} está atrasada: #{amount}"
    else raise ArgumentError, "unknown kind #{kind}"
    end
  end

  def body_for(entry)
    parts = [entry.category&.name, "vencimento #{entry.occurred_at.strftime('%d/%m')}"]
    parts.compact.join(" · ")
  end

  def label(entry)
    entry.description.presence || entry.category&.name || "Conta"
  end
end
