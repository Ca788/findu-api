# frozen_string_literal: true

module Llm
  module Tools
    class RegisterGoalTool < BaseTool
      description "Cria uma meta de economia (objetivo com valor alvo e prazo). " \
                  "Use quando o usuário falar em meta, objetivo, juntar dinheiro ou reserva — " \
                  "não use para limite de gastos do mês (isso é register_budget)."

      param :name, type: "string", desc: "Nome da meta (ex.: 'Viagem', 'Reserva de emergência')."
      param :target_amount, type: "number", desc: "Valor alvo em reais."
      param :current_amount, type: "number", desc: "Quanto já tem guardado. Padrão: 0.", required: false
      param :deadline, type: "string", desc: "Data limite ISO 8601 (YYYY-MM-DD).", required: false
      param :category_name, type: "string", desc: "Categoria opcional para vincular a meta.", required: false
      param :notes, type: "string", desc: "Observação curta.", required: false

      def initialize(user:,
                     creator: UseCase::Financial::Goal::CreateGoalUseCase.new,
                     category_finder: UseCase::Financial::Category::FindOrCreateByNameUseCase.new)
        super()
        @user            = user
        @creator         = creator
        @category_finder = category_finder
      end

      def execute(name:, target_amount:, current_amount: nil, deadline: nil, category_name: nil, notes: nil)
        safe_execute do
          category = resolve_category(category_name)
          goal = @creator.call(
            user:       @user,
            attributes: {
              name:           name,
              target_amount:  target_amount,
              current_amount: current_amount,
              deadline:       parse_date(deadline),
              category_id:    category&.id,
              notes:          notes
            }
          )

          {
            success:          true,
            goal_id:          goal.id,
            name:             goal.name,
            target_amount:    goal.target_amount.to_s,
            current_amount:   goal.current_amount.to_s,
            progress_percent: goal.progress_percent,
            status:           goal.status,
            deadline:         goal.deadline&.iso8601
          }
        end
      end

      private

      def resolve_category(category_name)
        return nil if category_name.blank?

        @category_finder.call(user: @user, name: category_name.to_s.strip)
      end
    end
  end
end
