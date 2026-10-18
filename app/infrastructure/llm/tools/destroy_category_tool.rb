# frozen_string_literal: true

module Llm
  module Tools
    class DestroyCategoryTool < BaseTool
      description "Exclui uma categoria do usuário pelo id. " \
                  "Falha se ainda houver parcelas em aberto ou lançamentos/recorrências que não sejam de parcelamento. " \
                  "Categoria usada só em parcelamento pode ser excluída quando não restam parcelas pendentes " \
                  "(o sistema também exclui sozinho nesse caso)."

      param :id, type: "string", desc: "UUID da categoria."

      def initialize(user:, destroyer: UseCase::Financial::Category::DestroyCategoryUseCase.new)
        super()
        @user      = user
        @destroyer = destroyer
      end

      def execute(id:)
        safe_execute do
          category = @destroyer.call(user: @user, id: id.to_s)
          { success: true, category_id: category.id, name: category.name }
        end
      end
    end
  end
end
