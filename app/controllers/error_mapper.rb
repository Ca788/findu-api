# frozen_string_literal: true

module ErrorMapper
  class Error
    attr_reader :code, :message

    def initialize(code, message)
      @code = code
      @message = message
    end

    def title
      @message
    end

    def description
      nil
    end
  end

  ERRORS = {
    unknown_error: Error.new(500, "Unknown Error"),
    record_not_found: Error.new(404, "Record Not Found"),
    record_invalid: Error.new(1003, "Validation failed"),
    unauthorized: Error.new(1001, "Invalid credentials"),
    missing_parameter: Error.new(1002, "Missing parameter"),
    too_many_requests: Error.new(1004, "Too many requests")
  }.freeze

  ERRORS.each do |key, error|
    define_singleton_method(key) { error }
  end

  def self.unknown_error
    Error.new(500, "Unknown Error")
  end

  # @param [String, nil] model_name eg. "Financial::Transaction"
  # @return [String]
  def self.record_not_found_message_for(model_name)
    return record_not_found.message if model_name.blank?

    "#{model_name.demodulize.titleize} not found"
  end
end
