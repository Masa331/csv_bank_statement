# frozen_string_literal: true

require "test_helper"
require "pry"

class TestCsvBankStatement < Minitest::Test
  def test_version
    assert_equal 1, 1
  end

  def test_unknown_file
    data = File.read('./test/files/unknown_bank_statement.csv')
    statement = CsvBankStatement.parse(data)

    refute statement.known?
  end

  def test_non_csv_file
    data = File.read('./test/files/non_csv_file.txt')
    statement = CsvBankStatement.parse(data)

    refute statement.known?
  end

  def test_rb_statement
    data = File.read('./test/files/rb_statement.csv')
    statement = CsvBankStatement.parse(data)

    assert statement.known?

    payment = statement.transactions.first
    assert_equal '296485675/5500', payment.counterparty
    assert_equal '296485675', payment.counterparty_account
    assert_equal '5500', payment.counterparty_bank_code
    assert_equal '72415442', payment.id
    assert_equal BigDecimal('-1815.05'), payment.amount
    assert_equal '202106056', payment.variable_symbol
    assert_nil payment.specific_symbol
    assert_nil payment.constant_symbol
    assert_equal Date.parse('31.05.2022'), payment.date
    assert_equal 'Platba, Odchozí okamžitá úhrada, PRODEJNÍ SLUZBY ZA KVETEN 1995', payment.note
    assert_equal 'CZK', payment.currency
    assert_equal '210291002/5500', payment.account
    assert_equal 'Foobar s.r.o.', payment.account_identifier

    payment = statement.transactions[2]
    assert_equal BigDecimal('-4025.3'), payment.amount
    assert_equal 'Platba kartou, Platba kartou, CS MARMAN ORLÍK; ORLÍK; CZE, CS MARMAN ORLÍK; ORLÍK; CZE, ČS MarMan, Orlík nad Vltavou', payment.note
    assert_equal '1178', payment.constant_symbol
    assert_equal '33', payment.specific_symbol

    fee_tx = statement.transactions[3]
    assert_equal BigDecimal('29'), fee_tx.amount
    assert_equal 'Poplatek k Platba kartou, Platba kartou, CS MARMAN ORLÍK; ORLÍK; CZE, CS MARMAN ORLÍK; ORLÍK; CZE, ČS MarMan, Orlík nad Vltavou', fee_tx.note
  end

  def test_kb_business_statement
    data = File.read('./test/files/kb_business_statement.csv')
    statement = CsvBankStatement.parse(data)

    assert statement.known?

    payment = statement.transactions.first
    assert_equal '1152992080267/0100', payment.counterparty
    assert_equal '1152992080267', payment.counterparty_account
    assert_equal '0100', payment.counterparty_bank_code
    assert_equal '000-31052022 005-005-001527910', payment.id
    assert_equal BigDecimal('6780'), payment.amount
    assert_equal '9', payment.variable_symbol
    assert_equal '0', payment.specific_symbol
    assert_equal '498', payment.constant_symbol
    assert_equal Date.parse('31.05.2022'), payment.date
    assert_equal 'Planovana splatka uveru/uroku, SPLATKA JISTINY, DANMAR S.R.O., Z    CK-0001158192180267, neco', payment.note
    assert_equal 'CZK', payment.currency
    assert_equal '51-3819161607', payment.account
    assert_equal 'Foobar s.r.o.', payment.account_identifier
  end

  def test_kb_personal_statement
    data = File.read('./test/files/kb_personal_statement.csv')
    statement = CsvBankStatement.parse(data)

    assert statement.known?

    assert_equal 3, statement.transactions.size

    payment = statement.transactions.first

    assert_equal '2727/2700', payment.counterparty
    assert_equal '2727', payment.counterparty_account
    assert_equal '2700', payment.counterparty_bank_code
    assert_equal '001-30062022 1602 602023 874281', payment.id
    assert_equal BigDecimal('-4055'), payment.amount
    assert_equal '766250273', payment.variable_symbol
    assert_equal '0', payment.specific_symbol
    assert_equal '0', payment.constant_symbol
    assert_equal Date.parse('30.06.2022'), payment.date
    assert_equal 'Platba na vrub vašeho účtu', payment.note
    assert_equal 'CZK', payment.currency
    assert_equal '35-1843350247/0100', payment.account
    assert_equal 'KALMAJEK PETR', payment.account_identifier

    payment = statement.transactions[1]
    assert_equal 'PLATEBNÍ KARTY VISA CZK, Mobilní platba, 20220630 PLATEBNÍ KARTY, SMISENE ZB. PISKACKOV, SOBEKURY 42                CZ   45, 4779 75** **** 8792        VISA, 28.06.2022               323,00 CZK', payment.note
    assert_equal BigDecimal('323'), payment.amount
  end

  def test_paypal_statement
    data = File.read('./test/files/paypal_statement.csv')
    statement = CsvBankStatement.parse(data)

    assert statement.known?

    assert_equal 12, statement.transactions.size

    payment = statement.transactions.first
    assert_nil payment.counterparty
    assert_nil payment.counterparty_account
    assert_nil payment.counterparty_bank_code
    assert_equal '38880240BR', payment.id
    assert_equal BigDecimal('-175424.07'), payment.amount
    assert_nil payment.variable_symbol
    assert_nil payment.specific_symbol
    assert_nil payment.constant_symbol
    assert_equal Date.parse('29.04.2022'), payment.date
    assert_equal 'FIO Firma CZK, 1710', payment.note
    assert_equal 'CZK', payment.currency
    assert_nil payment.account
    assert_nil payment.account_identifier

    payment = statement.transactions[11]
    assert_equal BigDecimal('-2.12'), payment.amount
    assert_equal 'Fee: atthecoz@gmail.com, Willow Fellow Studios', payment.note
    assert_equal 'USD', payment.currency
  end

  def test_csob_personal_statement
    data = File.read('./test/files/csob_personal_statement.csv')
    statement = CsvBankStatement.parse(data)

    assert statement.known?

    assert_equal 2, statement.transactions.size

    payment = statement.transactions.first
    assert_equal '2048555105/2600', payment.counterparty
    assert_equal '2048555105', payment.counterparty_account
    assert_equal '2600', payment.counterparty_bank_code
    assert_equal '103696078', payment.id
    assert_equal BigDecimal('210782'), payment.amount
    assert_equal '2022005', payment.variable_symbol
    assert_equal '0', payment.specific_symbol
    assert_equal '0', payment.constant_symbol
    assert_equal Date.parse('10.06.2022'), payment.date
    assert_equal 'Superstar, S.R.O.,, Příchozí úhrada, Pan Novák', payment.note
    assert_equal 'CZK', payment.currency
    assert_equal '251674128/0300', payment.account
    assert_nil payment.account_identifier

    payment = statement.transactions[1]
    assert_equal BigDecimal('-100.55'), payment.amount
    assert_equal 'Pan Novák, Odchozí úhrada', payment.note
    assert_equal 'CZK', payment.currency
  end

  def test_parsing_of_file_with_weird_separators
    data = File.read('./test/files/weird_separator.csv')
    statement = CsvBankStatement.parse(data)

    assert statement.known?
  end

  def test_cs_business_statement
    data = File.read('./test/files/cs_business_statement.csv')
    statement = CsvBankStatement.parse(data)

    assert statement.known?

    assert_equal 4, statement.transactions.size

    payment = statement.transactions.first
    assert_nil payment.counterparty
    assert_nil payment.counterparty_account
    assert_nil payment.counterparty_bank_code
    assert_equal '2.0220630001', payment.id
    assert_equal BigDecimal('-200'), payment.amount
    assert_nil payment.variable_symbol
    assert_nil payment.specific_symbol
    assert_equal '8', payment.constant_symbol
    assert_equal Date.parse('30.06.2022'), payment.date
    assert_equal 'Cena za internetové bankovnictví Business 24', payment.note
    assert_nil payment.currency
    assert_equal '42425383/0800', payment.account
  end

  def test_unicredit_business_statement
    data = File.read('./test/files/unicredit_business_statement.csv')
    statement = CsvBankStatement.parse(data)

    assert statement.known?

    assert_equal 2, statement.transactions.size

    payment = statement.transactions.first
    assert_equal '2114277/2700', payment.counterparty
    assert_equal '2114277', payment.counterparty_account
    assert_equal '2700', payment.counterparty_bank_code
    assert_equal '656604', payment.id
    assert_equal BigDecimal('1000'), payment.amount
    assert_nil payment.variable_symbol
    assert_nil payment.specific_symbol
    assert_nil payment.constant_symbol
    assert_equal Date.parse('01.06.2022'), payment.date
    assert_equal 'MV strojírna s.r.o.', payment.note
    assert_equal 'CZK', payment.currency
    assert_equal '2113873/2700', payment.account
  end
end
