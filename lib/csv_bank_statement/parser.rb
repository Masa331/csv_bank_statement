require 'bigdecimal'
require 'date'
require 'csv'
require 'acsv'

class CsvBankStatement
  class Parser
    class Transaction
      attr_reader :id, :counterparty, :counterparty_account, :counterparty_bank_code, :amount, :date, :variable_symbol,
        :specific_symbol, :constant_symbol, :note, :currency, :account, :account_identifier, :raw

      def initialize(id:, counterparty:, counterparty_account:, counterparty_bank_code:, amount:, date:, variable_symbol:, specific_symbol:, constant_symbol:, note:, currency:, account:, account_identifier:, raw:)
        @id = id
        @counterparty = counterparty
        @counterparty_account = counterparty_account
        @counterparty_bank_code = counterparty_bank_code
        @amount = amount
        @date = date
        @variable_symbol = variable_symbol
        @specific_symbol = specific_symbol
        @constant_symbol = constant_symbol
        @note = note
        @currency = currency
        @account = account
        @account_identifier = account_identifier
        @raw = raw
      end
    end

    RB_HEADER = ['Datum provedení', 'Datum zaúčtování', 'Číslo účtu', 'Název účtu', 'Kategorie transakce', 'Číslo protiúčtu', 'Název protiúčtu', 'Typ transakce', 'Zpráva', 'Poznámka']

    def self.call(raw_data)
      new(raw_data).parse
    end

    def initialize(raw_data)
      @raw_data = raw_data
    end

    def parse
      if @raw_data.nil? || @raw_data.empty?
        return [false, '', '', '', []]
      end

      encoding = ACSV::Detect.encoding(@raw_data)
      @raw_data.force_encoding(encoding)
      separator = ACSV::Detect.separator(@raw_data)

      csv = CSV.parse(@raw_data.encode('UTF-8'), col_sep: separator)

      if csv.first[0..9] == RB_HEADER
        parse_rb_statement(csv)
      else
        [false, []]
      end
    end

    private

    def parse_rb_statement(csv)
      txs = csv[1..-1]

      number = nil
      account = txs.first[2]
      transactions = []

      transactions = txs.flat_map do |tx|
        note = [tx[4], tx[6], tx[7], tx[8], tx[9], tx[19], tx[20], tx[21]].select { !_1.nil? && !_1.empty? }.join(', ')
        counterparty = tx[5]
        counterparty_account, counterparty_bank_code = (counterparty || '').split('/')
        fee = amount(tx[17])

        attrs = {
          id: tx[18],
          account: tx[2],
          account_identifier: txs.first[3],
          counterparty: counterparty,
          counterparty_account: counterparty_account,
          counterparty_bank_code: counterparty_bank_code,
          amount: amount(tx[13]),
          date: Date.parse(tx[1]),
          variable_symbol: tx[10],
          specific_symbol: tx[12],
          constant_symbol: tx[11],
          note: note,
          currency: tx[14],
          raw: tx
        }

        if fee.nonzero?
          fee_tx = attrs.dup
          fee_tx[:amount] = amount(tx[17])
          fee_tx[:note] = "Poplatek k #{fee_tx[:note]}"

          [Transaction.new(**attrs), Transaction.new(**fee_tx)]
        else
          Transaction.new(**attrs)
        end
      end

      [true, transactions]
    end

    def amount(raw)
      BigDecimal(raw.gsub(' ', '').gsub(',', '.'))
    end
  end
end
