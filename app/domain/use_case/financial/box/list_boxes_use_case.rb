# frozen_string_literal: true

class UseCase::Financial::Box::ListBoxesUseCase
  # @param [User] user
  # @param [String, nil] kind
  # @param [Boolean] archived
  # @return [ActiveRecord::Relation<Financial::Box>]
  def call(user:, kind: nil, archived: false)
    scope = archived ? user.boxes.archived : user.boxes.active
    scope.by_kind(kind).ordered
  end
end
