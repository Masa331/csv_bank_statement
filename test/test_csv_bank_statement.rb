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

  def test_kb_statement
    data = File.read('./test/files/kb_statement.csv')
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
    assert_equal 'Planovana splatka uveru/uroku, SPLATKA JISTINY, DANTOM INDUSTRIAL S.R.O., Z    CK-0001158192180267', payment.note
    assert_equal 'CZK', payment.currency
    assert_equal '51-3819161607', payment.account
    assert_equal 'Foobar s.r.o.', payment.account_identifier
  end
end
