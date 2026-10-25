# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chat::Conversation do
  let(:user) { create(:user) }

  describe "#broadcast_inbox!" do
    it "publishes the conversation to the owner's inbox channel" do
      conversation = create(:chat_conversation, user: user)

      expect(Chat::InboxChannel).to receive(:broadcast_to).with(
        user,
        hash_including(
          type:         "conversation.upserted",
          conversation: hash_including(id: conversation.id)
        )
      )

      conversation.broadcast_inbox!
    end
  end
end
