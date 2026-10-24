# frozen_string_literal: true

class UseCase::Financial::Box::CreateBoxUseCase
  # @param [User] user
  # @param [Hash] attributes
  # @param [Numeric, String, nil] initial_balance saldo já existente no banco
  # @return [Financial::Box]
  def call(user:, attributes:, initial_balance: nil)
    attrs = attributes.symbolize_keys.slice(*Financial::Box::PERMITTED_ATTRIBUTES)
    attrs[:position] = next_position(user) unless attrs.key?(:position)

    Financial::Box.transaction do
      box = user.boxes.create!(attrs)
      seed_balance!(box, initial_balance)
      box
    end
  end

  private

  def next_position(user)
    (user.boxes.maximum(:position) || -1) + 1
  end

  def seed_balance!(box, initial_balance)
    value = initial_balance.to_s.presence&.to_d
    return if value.nil? || value.zero?

    UseCase::Financial::Box::MoveBoxFundsUseCase.new.call(
      user:        box.user,
      id:          box.id,
      kind:        "adjustment",
      amount:      value,
      description: "Saldo inicial"
    )
    box.reload
  end
end
