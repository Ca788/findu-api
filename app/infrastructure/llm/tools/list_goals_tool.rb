# frozen_string_literal: true

module Llm
  module Tools
    class ListGoalsTool < BaseTool
      description "Lista as metas de economia do usuário, com progresso e valor que falta. " \
                  "Use quando ele pedir para ver metas, objetivos ou quanto falta juntar."

      param :status, type: "string", desc: "'active', 'achieved' ou 'canceled'. Se omitido, lista todas.", required: false

      def initialize(user:, lister: UseCase::Financial::Goal::ListGoalsUseCase.new)
        super()
        @user   = user
        @lister = lister
      end

      def execute(status: nil)
        safe_execute do
          goals = @lister.call(user: @user, status: whitelist(status, allowed: GOAL_STATUSES))
          {
            success: true,
            count:   goals.size,
            goals:   goals.map { |goal| serialize(goal) }
          }
        end
      end

      private

      def serialize(goal)
        {
          id:               goal.id,
          name:             goal.name,
          status:           goal.status,
          target_amount:    goal.target_amount.to_s,
          current_amount:   goal.current_amount.to_s,
          remaining_amount: goal.remaining_amount.to_s,
          progress_percent: goal.progress_percent,
          deadline:         goal.deadline&.iso8601,
          category:         goal.category&.name
        }
      end
    end
  end
end
