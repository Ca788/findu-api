# frozen_string_literal: true

require "rails_helper"

RSpec.describe Messaging::ProviderFactory do
  describe ".build_inbound" do
    it "returns the provider when it implements the inbound contract" do
      allow(described_class).to receive(:build).and_return(
        instance_double(Messaging::Twilio::Provider, parse: nil, valid_signature?: true)
      )

      expect { described_class.build_inbound }.not_to raise_error
    end

    it "names the missing methods when the provider cannot receive messages" do
      allow(described_class).to receive(:build).and_return(
        Messaging::WhatsappCloud::Provider.allocate
      )

      expect { described_class.build_inbound }.to raise_error(
        Messaging::ConfigurationError, /does not implement parse, valid_signature\?/
      )
    end
  end
end
