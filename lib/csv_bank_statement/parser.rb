require 'bigdecimal'
require 'date'
require 'csv'
require 'acsv'

class CsvBankStatement
  class Parser
    class Transaction
      attr_reader :id, :counterparty, :counterparty_account, :counterparty_bank_code, :amount, :date, :variable_symbol,
        :specific_symbol, :constant_symbol, :note, :currency, :account, :account_identifier, :fee, :raw

      def initialize(id:, counterparty:, counterparty_account:, counterparty_bank_code:, amount:, date:, variable_symbol:, specific_symbol:, constant_symbol:, note:, currency:, account:, account_identifier:, raw:, fee:)
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
        @fee = fee
        @raw = raw
      end
    end

    RB_HEADER = ['Datum provedení', 'Datum zaúčtování', 'Číslo účtu', 'Název účtu', 'Kategorie transakce', 'Číslo protiúčtu', 'Název protiúčtu', 'Typ transakce', 'Zpráva', 'Poznámka']

    # MojeBanka Business -> Transakcni historie -> Stazeni ucetnich dat -> Volba formatu: CSV
    KB_BUSINESS_HEADER = ['Datum vytvoreni souboru', 'Cislo uctu', 'Mena uctu', 'IBAN', 'Nazev uctu', 'Vypis ze dne', 'Cislo vypisu', 'Predchozi vypis ze dne', 'Pocet polozek', 'Pocatecni zustatek']

    KB_PERSONAL_HEADER = ['MojeBanka, export transakční historie', 'Datum vytvoření souboru', nil, 'Číslo účtu', 'IBAN', 'Název účtu']
    PAYPAL_HEADER = ["Date", "Time", "Time Zone", "Description", "Currency", "Gross", "Fee", "Net", "Balance", "Transaction ID"]
    CSOB_PERSONAL_HEADER = ["číslo účtu", "datum zaúčtování", "částka", "měna", "zůstatek", "číslo účtu protiúčtu", "kód banky protiúčtu", "název účtu protiúčtu", "konstantní symbol", "variabilní symbol"]
    CS_BUSINESS_HEADER = ["Prefix", "Account number", "Start date of the period", "End date of the period", "Opening balance", "Final balance", "Debet (-)", "Credit"]
    UNICREDIT_BUSINESS_HEADER = ["Účet", "Částka", "Měna", "Datum zaúčtování", "Valuta", "Banka", "Název banky", "Název banky", "Číslo účtu", "Název účtu"]

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
      #TODO,HACK: Unfortunatelly it's hard to detect files between Windows-1250 and eg. Windows-1252. Windows-1250
      #  is a safer bet for us now
      encoding =
        if encoding.include?('windows')
          'Windows-1250'
        else
          encoding
        end

      @raw_data.force_encoding(encoding)
      in_utf = @raw_data.encode('UTF-8')
      separator = detect_separator(in_utf)
      csv = CSV.parse(in_utf, col_sep: separator)

      if csv.first[0..9] == RB_HEADER
        parse_rb_statement(csv)
      elsif csv.first[0..9] == KB_BUSINESS_HEADER
        parse_kb_business_statement(csv)
      elsif csv[0..5].map(&:first) == KB_PERSONAL_HEADER
        parse_kb_personal_statement(csv)
      elsif csv.first[0..9] == PAYPAL_HEADER
        parse_paypal_statement(csv)
      elsif csv[2][0..9] == CSOB_PERSONAL_HEADER
        parse_csob_personal_statement(csv)
      elsif csv[0..7].map(&:first) == CS_BUSINESS_HEADER
        parse_cs_business_statement(csv)
      elsif csv[2][0..9] == UNICREDIT_BUSINESS_HEADER
        parse_unicredit_business_statement(csv)
      else
        [false, []]
      end
    end

    private

    def parse_rb_statement(csv)
      txs = csv[1..-1]

      transactions = txs.flat_map do |tx|
        note = [tx[4], tx[6], tx[7], tx[8], tx[9], tx[19], tx[20], tx[21]].select { !_1.nil? && !_1.empty? }.join(', ')
        counterparty = tx[5]
        counterparty_account, counterparty_bank_code = (counterparty || '').split('/')
        fee = amount(tx[17])

        attrs = {
          id: tx[18],
          account: tx[2],
          account_identifier: tx[3],
          counterparty: counterparty,
          counterparty_account: counterparty_account,
          counterparty_bank_code: counterparty_bank_code,
          amount: amount(tx[13]),
          fee: fee,
          date: Date.parse(tx[1]),
          variable_symbol: tx[10],
          specific_symbol: tx[12],
          constant_symbol: tx[11],
          note: note,
          currency: tx[14],
          raw: tx
        }

        Transaction.new(**attrs)
      end

      [true, transactions]
    end

    def parse_kb_business_statement(csv)
      txs = csv[1..-1]

      transactions = txs.map do |tx|
        note = [tx[23], tx[24], tx[17], tx[25], tx[26]].select { !_1.nil? && !_1.empty? }.join(', ')
        counterparty_account = tx[15]
        counterparty_bank_code = tx[16].rjust(4, '0')
        counterparty = "#{counterparty_account}/#{counterparty_bank_code}"

        attrs = {
          id: tx[22],
          account: tx[1],
          account_identifier: tx[4],
          counterparty: counterparty,
          counterparty_account: counterparty_account,
          counterparty_bank_code: counterparty_bank_code,
          amount: amount(tx[18]),
          fee: 0,
          date: Date.parse(tx[13]),
          variable_symbol: tx[19],
          specific_symbol: tx[21],
          constant_symbol: tx[20],
          note: note,
          currency: tx[2],
          raw: tx
        }

        Transaction.new(**attrs)
      end

      [true, transactions]
    end

    def parse_kb_personal_statement(csv)
      txs = csv[18..-1]

      transactions = txs.map do |tx|
        account, currency = csv[3][1].strip.split(' ')

        note = [tx[3], tx[12], tx[13], tx[14], tx[15], tx[16], tx[17], tx[18]].select { !_1.nil? }.map(&:strip).select { !_1.empty? }.join(', ')

        attrs = {
          id: tx[11],
          account: "#{account}/0100",
          account_identifier: csv[5][1],
          counterparty: nil,
          counterparty_account: nil,
          counterparty_bank_code: nil,
          amount: amount(tx[4]),
          fee: 0,
          date: Date.parse(tx[0]),
          variable_symbol: tx[8],
          specific_symbol: tx[9],
          constant_symbol: tx[10],
          note: note,
          currency: currency,
          raw: tx
        }

        counterparty = tx[2]
        if counterparty
          counterparty_account, counterparty_bank_code =
            if !counterparty.empty?
              counterparty.split('/')
            else
              [nil, nil]
            end

          attrs[:counterparty] = counterparty
          attrs[:counterparty_account] = counterparty_account
          attrs[:counterparty_bank_code] = counterparty_bank_code
        end

        Transaction.new(**attrs)
      end

      [true, transactions]
    end

    def parse_paypal_statement(csv)
      txs = csv[1..-1]

      transactions = txs.flat_map do |row|
        gross = BigDecimal(row[5].delete(','))
        fee = BigDecimal(row[6].delete(','))

        note = [row[10], row[11], row[12], row[13], row[16], row[17]].select { !_1.nil? }.map(&:strip).select { !_1.empty? }.join(', ')

        attrs = {
          id: row[9],
          account: nil,
          account_identifier: nil,
          counterparty: nil,
          counterparty_account: nil,
          counterparty_bank_code: nil,
          amount: gross,
          fee: fee,
          date: Date.strptime(row[0], '%m/%d/%Y'),
          variable_symbol: nil,
          specific_symbol: nil,
          constant_symbol: nil,
          note: note,
          currency: row[4],
          raw: row
        }

        Transaction.new(**attrs)
      end

      [true, transactions]
    end

    def parse_csob_personal_statement(csv)
      txs = csv[3..-1]

      transactions = txs.map do |row|
        counterparty_account = row[5]
        counterparty_bank_code = row[6].rjust(4, '0')

        note = [row[7], row[11], row[13]].select { !_1.nil? }.map(&:strip).select { !_1.empty? }.join(', ')

        attrs = {
          id: row[12],
          account: row[0],
          account_identifier: nil,
          counterparty: "#{counterparty_account}/#{counterparty_bank_code}",
          counterparty_account: counterparty_account,
          counterparty_bank_code: counterparty_bank_code,
          amount: BigDecimal(row[2].gsub(',', '')),
          fee: 0,
          date: Date.parse(row[1]),
          variable_symbol: row[9],
          specific_symbol: row[10],
          constant_symbol: row[8],
          note: note,
          currency: row[3],
          raw: row
        }

        Transaction.new(**attrs)
      end

      [true, transactions]
    end

    def parse_cs_business_statement(csv)
      txs = csv[11..-1]
      account = "#{csv[1][1]}/0800"

      transactions = txs.map do |row|
        note = [row[8], row[9], row[11], row[12], row[17]].select { !_1.nil? }.map(&:strip).select { !_1.empty? }.join(', ').gsub(/\s+/, ' ')

        attrs = {
          id: row[10],
          account: account,
          account_identifier: nil,
          counterparty: nil,
          counterparty_account: nil,
          counterparty_bank_code: nil,
          amount: BigDecimal(row[3].gsub(',', '.')),
          fee: 0,
          date: Date.strptime(row[13], '%Y/%m/%d'),
          variable_symbol: row[15],
          specific_symbol: row[7],
          constant_symbol: row[6],
          note: note,
          currency: nil,
          raw: row
        }

        counterparty_account_prefix = row[0]
        counterparty_account = row[1]
        counterparty_bank_code = row[2]&.rjust(4, '0')

        if counterparty_account
          full_account =
            if counterparty_account_prefix
              "#{counterparty_account_prefix}-#{counterparty_account}"
            else
              counterparty_account
            end

          attrs[:counterparty] = "#{full_account}/#{counterparty_bank_code}"
          attrs[:counterparty_account] = full_account
          attrs[:counterparty_bank_code] = counterparty_bank_code
        end

        Transaction.new(**attrs)
      end

      [true, transactions]
    end

    def parse_unicredit_business_statement(csv)
      txs = csv[3..-1]
      account = "#{csv[1][1]}/2700"

      transactions = txs.map do |row|
        note = [row[13], row[14], row[9], row[10], row[11], row[14], row[15], row[16]].select { !_1.nil? }.map(&:strip).select { !_1.empty? }.join(', ').gsub(/\s+/, ' ')

        counterparty_account = row[8]&.strip
        counterparty_bank_code =
          case row[5]
          when 'BACXCZPPXXX' then '2700'
          else row[5]&.strip
          end

        attrs = {
          id: row[23],
          account: account,
          account_identifier: nil,
          counterparty: "#{counterparty_account}/#{counterparty_bank_code}",
          counterparty_account: counterparty_account,
          counterparty_bank_code: counterparty_bank_code,
          amount: BigDecimal(row[1].gsub(',', '.')),
          fee: 0,
          date: Date.strptime(row[4], '%Y-%m-%d'),
          variable_symbol: row[20],
          specific_symbol: row[21],
          constant_symbol: row[19],
          note: note,
          currency: row[2],
          raw: row
        }

        Transaction.new(**attrs)
      end

      [true, transactions]
    end

    def amount(raw)
      BigDecimal(raw.gsub(' ', '').gsub(',', '.'))
    end

    def detect_separator(raw)
      lines = raw.lines
      20.times do |n|
        separator = ACSV::Detect.separator(lines[n])

        return separator if separator
      end
    end
  end
end
