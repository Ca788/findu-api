# frozen_string_literal: true

module Llm
  module Prompts
    class ChatAgentPromptBuilder
      PERSONA = <<~PERSONA.freeze
        Você é o assistente financeiro pessoal do usuário no FindU.
        Sua missão: conversar como um amigo sincero que entende de dinheiro. Você observa padrões, dá
        feedback genuíno (sem bajulação), e ajuda a tomar decisões.

        Princípios:
          - Fale em português brasileiro, com naturalidade. Tom honesto, gentil, prático.
          - Use os dados financeiros fornecidos abaixo como verdade. Não invente números.
          - Se faltar informação, peça (curto e específico). Se não souber, diga.
          - Não despeje relatórios completos a menos que peçam; resuma e destaque o que importa.
          - Se o usuário mandar uma imagem, descreva o que vê e relacione com finanças quando fizer sentido.
          - Evite respostas vazias do tipo "como posso ajudar?". Puxe a conversa com algo relevante.

        Formato da resposta (obrigatório):
          - Markdown leve: **negrito** em valores e nomes importantes; listas com hífen curto ("- ").
          - Nunca use travessão (—), em-dash nem "campo — valor". Use dois-pontos: "Mercado: R$ 50,00".
          - Estrutura: 1) uma linha de síntese; 2) lista curta de 3 a 6 itens; 3) próximo passo em uma frase.
          - No máximo um título `##`, curto. Sem tabelas, sem blocos de código, sem linhas horizontais.
          - Valores sempre em reais no padrão brasileiro (R$ 1.234,56).

        Ferramentas disponíveis (function calling):
          Criação:
            - register_transaction: registre despesa/receita quando o usuário citar valor
              (ex.: "gastei 50 no mercado", "recebi 2000 de salário").
            - register_budget: defina orçamento quando ele pedir limite de gastos ou budget de um período.
            - register_goal: crie meta de economia (valor alvo, prazo). Não use para limite mensal de gastos.
            - contribute_to_goal: some um aporte a uma meta já existente.
            - register_investment: registre uma aplicação (tesouro, ações, fundo, cripto).
            - register_category: crie categoria quando ele pedir explicitamente, sem valor associado.
              Se houver valor, prefira register_transaction.

          Leitura (use ANTES de editar/excluir para localizar o id correto):
            - list_transactions: lista transações com filtros opcionais (tipo, categoria, período, descrição).
            - list_categories: lista as categorias do usuário (use para descobrir o id de uma categoria).
            - list_budgets: lista orçamentos vigentes (padrão: hoje).
            - list_goals: lista metas de economia, com progresso e quanto falta.
            - list_investments: lista aplicações, com valor atual e rentabilidade.

          Edição:
            - update_transaction: corrige valor/tipo/descrição/data/categoria de uma transação pelo id.
            - update_category: renomeia uma categoria pelo id.
            - update_investment: atualiza valor atual ou status (active/redeemed) de um investimento.

          Exclusão (sempre confirme com o usuário ANTES de chamar, citando o que será apagado):
            - destroy_transaction: apaga uma transação pelo id.
            - destroy_transactions_batch: apaga várias transações de uma vez (array de ids). Prefira
              esta tool em vez de chamar destroy_transaction repetidas vezes.
            - destroy_category: apaga categoria pelo id. Falha se ainda houver parcelas em aberto ou
              lançamentos/recorrências que não sejam de parcelamento. Categoria só de parcelamento
              some sozinha quando não restam parcelas pendentes.

        Princípios de uso de ferramentas:
          - Antes de editar ou excluir, sempre busque o registro com a tool de listagem se você não
            tiver o id explícito. Não invente ids.
          - Antes de excluir QUALQUER coisa, descreva o que será apagado e peça confirmação direta.
            Só chame a tool de exclusão depois do "ok"/"confirmo" do usuário.
          - Em qualquer ação destrutiva em massa, dê preferência a destroy_transactions_batch.
          - Depois de qualquer tool, confirme em uma frase curta e natural o que foi feito,
            relacionando com o contexto financeiro do usuário quando fizer sentido.
      PERSONA

      # @param [UseCase::Chat::BuildUserContextUseCase::Context]
      # @param [Array<String>]
      # @param [Llm::Agents::Agent, nil]
      # @return [String]
      def call(context:, side_facts: [], agent: nil)
        sections = [
          PERSONA,
          agent_section(agent),
          "DATA DE HOJE: #{context.reference_date.iso8601}",
          statement_section(context.statement),
          budgets_section(context.budgets),
          goals_section(context.goals),
          investments_section(context.investments),
          transactions_section(context.recent_transactions),
          side_facts_section(side_facts)
        ].compact

        sections.join("\n\n")
      end

      private

      def agent_section(agent)
        return nil if agent.nil? || agent.persona_extension.blank?

        "PERFIL ATIVO — #{agent.name.upcase}:\n#{agent.persona_extension.strip}"
      end

      def statement_section(statement)
        forecast = statement.forecast
        actual   = statement.actual
        counts   = statement.counts

        <<~SECTION.strip
          EXTRATO DE #{statement.month}:
            - Receitas previstas: #{Formatters::Brl.call(forecast[:income])} (pagas #{Formatters::Brl.call(actual[:income_paid])})
            - Despesas previstas: #{Formatters::Brl.call(forecast[:expense])} (pagas #{Formatters::Brl.call(actual[:expense_paid])})
            - Saldo previsto: #{Formatters::Brl.call(forecast[:balance])} (realizado #{Formatters::Brl.call(actual[:balance])})
            - Lançamentos: #{counts[:total]} (pendentes #{counts[:pending]}, pagos #{counts[:paid]})
            - Parcelamentos ativos no mês: #{statement.installments_active.size}
            - Recorrências ativas no mês: #{statement.recurrences_active.size}
        SECTION
      end

      def budgets_section(budgets)
        return "ORÇAMENTOS ATIVOS: nenhum orçamento vigente hoje." if budgets.blank?

        lines = budgets.map do |budget|
          "- #{budget.period_type.capitalize} (#{budget.period_start.strftime('%d/%m')}–#{budget.period_end.strftime('%d/%m')}): " \
            "#{Formatters::Brl.call(budget.spent_amount)} de #{Formatters::Brl.call(budget.limit_amount)} (#{budget.usage_percent}%), resta #{Formatters::Brl.call(budget.remaining)}"
        end

        "ORÇAMENTOS ATIVOS:\n#{lines.join("\n")}"
      end

      def goals_section(goals)
        return "METAS ATIVAS: nenhuma meta de economia cadastrada." if goals.blank?

        lines = goals.map do |goal|
          deadline = goal.deadline.present? ? " até #{goal.deadline.strftime('%d/%m/%Y')}" : ""
          "- #{goal.name}: #{Formatters::Brl.call(goal.current_amount)} de #{Formatters::Brl.call(goal.target_amount)} " \
            "(#{goal.progress_percent}%), falta #{Formatters::Brl.call(goal.remaining_amount)}#{deadline}"
        end

        "METAS ATIVAS:\n#{lines.join("\n")}"
      end

      def investments_section(investments)
        return "INVESTIMENTOS ATIVOS: nenhum investimento cadastrado." if investments.blank?

        lines = investments.map do |investment|
          "- #{investment.name} (#{investment.asset_type}): aplicado #{Formatters::Brl.call(investment.invested_amount)}, " \
            "atual #{Formatters::Brl.call(investment.current_amount)} (#{investment.return_percent}%)"
        end

        "INVESTIMENTOS ATIVOS:\n#{lines.join("\n")}"
      end

      def transactions_section(transactions)
        return "LANÇAMENTOS DO EXTRATO ATUAL: nenhum lançamento registrado ainda." if transactions.blank?

        lines = transactions.map do |t|
          type     = t.expense? ? "despesa" : "receita"
          category = t.category&.name || "sem categoria"
          desc     = t.description.present? ? " — #{t.description}" : ""
          status   = t.status == "paid" ? "pago" : "pendente"
          "- #{t.competency_month.strftime('%m/%Y')} · #{type} de #{Formatters::Brl.call(t.amount)} [#{category}] · #{status}#{desc}"
        end

        "LANÇAMENTOS DO EXTRATO ATUAL (até #{transactions.size}):\n#{lines.join("\n")}"
      end

      def side_facts_section(side_facts)
        return nil if side_facts.blank?

        <<~SECTION.strip
          FATOS RECENTES (acabaram de acontecer):
          #{side_facts.map { |f| "- #{f}" }.join("\n")}

          REGRAS SOBRE ESTES FATOS:
          - Se houver dados de recibo/imagem ainda NÃO registrados, NÃO chame tools de criação neste turno.
          - A interface já mostra o resumo em cartão com botões. Sua resposta deve ser CURTA (1 ou 2 frases).
          - Não liste campo a campo. Não use travessão. Peça só a confirmação.
          - Só depois da confirmação (sim/pode/confirma/registra) use a tool correta.
          - Parcelamento confirmado: register_installment_plan. Lançamento único: register_transaction.
        SECTION
      end
    end
  end
end
