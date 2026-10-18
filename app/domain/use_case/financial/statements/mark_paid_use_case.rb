# frozen_string_literal: true

class UseCase::Financial::Statements::MarkPaidUseCase
  # @param [User]
  # @param [String] transaction id
  # @param [DateTime, String, nil] paid_at defaults to Time.current
  # @return [Financial::Transaction]
  def call(user:, id:, paid_at: nil)
    transaction = user.transactions.find(id)
    category_id = transaction.category_id
    installment = transaction.installment_plan_id.present?

    transaction.update!(
      status:  "paid",
      paid_at: Support::DateParser.parse(paid_at) || Time.current
    )

    if installment
      released = release_category(user, category_id)
      transaction.reload if released.any?
    end

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
