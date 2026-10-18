# frozen_string_literal: true

class UseCase::Financial::Category::DestroyCategoryUseCase
  # @param [User] user
  # @param [String] id
  # @return [Financial::Category]
  def call(user:, id:)
    category = user.categories.find(id)
    ensure_deletable!(category)

    category.destroy!
    category
  end

  private

  def ensure_deletable!(category)
    if category.pending_installments?
      raise ArgumentError, "Cannot delete category with remaining installments"
    end

    if category.standalone_activity?
      raise ArgumentError, "Cannot delete category with associated transactions"
    end
  end
end
