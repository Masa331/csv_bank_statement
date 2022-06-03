# frozen_string_literal: true

require_relative 'csv_bank_statement/parser'

class CsvBankStatement
  class Error < StandardError; end

  attr_reader :transactions

  def initialize(data)
    @known, @transactions = data
  end

  def self.parse(raw_data)
    self.new(Parser.call(raw_data))
  end

  def known?
    @known
  end
end
