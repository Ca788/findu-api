# frozen_string_literal: true

class UseCase::Financial::Transaction::DestroyTransactionUseCase
  # @param [User]
  # @param [String]
  # @return [Financial::Transaction]
  def call(user:, id:)
    transaction = user.transactions.find(id)
    category_id = transaction.category_id
    installment = transaction.installment_plan_id.present?

    transaction.destroy!
    release_category(user, category_id) if installment
    transaction
  end

  private

  def release_category(user, category_id)
    UseCase::Financial::Category::PurgeCategoryWithoutInstallmentsUseCase.new.call(
      user:         user,
      category_ids: category_id
    )
  end
end
