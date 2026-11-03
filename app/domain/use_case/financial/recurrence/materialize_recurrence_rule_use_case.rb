# frozen_string_literal: true

class UseCase::Financial::Recurrence::MaterializeRecurrenceRuleUseCase
  DEFAULT_HORIZON_MONTHS = 12

  # Materializes future transactions for the rule within the horizon window.
  # Idempotent per (recurrence_rule_id, competency_month).
  #
  # @param [Financial::RecurrenceRule] rule
  # @param [Date, nil] up_to last month to materialize (default: today + 12 months)
  # @return [Integer] number of transactions created
  def call(rule:, up_to: nil)
    return 0 unless rule.active?

    horizon_end = normalize_horizon(up_to)
    horizon_end = [horizon_end, rule.ends_on].compact.min if rule.ends_on

    horizon_start = [rule.starts_on.beginning_of_month, Date.current.beginning_of_month].max

    created = 0
    ApplicationRecord.transaction do
      cursor = horizon_start
      while cursor <= horizon_end.beginning_of_month
        created += 1 if materialize_month(rule, cursor)
        cursor = cursor.next_month
      end
    end

    created
  end

  private

  def normalize_horizon(value)
    parsed = Support::DateParser.parse(value)
    (parsed || Date.current + DEFAULT_HORIZON_MONTHS.months).beginning_of_month
  end

  # @return [Boolean] true when a new transaction was created
  def materialize_month(rule, competency)
    existing = rule.transactions.find_by(competency_month: competency)
    return false if existing

    rule.transactions.create!(
      user_id:          rule.user_id,
      transaction_type: rule.transaction_type,
      amount:           rule.amount,
      description:      rule.description,
      category_id:      rule.category_id,
      competency_month: competency,
      occurred_at:      occurred_at_for(rule, competency),
      status:           "pending"
    )
    true
  end

  def occurred_at_for(rule, competency)
    day = rule.day_of_month || rule.starts_on.day
    max_day = Date.civil(competency.year, competency.month, -1).day
    Date.new(competency.year, competency.month, [day, max_day].min).in_time_zone.noon
  end
end
