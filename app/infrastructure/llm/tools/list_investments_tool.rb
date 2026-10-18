# frozen_string_literal: true

module Llm
  module Tools
    class ListInvestmentsTool < BaseTool
      description "Lista os investimentos do usuário, com valor aplicado, valor atual e rentabilidade. " \
                  "Use quando ele pedir a carteira, aplicações ou rendimento."

      param :status, type: "string", desc: "'active' ou 'redeemed'. Se omitido, lista todos.", required: false
      param :asset_type, type: "string", desc: "fixed_income, stocks, funds, treasury, crypto ou other.", required: false

      def initialize(user:, lister: UseCase::Financial::Investment::ListInvestmentsUseCase.new)
        super()
        @user   = user
        @lister = lister
      end

      def execute(status: nil, asset_type: nil)
        safe_execute do
          investments = @lister.call(
            user:       @user,
            status:     whitelist(status, allowed: INVESTMENT_STATUSES),
            asset_type: whitelist(asset_type, allowed: INVESTMENT_ASSET_TYPES)
          )

          {
            success:     true,
            count:       investments.size,
            investments: investments.map { |investment| serialize(investment) }
          }
        end
      end

      private

      def serialize(investment)
        {
          id:              investment.id,
          name:            investment.name,
          asset_type:      investment.asset_type,
          institution:     investment.institution,
          status:          investment.status,
          invested_amount: investment.invested_amount.to_s,
          current_amount:  investment.current_amount.to_s,
          return_amount:   investment.return_amount.to_s,
          return_percent:  investment.return_percent,
          invested_on:     investment.invested_on&.iso8601
        }
      end
    end
  end
end
