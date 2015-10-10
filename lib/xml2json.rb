require 'libxml'
require 'json'
require 'active_support/inflector'
require_relative './xml2json/configuration'

module XML2JSON
  class InvalidXML < StandardError; end

  def self.parse xml
    parse_to_hash(xml).to_json
  end

  def self.parse_to_hash xml
    begin
      doc = LibXML::XML::Parser.string(xml, options: LibXML::XML::Parser::Options::NOBLANKS).parse
    rescue LibXML::XML::Error
      raise InvalidXML.new
    end

    root = doc.root
    hash = { root.name => parse_node(root) }
    hash[root.name] = { self.configuration.namespaces_key => 
      Hash[root.namespaces.definitions.collect { |d| 
       key = ( d.prefix && !d.prefix.strip.empty? ) ? "xmlns:#{d.prefix}" : 'xmlns'
       [ key, d.href ] 
      }]
    }.merge(hash[root.name]) unless root.namespaces.definitions.empty?
    hash
  end


  def self.parse_node(node)
    if node.children.count > 0
      if node.children.size == 1
        child = node.first
        if child.text? or child.cdata?
          return (node.attributes? ? parse_attributes(node).merge(text_hash(child)) : child.content)
        end
      end
      parse_attributes(node).merge(node2json(node))
    else
      node.attributes? ? parse_attributes(node).merge(text_hash(node)) : node.content
    end
  end

  def self.text_hash(node)
    return {} if node.content.strip.empty?
    { self.configuration.text_key => node.content }
  end

  def self.parse_attributes(node)
    !node.attributes? ? {} : { self.configuration.attributes_key => Hash[node.attributes.map { |a| [a.name, a.value] } ]}
  end

  def self.node2json node
    node.children.each_with_object({}) do |child, hash|
      key = namespaced_node_name child

      if hash.has_key?(key)
        node_to_nodes!(hash, key)
        hash[key] << parse_node(child)
      else
        hash[key] = parse_node(child)
      end

    end
  end

  def self.node_to_nodes! hash, key
    if !hash[key].is_a?(Array)
      tmp = hash[key]
      hash[key] = [ tmp ]
    end
  end

  def self.namespaced_node_name node
    "#{prefix(node)}#{node.name}"
  end

  def self.prefix node
    ns = node.namespaces.namespace
    if ns && ns.prefix && !ns.prefix.strip.empty?
      "#{ns.prefix}:"
    else
      ""
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.config
    yield configuration if block_given?
  end

  def self.reset
    @configuration = Configuration.new
  end
end
