# frozen_string_literal: true

require 'require_all'
require 'scraped'
require 'scraperwiki'
require 'active_support'
require 'active_support/core_ext/string'
require 'table_unspanner'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

# require_rel 'lib'

def scrape(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

class Page < Scraped::HTML
  field :presidents do
    table.xpath('tr[td]').map do |tr|
      fragment(tr => Row)
    end
  end

  private

  def table
    @table ||= TableUnspanner::UnspannedTable.new(noko.at_xpath('.//table[2]')).nokogiri_node
  end
end

class Row < Scraped::HTML
  field :id do
    name.parameterize
  end

  field :name do
    noko.xpath('td[3]').text.tidy.gsub(/\[.+?\]$/, '')
  end

  field :area_name do
    noko.xpath('td[2]/a').text.tidy
  end

  field :area_id do
    noko.xpath('td[1]').text.tidy
  end

  field :party_code do
    noko.xpath('td[5]').text.tidy
  end

  field :party_name do
    parties[party_code]
  end

  private

  def parties
    noko.xpath('../tr[td]/td[5]/a').map { |a| [a.text, a[:title]] }.to_h
  end
end

wikipedia_url = 'https://fr.wikipedia.org/wiki/Liste_des_pr%C3%A9sidents_des_conseils_d%C3%A9partementaux_fran%C3%A7ais'

page = scrape(wikipedia_url => Page)

page.presidents.each do |president|
  ScraperWiki.save_sqlite([:id], president.to_h)
end
