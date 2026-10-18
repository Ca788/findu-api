# frozen_string_literal: true

class UseCase::Chat::SelectAgentUseCase
  Result = Struct.new(:agent, :intent, :confidence, keyword_init: true)

  # Roteamento por LLM foi removido: cada turno extra de classificação
  # consumia cota e atrasava o primeiro token, e o DEFAULT já expõe as tools.
  # Um agente especializado só entra se a conversa tiver agent_id forçado.
  def call(text:, forced_agent: nil)
    if forced_agent
      agent = Llm::Agents::Registry.find(forced_agent) || Llm::Agents::Registry::DEFAULT
      return Result.new(agent: agent, intent: nil, confidence: nil)
    end

    Result.new(
      agent:      Llm::Agents::Registry::DEFAULT,
      intent:     "unknown",
      confidence: 0.0
    )
  end
end
