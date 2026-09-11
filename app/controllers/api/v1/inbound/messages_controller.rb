# frozen_string_literal: true

module Api
  module V1
    module Inbound
      class MessagesController < ActionController::API
        include ExceptionHandler

        before_action :validate_signature

        def create
          message = messaging_provider.parse(params)
          UseCase::Messaging::ProcessInboundMessageUseCase.new(provider: messaging_provider).call(message: message)
          head :ok
        end

        private

        def messaging_provider
          Messaging::ProviderFactory.build_inbound
        end

        def validate_signature
          return if messaging_provider.valid_signature?(request, request.request_parameters)

          render json: ApiResponseSerializer.error(
            ErrorMapper::ERRORS[:unauthorized]
          ), status: :unauthorized
        end
      end
    end
  end
end
