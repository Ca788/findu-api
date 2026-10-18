# frozen_string_literal: true

module Llm
  module Agents
    module Registry
      module_function

      DEFAULT = Agent.new(
        id:                :default,
        name:              "Generalista",
        persona_extension: nil,
        tool_classes:      [
          Llm::Tools::RegisterTransactionTool,
          Llm::Tools::RegisterInstallmentPlanTool,
          Llm::Tools::RegisterBudgetTool,
          Llm::Tools::RegisterGoalTool,
          Llm::Tools::ContributeToGoalTool,
          Llm::Tools::RegisterInvestmentTool,
          Llm::Tools::UpdateInvestmentTool,
          Llm::Tools::RegisterCategoryTool,
          Llm::Tools::ListTransactionsTool,
          Llm::Tools::ListCategoriesTool,
          Llm::Tools::ListBudgetsTool,
          Llm::Tools::ListGoalsTool,
          Llm::Tools::ListInvestmentsTool,
          Llm::Tools::UpdateTransactionTool,
          Llm::Tools::DestroyTransactionTool,
          Llm::Tools::DestroyTransactionsBatchTool,
          Llm::Tools::UpdateCategoryTool,
          Llm::Tools::DestroyCategoryTool
        ]
      )

      ANALYST = Agent.new(
        id:                :analyst,
        name:              "Analista",
        persona_extension: <<~EXT.freeze,
          Modo: ANALISTA (somente leitura).
          Você só pode CONSULTAR dados — não registra, não edita e não exclui nada.
          Foque em interpretar números, identificar padrões, comparar períodos e dar
          recomendações curtas e objetivas. Se o usuário pedir uma ação destrutiva
          ou de criação, diga que neste modo você só investiga e sugira que ele
          repita o pedido em outro momento.
        EXT
        tool_classes:      [
          Llm::Tools::ListTransactionsTool,
          Llm::Tools::ListCategoriesTool,
          Llm::Tools::ListBudgetsTool,
          Llm::Tools::ListGoalsTool,
          Llm::Tools::ListInvestmentsTool
        ]
      )

      LAUNCHER = Agent.new(
        id:                :launcher,
        name:              "Lançador",
        persona_extension: <<~EXT.freeze,
          Modo: LANÇADOR (registro rápido).
          Seu foco é registrar e ajustar dados financeiros com o mínimo de fricção.
          Quando os dados já estiverem claros e o usuário pedir para lançar, use as tools.
          Se houver extração de recibo aguardando confirmação (ver FATOS RECENTES),
          NÃO registre até o usuário confirmar. Para compras em N vezes, use
          register_installment_plan (nunca register_transaction).
          Confirme em uma frase curta depois de qualquer tool.
        EXT
        tool_classes:      [
          Llm::Tools::RegisterTransactionTool,
          Llm::Tools::RegisterInstallmentPlanTool,
          Llm::Tools::RegisterBudgetTool,
          Llm::Tools::RegisterGoalTool,
          Llm::Tools::ContributeToGoalTool,
          Llm::Tools::RegisterInvestmentTool,
          Llm::Tools::UpdateInvestmentTool,
          Llm::Tools::RegisterCategoryTool,
          Llm::Tools::UpdateTransactionTool,
          Llm::Tools::UpdateCategoryTool,
          Llm::Tools::ListCategoriesTool,
          Llm::Tools::ListTransactionsTool,
          Llm::Tools::ListGoalsTool,
          Llm::Tools::ListInvestmentsTool
        ]
      )

      CLEANER = Agent.new(
        id:                :cleaner,
        name:              "Faxineiro",
        persona_extension: <<~EXT.freeze,
          Modo: FAXINEIRO (limpeza e reorganização).
          Seu foco é localizar e remover transações/categorias incorretas ou duplicadas.
          Sempre liste antes de excluir, mostre o que será apagado e peça confirmação
          explícita do usuário ANTES de chamar qualquer destroy. Para remover várias
          de uma vez, prefira destroy_transactions_batch.
        EXT
        tool_classes:      [
          Llm::Tools::ListTransactionsTool,
          Llm::Tools::ListCategoriesTool,
          Llm::Tools::DestroyTransactionTool,
          Llm::Tools::DestroyTransactionsBatchTool,
          Llm::Tools::DestroyCategoryTool
        ]
      )

      INTENT_MAP = {
        "create_transaction" => LAUNCHER,
        "create_budget"      => LAUNCHER,
        "create_goal"        => LAUNCHER,
        "create_investment"  => LAUNCHER,
        "create_category"    => LAUNCHER,
        "create_installment" => LAUNCHER,
        "query_balance"      => ANALYST,
        "query_budget"       => ANALYST,
        "query_goal"         => ANALYST,
        "query_investment"   => ANALYST,
        "delete_transaction" => CLEANER
      }.freeze

      ALL = [DEFAULT, ANALYST, LAUNCHER, CLEANER].freeze

      # @param [String, Symbol, nil]
      # @return [Agent]
      def for_intent(intent)
        INTENT_MAP.fetch(intent.to_s, DEFAULT)
      end

      # @param [Symbol, String]
      # @return [Agent, nil]
      def find(id)
        ALL.find { |a| a.id.to_s == id.to_s }
      end
    end
  end
end
