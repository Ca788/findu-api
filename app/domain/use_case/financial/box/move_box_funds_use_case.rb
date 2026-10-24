# frozen_string_literal: true

# Único ponto de escrita no ledger da caixinha. Saldo é recalculado sob lock e
# nunca fica negativo. `adjustment` recebe o saldo-alvo e gera o delta.
class UseCase::Financial::Box::MoveBoxFundsUseCase
  class InsufficientFunds < ArgumentError; end

  Result = Struct.new(:box, :movement, keyword_init: true)

  # @param [User] user
  # @param [String] id
  # @param [String] kind deposit | withdraw | adjustment
  # @param [Numeric, String] amount valor do movimento (ou saldo-alvo no adjustment)
  # @param [String, nil] description
  # @param [String] source
  # @param [Time, nil] occurred_at
  # @param [String, nil] transaction_id
  # @return [Result]
  def call(user:, id:, kind:, amount:, description: nil, source: "manual", occurred_at: nil, transaction_id: nil)
    ensure_kind!(kind)
    ensure_source!(source)
    value = amount.to_d

    box = user.boxes.active.find(id)

    Financial::Box.transaction do
      box.lock!
      delta = delta_for(kind, value, box.balance.to_d)
      new_balance = box.balance.to_d + delta
      raise InsufficientFunds, "Saldo insuficiente na caixinha" if new_balance.negative?

      movement = box.movements.create!(
        user:           user,
        kind:           kind,
        source:         source,
        amount:         delta,
        balance_after:  new_balance,
        description:    description.presence,
        occurred_at:    occurred_at || Time.current,
        transaction_id: transaction_id
      )
      box.update!(balance: new_balance)

      Result.new(box: box, movement: movement)
    end
  end

  private

  def delta_for(kind, value, current_balance)
    case kind.to_s
    when "deposit"
      raise ArgumentError, "amount must be greater than 0" unless value.positive?

      value
    when "withdraw"
      raise ArgumentError, "amount must be greater than 0" unless value.positive?

      -value
    when "adjustment"
      raise ArgumentError, "target balance must be >= 0" if value.negative?

      delta = value - current_balance
      raise ArgumentError, "Saldo já está em #{value}" if delta.zero?

      delta
    end
  end

  def ensure_kind!(kind)
    return if Financial::BoxMovement::KINDS.value?(kind.to_s)

    raise ArgumentError, "Invalid movement kind"
  end

  def ensure_source!(source)
    return if Financial::BoxMovement::SOURCES.value?(source.to_s)

    raise ArgumentError, "Invalid movement source"
  end
end
