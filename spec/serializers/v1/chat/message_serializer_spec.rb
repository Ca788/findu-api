# frozen_string_literal: true

require "rails_helper"

RSpec.describe V1::Chat::MessageSerializer do
  let(:user)         { create(:user) }
  let(:conversation) { create(:chat_conversation, user: user) }
  let(:message)      { create(:chat_message, user: user, conversation: conversation) }

  def attach_png!(record)
    record.attachments.attach(
      io:           StringIO.new("fake-png"),
      filename:     "recibo.png",
      content_type: "image/png"
    )
  end

  def attach_wav!(record)
    record.audio.attach(
      io:           StringIO.new("fake-wav"),
      filename:     "nota.wav",
      content_type: "audio/wav"
    )
  end

  it "includes audio_url and attachments on the default list view" do
    attach_png!(message)
    attach_wav!(message)

    hash = described_class.render_as_hash(message.reload, view: :default)

    expect(hash[:attachments]).to contain_exactly(
      a_hash_including(
        filename:     "recibo.png",
        content_type: "image/png",
        url:          a_string_starting_with("/rails/active_storage/")
      )
    )
    expect(hash[:audio_url]).to start_with("/rails/active_storage/")
  end

  it "keeps payload out of the default view" do
    hash = described_class.render_as_hash(message, view: :default)

    expect(hash).not_to have_key(:payload)
    expect(hash).not_to have_key(:error)
  end
end
