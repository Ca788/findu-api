# frozen_string_literal: true

module Chat
  module Replies
    module ActionBuilder
      module_function

      CREATING_TOOLS = %w[
        register_transaction
        register_installment_plan
        register_budget
        register_goal
        register_investment
        contribute_to_goal
      ].freeze

      Result = Struct.new(:actions, :card, keyword_init: true)

      # @param [Chat::Message] user_message
      # @param [Array<Hash>] tool_results
      # @return [Result]
      def call(user_message:, tool_results: [])
        results = Array(tool_results).map { |item| stringify(item) }
        created = results.select { |item| creating_success?(item) }

        if created.any?
          first = created.first
          return Result.new(
            actions: follow_up_actions(first),
            card:    card_from_tool(first)
          )
        end

        from_receipt(user_message)
      end

      def from_receipt(user_message)
        payload = stringify(user_message.payload)
        return empty unless payload["receipt_awaiting_confirmation"]

        candidate = Array(payload["receipt_candidates"]).find { |item| item.is_a?(Hash) }
        return empty if candidate.blank?

        data = stringify(candidate)
        Result.new(actions: receipt_actions(data), card: receipt_card(data))
      end

      def empty
        Result.new(actions: [], card: nil)
      end

      def creating_success?(item)
        CREATING_TOOLS.include?(item["name"].to_s) && success?(item["result"])
      end

      def success?(result)
        hash = stringify(result)
        hash["success"] == true
      end

      def stringify(value)
        return {} unless value.is_a?(Hash)

        value.deep_stringify_keys
      end

      def receipt_actions(candidate)
        primary =
          if installment?(candidate)
            action("register_installment", "Registrar parcelamento", "Confirma, registra esse parcelamento.")
          elsif income?(candidate)
            action("register_income", "Registrar receita", "Confirma, registra essa receita.")
          else
            action("register_expense", "Registrar despesa", "Confirma, registra essa despesa.")
          end

        [
          primary,
          action("dismiss_register", "Agora não", "Não registra.", variant: "secondary")
        ]
      end

      def receipt_card(candidate)
        installment = installment?(candidate)
        type_label  = income?(candidate) ? "Receita" : "Despesa"
        title       = installment ? "Parcelamento identificado" : "#{type_label} identificada"
        monthly     = money(candidate["monthly_amount"])
        total       = money(candidate["total_amount"]) || money(candidate["amount"])
        count       = candidate["total_installments"].to_i

        fields = []
        fields << field("Valor", total) if total
        if installment && count.positive? && monthly
          fields << field("Parcelas", "#{count}x de #{monthly}")
        end
        fields << field("Descrição", candidate["description"]) if candidate["description"].present?
        fields << field("Data", format_date(candidate["occurred_at"])) if candidate["occurred_at"].present?

        { "kind" => installment ? "installment" : "receipt", "title" => title, "fields" => fields }
      end

      def follow_up_actions(item)
        case item["name"].to_s
        when "register_transaction"
          [navigate("view_statement", "Ver no extrato", "/statements")]
        when "register_installment_plan"
          [navigate("view_installments", "Ver parcelas", "/installments")]
        when "register_budget"
          [navigate("view_budget", "Ver orçamento", "/budgets")]
        when "register_goal", "contribute_to_goal"
          [navigate("view_goals", "Ver metas", "/budgets")]
        when "register_investment"
          [navigate("view_investments", "Ver investimentos", "/investments")]
        else
          []
        end
      end

      def card_from_tool(item)
        result = stringify(item["result"])
        case item["name"].to_s
        when "register_transaction"
          type_label = result["type"].to_s == "income" ? "Receita" : "Despesa"
          {
            "kind"   => "transaction",
            "title"  => "#{type_label} registrada",
            "fields" => compact_fields(
              field("Valor", money(result["amount"])),
              field("Descrição", result["description"]),
              field("Categoria", result["category"])
            )
          }
        when "register_installment_plan"
          count = result["total_installments"].to_i
          monthly = money(result["monthly_amount"])
          {
            "kind"   => "installment",
            "title"  => "Parcelamento registrado",
            "fields" => compact_fields(
              field("Parcelas", (count.positive? && monthly) ? "#{count}x de #{monthly}" : nil),
              field("Descrição", result["description"])
            )
          }
        when "register_budget"
          {
            "kind"   => "budget",
            "title"  => "Orçamento criado",
            "fields" => compact_fields(
              field("Limite", money(result["limit_amount"])),
              field("Período", result["period_type"])
            )
          }
        when "register_goal", "contribute_to_goal"
          {
            "kind"   => "goal",
            "title"  => item["name"].to_s == "contribute_to_goal" ? "Aporte registrado" : "Meta criada",
            "fields" => compact_fields(
              field("Nome", result["name"]),
              field("Alvo", money(result["target_amount"])),
              field("Atual", money(result["current_amount"]))
            )
          }
        when "register_investment"
          {
            "kind"   => "investment",
            "title"  => "Investimento registrado",
            "fields" => compact_fields(
              field("Nome", result["name"]),
              field("Aplicado", money(result["invested_amount"])),
              field("Atual", money(result["current_amount"]))
            )
          }
        end
      end

      def installment?(candidate)
        candidate["is_installment"] && candidate["total_installments"].to_i > 1
      end

      def income?(candidate)
        candidate["transaction_type"].to_s == "income"
      end

      def action(id, label, message, variant: "primary")
        {
          "id"      => id,
          "label"   => label,
          "kind"    => "send_message",
          "message" => message,
          "variant" => variant
        }
      end

      def navigate(id, label, href)
        {
          "id"      => id,
          "label"   => label,
          "kind"    => "navigate",
          "href"    => href,
          "variant" => "primary"
        }
      end

      def field(label, value)
        return nil if value.blank?

        { "label" => label, "value" => value.to_s }
      end

      def compact_fields(*fields)
        fields.compact
      end

      def money(value)
        return nil if value.blank?

        Formatters::Brl.call(value)
      end

      def format_date(value)
        Time.zone.parse(value.to_s).strftime("%d/%m/%Y")
      rescue ArgumentError, TypeError
        value.to_s
      end
    end
  end
end
