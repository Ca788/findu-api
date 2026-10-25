# frozen_string_literal: true

# == Schema Information
#
# Table name: chat_conversations
#
#  id          :uuid             not null, primary key
#  archived_at :datetime
#  title       :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  agent_id    :string
#  model_id    :string
#  user_id     :uuid             not null
#
# Indexes
#
#  index_chat_conversations_on_agent_id  (agent_id)
#  index_chat_conversations_on_model_id  (model_id)
#  index_chat_conversations_on_user_id   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
module Chat
  class Conversation < ApplicationRecord
    self.table_name = "chat_conversations"

    PERMITTED_ATTRIBUTES = %i[title agent_id model_id].freeze

    belongs_to :user
    has_many :messages,
             class_name: "Chat::Message",
             foreign_key: :conversation_id,
             dependent: :destroy

    scope :active, -> { where(archived_at: nil) }

    validates :agent_id,
              inclusion: { in: ->(_) { Llm::Agents::Registry::ALL.map { |a| a.id.to_s } } },
              allow_nil: true

    validates :model_id,
              inclusion: { in: ->(_) { Llm::Models.known } },
              allow_nil: true

    def archived?
      archived_at.present?
    end

    def archive!
      update!(archived_at: Time.current)
    end

    # Broadcasts a conversation snapshot to every session of the owner.
    # @param [String] type
    # @return [void]
    def broadcast_inbox!(type = "conversation.upserted")
      Chat::InboxChannel.broadcast_to(
        user,
        type:         type,
        conversation: ::V1::Chat::ConversationSerializer.render_as_hash(self, view: :default)
      )
    end

    # Broadcasts a message snapshot to subscribers of this conversation channel.
    # @param [Chat::Message] message
    # @return [void]
    def broadcast_message!(message)
      preload_attachments(message)
      payload = ::V1::Chat::MessageSerializer.render_as_hash(message, view: :extended)
      Chat::ConversationChannel.broadcast_to(
        self,
        type:    "message.upserted",
        message: payload
      )
    end

    # Broadcasts an incremental text chunk for an in-flight message.
    # @param [String] message_id
    # @param [String] delta  the newly produced text since the last broadcast
    # @return [void]
    def broadcast_delta!(message_id, delta)
      Chat::ConversationChannel.broadcast_to(
        self,
        type:    "message.delta",
        message: { id: message_id, delta: delta }
      )
    end

    private

    # @param [Chat::Message] message
    # @return [void]
    def preload_attachments(message)
      ActiveRecord::Associations::Preloader.new(
        records:      [message],
        associations: [{ audio_attachment: :blob }, { attachments_attachments: :blob }]
      ).call
    end
  end
end
