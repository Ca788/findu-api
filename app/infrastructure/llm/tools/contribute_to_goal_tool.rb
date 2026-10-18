# frozen_string_literal: true

module Llm
  module Tools
    class ContributeToGoalTool < BaseTool
      description "Registra um aporte em uma meta existente, somando ao valor já guardado. " \
                  "Use quando o usuário disser que guardou, separou ou depositou dinheiro na meta. " \
                  "Busque o id com list_goals antes, se não tiver."

      param :id, type: "string", desc: "UUID da meta."
      param :amount, type: "number", desc: "Valor do aporte em reais."

      def initialize(user:, contributor: UseCase::Financial::Goal::ContributeToGoalUseCase.new)
        super()
        @user        = user
        @contributor = contributor
      end

      def execute(id:, amount:)
        safe_execute do
          goal = @contributor.call(user: @user, id: id.to_s, amount: amount)
          {
            success:          true,
            goal_id:          goal.id,
            name:             goal.name,
            current_amount:   goal.current_amount.to_s,
            remaining_amount: goal.remaining_amount.to_s,
            progress_percent: goal.progress_percent,
            status:           goal.status
          }
        end
      end
    end
  end
end
