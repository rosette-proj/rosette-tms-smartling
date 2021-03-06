# encoding: UTF-8

require 'spec_helper'

include Rosette::Tms::SmartlingTms

describe SmartlingTmxParser do
  describe '#load' do
    let(:parser) { SmartlingTmxParser }
    let(:variant) { 'en:#:foo:#:bar' }

    let(:tmx_contents) do
      TmxFixture.load('single', {
        key: 'foobar', meta_key: variant, translation: 'fussbar'
      })
    end

    it 'converts smartling variants to meta keys and removes the leading locale' do
      parser.load(tmx_contents).tap do |result|
        meta_key = 'foo.bar'
        expect(result).to include(meta_key)
        expect(result[meta_key].size).to eq(1)
        expect(result[meta_key].first).to be_a(TmxParser::Unit)
      end
    end

    context 'with a variant containing an array index' do
      let(:variant) { 'en:#:foo:#:[2]:#:bar' }

      it 'removes enclosing square brackets from the array index and subtracts one' do
        # fyi smartling indexes start at 1 instead of 0
        parser.load(tmx_contents).tap do |result|
          meta_key = 'foo.1.bar'
          expect(result).to include(meta_key)
          expect(result[meta_key].size).to eq(1)
          expect(result[meta_key].first).to be_a(TmxParser::Unit)
        end
      end
    end
  end
end
