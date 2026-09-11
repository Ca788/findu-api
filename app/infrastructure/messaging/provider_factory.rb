# frozen_string_literal: true

module Messaging
  class ConfigurationError < StandardError; end

  class ProviderFactory
    SUPPORTED_PROVIDERS = %w[twilio whatsapp_cloud].freeze
    INBOUND_CONTRACT    = %i[parse valid_signature?].freeze

    # @return [Messaging::Twilio::Provider, Messaging::WhatsappCloud::Provider]
    def self.build
      provider = ENV["MESSAGING_PROVIDER"].to_s.strip.downcase

      raise ConfigurationError, "MESSAGING_PROVIDER is not configured" if provider.empty?

      case provider
      when "twilio"          then twilio
      when "whatsapp_cloud"  then whatsapp_cloud
      else
        raise ConfigurationError,
              "Unsupported messaging provider: #{provider.inspect}. Supported: #{SUPPORTED_PROVIDERS.join(', ')}"
      end
    end

    # @return [Messaging::Twilio::Provider]
    def self.build_inbound
      provider = build
      missing  = INBOUND_CONTRACT.reject { |method| provider.respond_to?(method) }
      return provider if missing.empty?

      raise ConfigurationError,
            "MESSAGING_PROVIDER=#{ENV['MESSAGING_PROVIDER']} cannot receive messages: " \
            "#{provider.class} does not implement #{missing.join(', ')}."
    end

    # Outbound receipts prefer Cloud API when configured, so the PDF is uploaded
    # as bytes instead of a signed URL that Twilio cannot fetch.
    # @return [Messaging::Twilio::Provider, Messaging::WhatsappCloud::Provider]
    def self.build_outbound
      cloud_configured? ? whatsapp_cloud : build
    end

    def self.twilio
      Twilio::Provider.new(
        credentials: Twilio::Provider::Credentials.new(
          account_sid:  ENV.fetch("TWILIO_ACCOUNT_SID"),
          auth_token:   ENV.fetch("TWILIO_AUTH_TOKEN"),
          phone_number: ENV.fetch("TWILIO_PHONE_NUMBER")
        )
      )
    end

    def self.whatsapp_cloud
      WhatsappCloud::Provider.new(
        credentials: WhatsappCloud::Provider::Credentials.new(
          access_token:    ENV.fetch("WHATSAPP_ACCESS_TOKEN"),
          phone_number_id: ENV.fetch("WHATSAPP_PHONE_NUMBER_ID"),
          graph_version:   ENV.fetch("WHATSAPP_GRAPH_VERSION", "v21.0")
        )
      )
    end

    def self.cloud_configured?
      ENV["WHATSAPP_ACCESS_TOKEN"].to_s.present? && ENV["WHATSAPP_PHONE_NUMBER_ID"].to_s.present?
    end

    private_class_method :twilio, :whatsapp_cloud, :cloud_configured?
  end
end
