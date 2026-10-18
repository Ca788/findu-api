# frozen_string_literal: true

class UseCase::Financial::Transaction::DestroyTransactionsBatchUseCase
  Result = Struct.new(:destroyed_ids, :missing_ids, keyword_init: true)

  MAX_BATCH_SIZE = 200

  # @param [User]
  # @param [Array<String>]
  # @return [Result]
  def call(user:, ids:)
    requested = Array(ids).map(&:to_s).compact_blank.uniq
    raise ArgumentError, "ids must be present" if requested.empty?
    raise ArgumentError, "max batch size is #{MAX_BATCH_SIZE}" if requested.size > MAX_BATCH_SIZE

    scoped = user.transactions.where(id: requested)
    found_ids = scoped.pluck(:id).map(&:to_s)
    category_ids = scoped.where.not(installment_plan_id: nil).pluck(:category_id)

    Financial::Transaction.transaction do
      scoped.destroy_all
    end

    UseCase::Financial::Category::PurgeCategoryWithoutInstallmentsUseCase.new.call(
      user:         user,
      category_ids: category_ids
    )

    Result.new(
      destroyed_ids: found_ids,
      missing_ids:   requested - found_ids
    )
  end
end
