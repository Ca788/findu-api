# frozen_string_literal: true

class UseCase::Financial::Box::ArchiveBoxUseCase
  # @param [User] user
  # @param [String] id
  # @param [Boolean] archived
  # @return [Financial::Box]
  def call(user:, id:, archived: true)
    box = user.boxes.find(id)

    if archived
      raise ArgumentError, "Retire o saldo antes de arquivar a caixinha" if box.balance.to_d.positive?

      box.update!(archived_at: box.archived_at || Time.current)
    else
      box.update!(archived_at: nil)
    end

    box
  end
end
