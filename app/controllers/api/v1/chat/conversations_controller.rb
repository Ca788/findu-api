# frozen_string_literal: true

module Api
  module V1
    module Chat
      class ConversationsController < Api::BaseController
        def index
          conversations = @user.chat_conversations
                               .active
                               .order(updated_at: :desc)
                               .page(page_param)
                               .per(per_page_param)

          render json: ApiResponseSerializer.render_data_array(
            conversations,
            serializer:      ::V1::Chat::ConversationSerializer,
            serializer_view: :default,
            pagination:      pagination_for(conversations)
          ), status: :ok
        end

        def show
          conversation = @user.chat_conversations.find(params[:id])

          render json: ApiResponseSerializer.render(
            conversation,
            serializer:      ::V1::Chat::ConversationSerializer,
            serializer_view: :extended
          ), status: :ok
        end

        def create
          conversation = @user.chat_conversations.create!(conversation_params.to_h.symbolize_keys)
          conversation.broadcast_inbox!

          render json: ApiResponseSerializer.render(
            conversation,
            serializer:      ::V1::Chat::ConversationSerializer,
            serializer_view: :default,
            message:         "Conversation created."
          ), status: :created
        end

        def update
          conversation = @user.chat_conversations.find(params[:id])
          conversation.update!(conversation_params.to_h.symbolize_keys)
          conversation.broadcast_inbox!

          render json: ApiResponseSerializer.render(
            conversation,
            serializer:      ::V1::Chat::ConversationSerializer,
            serializer_view: :default,
            message:         "Conversation updated."
          ), status: :ok
        end

        def destroy
          conversation = @user.chat_conversations.find(params[:id])
          unless conversation.archived?
            conversation.archive!
            conversation.broadcast_inbox!("conversation.archived")
          end

          render json: ApiResponseSerializer.render(
            {},
            message: "Conversation archived."
          ), status: :ok
        end

        private

        def conversation_params
          params.permit(*::Chat::Conversation::PERMITTED_ATTRIBUTES)
        end
      end
    end
  end
end
