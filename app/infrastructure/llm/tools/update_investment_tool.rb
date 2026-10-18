# frozen_string_literal: true

module Llm
  module Tools
    class UpdateInvestmentTool < BaseTool
      description "Atualiza um investimento existente: valor atual, status (active/redeemed) ou instituição. " \
                  "Busque o id com list_investments antes, se não tiver."

      param :id, type: "string", desc: "UUID do investimento."
      param :current_amount, type: "number", desc: "Novo valor de mercado em reais.", required: false
      param :status, type: "string", desc: "'active' ou 'redeemed'.", required: false
      param :institution, type: "string", desc: "Corretora ou banco.", required: false
      param :notes, type: "string", desc: "Observação curta.", required: false

      def initialize(user:, updater: UseCase::Financial::Investment::UpdateInvestmentUseCase.new)
        super()
        @user    = user
        @updater = updater
      end

      def execute(id:, current_amount: nil, status: nil, institution: nil, notes: nil)
        safe_execute do
          attributes = {
            current_amount: current_amount,
            status:         whitelist(status, allowed: INVESTMENT_STATUSES),
            institution:    institution,
            notes:          notes
          }.compact

          investment = @updater.call(user: @user, id: id.to_s, attributes: attributes)
          {
            success:         true,
            investment_id:   investment.id,
            name:            investment.name,
            status:          investment.status,
            current_amount:  investment.current_amount.to_s,
            return_amount:   investment.return_amount.to_s,
            return_percent:  investment.return_percent
          }
        end
      end
    end
  end
end
