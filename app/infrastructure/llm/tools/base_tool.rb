# frozen_string_literal: true

module Llm
  module Tools
    class BaseTool < RubyLLM::Tool
      TRANSACTION_TYPES        = %w[expense income].freeze
      BUDGET_PERIOD_TYPES      = %w[weekly monthly yearly custom].freeze
      GOAL_STATUSES            = %w[active achieved canceled].freeze
      INVESTMENT_ASSET_TYPES   = %w[fixed_income stocks funds treasury crypto other].freeze
      INVESTMENT_STATUSES      = %w[active redeemed].freeze

      protected

      def safe_execute(&block)
        block.call
      rescue ActiveRecord::RecordNotFound => e
        { success: false, error: not_found_message(e) }
      rescue ArgumentError => e
        { success: false, error: e.message }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      # @return [Time, nil]
      def parse_time(value)
        return nil if value.blank?

        Time.zone.parse(value.to_s)
      rescue ArgumentError
        nil
      end

      # @return [Date, nil]
      def parse_date(value)
        return nil if value.blank?

        Date.parse(value.to_s)
      rescue Date::Error, ArgumentError
        nil
      end

      # @param [String, nil] value
      # @param [Array<String>] allowed
      # @return [String, nil]
      def whitelist(value, allowed:, default: nil)
        return default if value.blank?

        v = value.to_s
        allowed.include?(v) ? v : default
      end

      def not_found_message(error)
        model = error.respond_to?(:model) ? error.model.to_s : nil
        case model
        when "Financial::Transaction" then "Transação não encontrada para este usuário."
        when "Financial::Category"    then "Categoria não encontrada para este usuário."
        when "Financial::Budget"      then "Orçamento não encontrado para este usuário."
        when "Financial::Goal"        then "Meta não encontrada para este usuário."
        when "Financial::Investment"  then "Investimento não encontrado para este usuário."
        else                               "Recurso não encontrado."
        end
      end
    end
  end
end
