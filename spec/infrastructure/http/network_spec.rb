# frozen_string_literal: true

require "rails_helper"

RSpec.describe Http::Network do
  describe ".wrap" do
    it "returns the block value when nothing fails" do
      expect(described_class.wrap { :ok }).to eq(:ok)
    end

    it "wraps known network errors and keeps the cause" do
      expect { described_class.wrap { raise Net::ReadTimeout } }
        .to raise_error(described_class::Error, /ReadTimeout/) do |error|
          expect(error.cause).to be_a(Net::ReadTimeout)
        end
    end

    it "lets unrelated errors through" do
      expect { described_class.wrap { raise ArgumentError, "bad" } }
        .to raise_error(ArgumentError, "bad")
    end

    it "does not treat generic IO errors as network failures" do
      expect { described_class.wrap { raise IOError, "closed" } }
        .to raise_error(IOError, "closed")
      expect { described_class.wrap { raise EOFError } }
        .to raise_error(EOFError)
    end
  end

  describe ".start" do
    it "opens the connection with timeouts" do
      uri = URI("https://fcm.googleapis.com/v1")
      captured = nil

      allow(Net::HTTP).to receive(:start) do |host, port, **opts, &block|
        captured = { host: host, port: port, **opts }
        block.call(instance_double(Net::HTTP))
      end

      described_class.start(uri) { |_http| :done }

      expect(captured).to include(
        host:         "fcm.googleapis.com",
        port:         443,
        use_ssl:      true,
        open_timeout: described_class::OPEN_TIMEOUT,
        read_timeout: described_class::READ_TIMEOUT
      )
    end
  end
end
