# frozen_string_literal: true

require "net/http"
require "openssl"

module Http
  module Network
    class Error < StandardError; end

    ERRORS = [
      Net::OpenTimeout,
      Net::ReadTimeout,
      SocketError,
      Errno::ECONNRESET,
      Errno::ECONNREFUSED,
      Errno::ETIMEDOUT,
      Errno::EHOSTUNREACH,
      OpenSSL::SSL::SSLError
    ].freeze

    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10

    def self.wrap
      yield
    rescue *ERRORS => e
      raise Error, "network #{e.class}: #{e.message}", cause: e
    end

    def self.start(uri, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT,
                   use_ssl: uri.scheme != "http", &block)
      wrap do
        Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl:      use_ssl,
          open_timeout: open_timeout,
          read_timeout: read_timeout,
          &block
        )
      end
    end
  end
end
