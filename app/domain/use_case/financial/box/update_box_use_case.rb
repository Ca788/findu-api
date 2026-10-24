# frozen_string_literal: true

class UseCase::Financial::Box::UpdateBoxUseCase
  # @param [User] user
  # @param [String] id
  # @param [Hash] attributes
  # @return [Financial::Box]
  def call(user:, id:, attributes:)
    attrs = attributes.symbolize_keys.slice(*Financial::Box::PERMITTED_ATTRIBUTES)
    box = user.boxes.find(id)
    box.update!(attrs)
    box
  end
end
