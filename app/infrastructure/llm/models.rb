# frozen_string_literal: true

module Llm
  # Toda chamada usa um único modelo, o mais novo. Não existe cadeia: cair para
  # um modelo mais antigo no meio de uma falha escondia o erro e mudava a
  # qualidade da resposta sem ninguém perceber.
  module Models
    CURRENT = "gemini-3.8-flash"

    # Ids antigos continuam aqui porque existem conversas gravadas com eles.
    LABELS = {
      "gemini-3.8-flash"       => "Gemini 3.8 Flash",
      "gemini-3.5-flash"       => "Gemini 3.5 Flash",
      "gemini-3.1-flash-lite"  => "Gemini 3.1 Flash Lite",
      "gemini-3.1-pro-preview" => "Gemini 3.1 Pro"
    }.freeze

    module_function

    # @param [String] env_key
    # @return [String]
    def current(env_key = "CHAT_AGENT_MODEL")
      first_id(ENV[env_key]) ||
        first_id(ENV["GEMINI_MODEL"]) ||
        first_id(ENV["GEMINI_MODEL_CHAIN"]) ||
        CURRENT
    end

    # Sempre um único id. O formato de Array é mantido porque é o que os
    # chamadores recebem em `models:`.
    # @param [String] env_key
    # @return [Array<String>]
    def chain(env_key)
      [current(env_key)]
    end

    # @param [String] env_key
    # @return [Array<Hash>]
    def available(env_key = "CHAT_AGENT_MODEL")
      chain(env_key).map { |id| { id: id, name: label(id) } }
    end

    # A preferência gravada na conversa é ignorada: conversa antiga continua
    # respondendo, mas no modelo atual.
    # @param [String, nil] _preferred
    # @param [String] env_key
    # @return [Array<String>]
    def prefer(_preferred, env_key = "CHAT_AGENT_MODEL")
      chain(env_key)
    end

    # Ids aceitos em `chat_conversations.model_id`, incluindo os legados já
    # persistidos, para que conversa antiga não fique inválida.
    # @return [Array<String>]
    def known
      (LABELS.keys + [current]).uniq
    end

    # @param [String] id
    # @return [String]
    def label(id)
      LABELS[id] || id.tr("-", " ").split.map(&:capitalize).join(" ")
    end

    # Tolera variáveis que ainda estejam em CSV, usando só o primeiro id.
    # @param [String, nil] raw
    # @return [String, nil]
    def first_id(raw)
      raw.to_s.split(",").map(&:strip).reject(&:empty?).first
    end
  end
end
