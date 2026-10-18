# frozen_string_literal: true

module Llm
  module Tools
    class RegisterInvestmentTool < BaseTool
      description "Registra um investimento (aplicação). " \
                  "Use quando o usuário falar em investir, aplicar, tesouro, ações, fundo ou cripto."

      param :name, type: "string", desc: "Nome do investimento (ex.: 'Tesouro Selic', 'IVVB11')."
      param :invested_amount, type: "number", desc: "Valor aplicado em reais."
      param :asset_type, type: "string", desc: "fixed_income, stocks, funds, treasury, crypto ou other.", required: false
      param :institution, type: "string", desc: "Corretora ou banco.", required: false
      param :current_amount, type: "number", desc: "Valor atual. Se omitido, usa o valor aplicado.", required: false
      param :invested_on, type: "string", desc: "Data da aplicação ISO 8601 (YYYY-MM-DD). Padrão: hoje.", required: false
      param :notes, type: "string", desc: "Observação curta.", required: false

      def initialize(user:, creator: UseCase::Financial::Investment::CreateInvestmentUseCase.new)
        super()
        @user    = user
        @creator = creator
      end

      def execute(name:, invested_amount:, asset_type: nil, institution: nil,
                  current_amount: nil, invested_on: nil, notes: nil)
        safe_execute do
          investment = @creator.call(
            user:       @user,
            attributes: {
              name:             name,
              invested_amount:  invested_amount,
              asset_type:       whitelist(asset_type, allowed: INVESTMENT_ASSET_TYPES, default: "other"),
              institution:      institution,
              current_amount:   current_amount,
              invested_on:      parse_date(invested_on) || Date.current,
              notes:            notes
            }
          )

          {
            success:         true,
            investment_id:   investment.id,
            name:            investment.name,
            asset_type:      investment.asset_type,
            invested_amount: investment.invested_amount.to_s,
            current_amount:  investment.current_amount.to_s,
            return_amount:   investment.return_amount.to_s,
            return_percent:  investment.return_percent
          }
        end
      end
    end
  end
end
