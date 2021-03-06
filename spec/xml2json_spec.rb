# require 'rspec/autorun'
require 'spec_helper'
require 'xml2json'

# Shutdown libxml error ouput for cleaner output during spec
LibXML::XML::Error.set_handler(&LibXML::XML::Error::QUIET_HANDLER)

describe XML2JSON do
  describe ".parse" do
    it 'jsonifies parsed hash' do
      expect(XML2JSON).to receive(:parse_to_hash).with('xml').and_return({"key" => "value"})
      expect(XML2JSON.parse('xml')).to eq('{"key":"value"}')
    end

    context "rss" do
      let(:rss) { SpecHelpers.open_fixture_file('rss.xml') }
      let(:json) { SpecHelpers.open_fixture_file('rss.json').delete("\n") }

      it "parses the rss into json" do
        hash = XML2JSON.parse(rss)
        expect(hash).to eq(json)
      end
    end

    context "atom" do
      let(:atom) { SpecHelpers.open_fixture_file('atom.xml') }
      let(:json) { SpecHelpers.open_fixture_file('atom.json').delete("\n") }

      it "parses the atom into json" do
        expect(XML2JSON.parse(atom)).to eq(json)
      end
    end
  end

  describe ".parse_to_hash" do
    it "parses xml into hash" do
      xml = '<a><b><c>Hello</c><d>World</d></b></a>'
      json = { "a" => { "b" => { "c" => "Hello", "d" => "World" } } }
      expect(XML2JSON.parse_to_hash(xml)).to eq(json)

      xml = '<a><b><x>Io</x><c><d>Hello</d><e>World</e></c></b></a>'
      json = { "a" => { "b" => { "x" => "Io", "c" => { "d" => "Hello", "e" => "World" } } } }
      expect(XML2JSON.parse_to_hash(xml)).to eq(json)
    end

    it "handles multiple elements" do
      xml = '<a><x><b>Primo</b><b>Secondo</b></x></a>'
      expect(XML2JSON.parse_to_hash(xml)).to(
        eq({ "a" => { "x" => { "b" => [ "Primo", "Secondo" ] } } })
      )

      xml = '<a><b><x>Primo</x></b><b><x>Secondo</x></b></a>'
      expect(XML2JSON.parse_to_hash(xml)).to(
        eq({ "a" => { "b" => [ { "x" => "Primo" }, { "x" => "Secondo" } ] } })
      )

      xml = '<a><b><x>Primo</x></b><b><x>Secondo</x></b><b><x>Terzo</x></b></a>'
      expect(XML2JSON.parse_to_hash(xml)).to(
        eq({ "a" => { "b" => [ { "x" => "Primo" }, { "x" => "Secondo" }, { "x" => "Terzo" }] } })
      )
    end

    it "parses node attributes" do
      xml = '<r><a url="www.google.it"></a></r>'
      expect(XML2JSON.parse_to_hash(xml)).to(
        eq({"r" => {"a" => { "_attributes" => {"url" => "www.google.it"}}}})
      )

      xml = '<r><a url="www.google.it"><b>ciao</b></a></r>'
      expect(XML2JSON.parse_to_hash(xml)).to(
        eq({"r" => {"a" => { "_attributes" => {"url" => "www.google.it"}, "b" => "ciao"}}})
      )

      xml = '<r><a url="www.google.it"></a><a url="www.google.com"></a></r>'
      expect(XML2JSON.parse_to_hash(xml)).to(
        eq({"r" => {"a" => [{ "_attributes" => {"url" => "www.google.it"}},{ "_attributes" => {"url" => "www.google.com"}}]}})
      )

      xml = '<r><a url="www.google.it"><b>ciao</b></a><a url="www.google.com"><b>ciao</b></a></r>'
      expect(XML2JSON.parse_to_hash(xml)).to(
        eq({"r" => {"a" => [{ "_attributes" => {"url" => "www.google.it"}, "b" => "ciao"},{ "_attributes" => {"url" => "www.google.com"}, "b" => "ciao"}]}})
      )
    end

    it "does not add the _text key when a node has no text" do
      xml = '<r><a url="www.google.it" /></r>'
      expect(XML2JSON.parse_to_hash(xml)).to(
        eq({ "r" => { "a" => { "_attributes" => { "url" => "www.google.it" } } } })
      )
    end

    it "parses root attributes" do
      xml = '<r id="1"><a>Hello</a></r>'
      expect(XML2JSON.parse_to_hash(xml)).to(
        eq({"r" => {"_attributes" => { "id" => "1" }, "a" => "Hello" } })
      )
    end

    context "namespaces" do
      let(:xml) { '<r xmlns:content="http://purl.org/rss/1.0/modules/content/"><content:encoded>Hello</content:encoded><content:encoded>World</content:encoded></r>' }
      it "parses namespaced node names" do
        expect(XML2JSON.parse_to_hash(xml)).to(
          eq({"r" => { "_namespaces" => { "xmlns:content" => "http://purl.org/rss/1.0/modules/content/" }, "content:encoded" => [ "Hello", "World" ] } })
        )
      end
    end

    context "invalid xml file" do
      it "raises an exception if the xml file is bad formed" do
        xml = '<invalid></xml>'
        expect {
          XML2JSON.parse_to_hash(xml)
        }.to raise_error XML2JSON::InvalidXML

        xml = 'not xml file'
        expect {
          XML2JSON.parse_to_hash(xml)
        }.to raise_error XML2JSON::InvalidXML
      end
    end

  end

  context "configuration" do
    after do
      XML2JSON.reset
    end

    it "let's the user choose the keys" do
      XML2JSON.config do |c|
        c.attributes_key = 'attr'
        c.namespaces_key = 'names'
        c.text_key = 'body'
      end
      expect(XML2JSON.configuration.attributes_key).to eq('attr')
      expect(XML2JSON.configuration.namespaces_key).to eq('names')
      expect(XML2JSON.configuration.text_key).to eq('body')
    end

    it "provides default values" do
      expect(XML2JSON.configuration.attributes_key).to eq('_attributes')
      expect(XML2JSON.configuration.namespaces_key).to eq('_namespaces')
      expect(XML2JSON.configuration.text_key).to eq('_text')
    end

    it "restores the default values" do
      XML2JSON.config do |c|
        c.attributes_key = 'attr'
      end

      expect(XML2JSON.configuration.attributes_key).to eq('attr')
      XML2JSON.reset

      expect(XML2JSON.configuration.attributes_key).to eq('_attributes')
    end
  end
end
