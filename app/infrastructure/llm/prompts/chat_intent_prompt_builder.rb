# frozen_string_literal: true

module Llm
  module Prompts
    class ChatIntentPromptBuilder
      # @param [String] text
      # @return [String]
      def call(text:)
        <<~PROMPT
          Você é um classificador de intenções para um assistente financeiro pessoal em português.
          Classifique a mensagem do usuário em UMA das categorias abaixo.

          Categorias:
            - create_transaction: registrar uma despesa ou receita única. Inclui formas coloquiais ("gastei", "recebi"), imperativas ("registra", "cria", "adiciona") e descritivas ("uma transação de X").
                Exemplos:
                  * "gastei 50 no mercado"
                  * "recebi 2000 de salário"
                  * "paguei 100 de luz"
                  * "criar transação de 50 reais"
                  * "cria uma transação de 150"
                  * "criei uma transação de 200 no Uber"
                  * "registra uma despesa de 80 reais"
                  * "adiciona um gasto de 30 com lanche"
                  * "uma transação de 150 reais, categoria mercado"
                Esses são create_transaction MESMO quando a frase também menciona criar/associar categoria, contanto que tenha um valor monetário.
            - create_budget: definir um limite de gastos para um período (semanal/mensal/anual). Geralmente cita "orçamento", "limite", "budget" + valor + período. NÃO use para meta de juntar dinheiro.
                Exemplos: "quero um orçamento de 2000 por mês", "limite de 500 por semana para alimentação", "criar budget mensal de 3000".
            - create_goal: criar uma meta de economia (juntar um valor até uma data). Cita "meta", "objetivo", "juntar", "guardar", "reserva".
                Exemplos: "quero uma meta de 10000 para a viagem", "juntar 5000 até dezembro", "criar reserva de emergência de 8000".
            - create_investment: registrar uma aplicação financeira. Cita "investir", "apliquei", "tesouro", "ações", "fundo", "cripto".
                Exemplos: "investi 2000 no tesouro selic", "apliquei 500 em IVVB11", "comprei bitcoin".
            - create_category: criar SOMENTE uma categoria, SEM valor monetário envolvido. Se houver valor, é create_transaction.
                Exemplos: "criar categoria mercado", "adicionar categoria saúde", "nova categoria transporte".
            - create_installment: registrar uma compra parcelada (precisa explicitar número de parcelas, "em X vezes", "Xx").
                Exemplos: "comprei celular 3000 em 10 vezes", "parcelei o sofá em 12x de 200".
            - query_balance: perguntar sobre totais, resumos, soma de gastos/receitas.
                Exemplos: "quanto gastei esse mês?", "qual meu resumo?", "total de receitas".
            - query_budget: perguntar quanto ainda pode gastar do orçamento.
                Exemplos: "quanto posso gastar?", "ainda tenho quanto no orçamento?".
            - query_goal: perguntar o progresso de uma meta de economia.
                Exemplos: "como está minha meta da viagem?", "quanto falta juntar?", "minhas metas".
            - query_investment: perguntar da carteira, aplicações ou rentabilidade.
                Exemplos: "como estão meus investimentos?", "quanto rendeu o tesouro?", "minha carteira".
            - delete_transaction: pedir para apagar/remover/excluir uma ou várias transações,
                limpar histórico, remover duplicatas. Pode citar "apaga", "exclui", "remove",
                "limpa", "deleta".
                Exemplos:
                  * "apaga aquele gasto de 50 no mercado"
                  * "remove a transação de ontem"
                  * "limpa as duplicadas de uber"
                  * "exclui todas as transações de teste"
                  * "deleta o lançamento errado de 200"
            - unknown: nada acima se aplica.

          Mensagem do usuário: "#{text}"

          Retorne o intent e uma confidence de 0.0 a 1.0.
          Se a mensagem for ambígua, escolha unknown.
        PROMPT
      end
    end
  end
end
