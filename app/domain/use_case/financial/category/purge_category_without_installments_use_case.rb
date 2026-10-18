# frozen_string_literal: true

class UseCase::Financial::Category::PurgeCategoryWithoutInstallmentsUseCase
  # Exclui categorias que não têm mais parcelas em aberto e não possuem
  # lançamentos ou recorrências fora de parcelamento.
  #
  # @param [User] user
  # @param [String, Array<String>] category_ids
  # @param [Boolean] orphaned
  # @return [Array<Financial::Category>]
  def call(user:, category_ids:, orphaned: false)
    Array(category_ids).compact.uniq.filter_map do |category_id|
      Financial::Category.release_without_pending_installments!(
        user:        user,
        category_id: category_id,
        orphaned:    orphaned
      )
    end
  end
end
