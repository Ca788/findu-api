# frozen_string_literal: true

module Api
  module V1
    module Chat
      class MessagesController < Api::BaseController
        before_action :set_conversation

        def index
          messages = @conversation.messages
                                  .not_deleted
                                  .with_attached_audio
                                  .with_attached_attachments
                                  .order(created_at: :asc)
                                  .page(page_param)
                                  .per(per_page_param)

          render json: ApiResponseSerializer.render_data_array(
            messages,
            serializer:      ::V1::Chat::MessageSerializer,
            serializer_view: serializer_view_param(default: :default),
            pagination:      pagination_for(messages)
          ), status: :ok
        end

        def show
          message = @conversation.messages.not_deleted.find(params[:id])

          render json: ApiResponseSerializer.render(
            message,
            serializer:      ::V1::Chat::MessageSerializer,
            serializer_view: :extended
          ), status: :ok
        end

        def create
          message = UseCase::Chat::CreateMessageUseCase.new.call(
            conversation:      @conversation,
            user:              @user,
            body:              message_params[:body],
            audio:             message_params[:audio],
            attachments:       Array(message_params[:attachments]),
            client_message_id: message_params[:client_message_id]
          )

          render json: ApiResponseSerializer.render(
            message,
            serializer:      ::V1::Chat::MessageSerializer,
            serializer_view: :extended,
            message:         "Message queued for processing."
          ), status: :accepted
        end

        private

        def set_conversation
          @conversation = @user.chat_conversations.find(params[:conversation_id])
        end

        def message_params
          params.permit(:body, :audio, :client_message_id, attachments: [])
        end
      end
    end
  end
end
