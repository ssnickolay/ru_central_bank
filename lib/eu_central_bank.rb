require 'rubygems'
require 'open-uri'
require 'nokogiri'
require 'money'

class InvalidCache < StandardError ; end

class EuCentralBank < Money::Bank::VariableExchange

  attr_accessor :last_updated

  ECB_RATES_URL = 'http://www.cbr.ru/scripts/XML_daily.asp?date_req=17/04/2013'
  CURRENCIES = %w(USD JPY BGN CZK DKK GBP HUF ILS LTL LVL PLN RON SEK CHF NOK HRK RUB TRY AUD BRL CAD CNY HKD IDR INR KRW MXN MYR NZD PHP SGD THB ZAR)

  def update_rates(cache=nil)
    update_parsed_rates(exchange_rates(cache))
  end

  def save_rates(cache)
    raise InvalidCache if !cache
    File.open(cache, "w") do |file|
      io = open(ECB_RATES_URL) ;
      io.each_line {|line| file.puts line}
    end
  end

  def update_rates_from_s(content)
    update_parsed_rates(exchange_rates_from_s(content))
  end

  def save_rates_to_s
    open(ECB_RATES_URL).read
  end

  def exchange(cents, from_currency, to_currency)
    exchange_with(Money.new(cents, from_currency), to_currency)
  end

  def exchange_with(from, to_currency)
    rate = get_rate(from.currency, to_currency)
    unless rate
      from_base_rate = get_rate("EUR", from.currency)
      to_base_rate = get_rate("EUR", to_currency)
      rate = to_base_rate / from_base_rate
    end
    Money.new(((Money::Currency.wrap(to_currency).subunit_to_unit.to_f / from.currency.subunit_to_unit.to_f) * from.cents * rate).round, to_currency)
  end

  protected

  #def exchange_rates(cache=nil)
  #  rates_source = !!cache ? cache : ECB_RATES_URL
  #  doc = Nokogiri::XML(open(rates_source))
  #  doc.xpath('gesmes:Envelope/xmlns:Cube/xmlns:Cube//xmlns:Cube')
  #end
#
  #def exchange_rates_from_s(content)
  #  doc = Nokogiri::XML(content)
  #  doc.xpath('gesmes:Envelope/xmlns:Cube/xmlns:Cube//xmlns:Cube')
  #end

  def exchange_rates(cache=nil)
    rates_source = !!cache ? cache : ECB_RATES_URL
    doc = Nokogiri::XML(open(rates_source))
    doc.xpath('ValCurs/Valute')
  end

  def exchange_rates_from_s(content)
    doc = Nokogiri::XML(content)
    doc.xpath('/ValCurs/Valute')
  end

  def update_parsed_rates(rates)
    rates.each do |exchange_rate|
      currency = exchange_rate.search('CharCode').children[0].content
      string_rate = exchange_rate.search('Value').children[0].content
      string_rate[","] = "."
      rate = string_rate.to_f

      #rate = exchange_rate.attribute("Value").value.to_f
      #currency = exchange_rate.attribute("CharCode").value

      debugger
      add_rate("RUB", currency, rate)
    end
    add_rate("RUB", "RUB", 1)
    @last_updated = Time.now
  end
end
