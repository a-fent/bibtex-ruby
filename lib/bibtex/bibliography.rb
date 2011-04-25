#--
# BibTeX-Ruby
# Copyright (C) 2010  Sylvester Keil <sylvester.keil.or.at>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++

require 'forwardable'

module BibTeX

  #
  # The Bibliography class models a BibTeX bibliography;
  # typically, it corresponds to a `.bib' file.
  #
  class Bibliography
    extend Forwardable
    include Enumerable
    
    attr_accessor :path
    attr_reader :data, :strings, :entries, :errors

    def_delegators :@data, :length, :size, :each
    
    #
    # Opens and parses the `.bib' file at the given +path+. Returns
    # a new Bibliography instance corresponding to the file.
    #
    # The options argument is passed on to BibTeX::Parser.new.
    #
    def self.open(path, options = {})
      BibTeX.log.debug("Opening file #{path}")
      BibTeX::Parser.new(options).parse(File.read(path))
    end
    
    #
    # Creates a new bibliography; empty if no data attribute is specified.
    #
    def initialize(data = [])
      @data = []
      @strings = {}
      @entries = {}
      @errors = []
      add(data)
    end
    
    # Adds a new element, or a list of new elements to the bibliography.
    # Returns the Bibliography for chainability.
    def add(data)
      raise(ArgumentError,'BibTeX::Bibliography.add data expected to be enumerable or of type BibTeX::Element; was: ' + data.class.name) unless data.respond_to?(:each) || data.is_a?(Element)
      data.is_a?(Element) ? self << data : data.each { |d| self << d }
      self
    end
    
    # Saves the bibliography to the current path.
    def save
      save_to(@path)
    end
    
    # Saves the bibliography to a file at the given path.
    def save_to(path)
      File.open(path, "w") do |f|
        f.write to_s
      end
    end
    
    # Add an object to the bibliography. Returns the bibliography.
    def <<(obj)
      raise(ArgumentError, 'A BibTeX::Bibliography can contain only BibTeX::Elements; was: ' + obj.class.name) unless obj.is_a?(Element)
      @data << obj.added_to_bibliography(self)
      self
    end
    
    # Delete an object from the bibliography. Returns the object, or nil
    # if the object was not part of the bibliography.
    def delete(obj)
      @data.delete(obj.removed_from_bibliography(self))
    end
    
    def delete_all
      @data.each { |obj| obj.removed_from_bibliography(self) }
      @data = []
    end
    
    # Returns all @preamble objects.
    def preambles
      find_by_type(BibTeX::Preamble)
    end
    
    # Returns the first entry with a given key.
    def [](key)
      @entries[key.to_s]
    end
          
    # Returns all @comment objects.
    def comments
      find_by_type(BibTeX::Comment)
    end

    # Returns all meta comments, i.e., all text outside of BibTeX objects.
    def meta_comments
      find_by_type(BibTeX::MetaComment)
    end

    # Returns all objects which could not be parsed successfully.
    def errors
      @errors
    end

    # Returns true if there are object which could not be parsed.
    def errors?
      !errors.empty?
    end

    # Returns true if the +Bibliography+ contains no errors and only
    # valid BibTeX objects (meta comments are ignored).
    def valid?
      !errors? && !@entries.values.map(&:valid?).uniq.include?(false)
    end
    
    # Replaces all string constants which are defined in the bibliography.
    #
    # By default constants in @string, @preamble and entries are defined; this
    # behaviour can be changed using the options argument by setting
    # the :include option to a list of types.
    #
    # Note that strings are replaced in the order in which they occur in the
    # bibliography.
    #
    # call-seq:
    # replace_strings
    # replace_strings({ :include => [BibTeX::String,BibTeX::Preamble]})
    #
    def replace_strings(options={})
      options[:include] ||= [BibTeX::String, BibTeX::Preamble, BibTeX::Entry]
      find_by_type(options[:include]).each { |e| e.replace!(@strings) if e.respond_to?(:replace!)}
    end

    def join_strings(options={})
      options[:include] ||= [BibTeX::String, BibTeX::Preamble, BibTeX::Entry]
      find_by_type(options[:include]).each { |e| e.join! if e.respond_to?(:join!)}
    end
    
    # Returns true if the bibliography is currently empty.
    def empty?
      @data.empty?
    end
    
    # Returns the bibliography as an array of +BibTeX::Element+
    def to_a
      @data
    end
    
    # Returns a string representation of the bibliography.
    def to_s
      @data.map(&:to_s).join
    end
    
    
    # Returns a Ruby hash representation of the bibliography.
    def to_hash
      @entries.values.map(&:to_hash)
    end
    
    # Returns a YAML representation of the bibliography. Only BibTeX entries are exported.
    def to_yaml
      to_hash.to_yaml
    end
    
    # Returns a JSON representation of the bibliography. Only BibTeX entries are exported.
    def to_json
      to_hash.to_json
    end
    
    # Returns an XML representation of the bibliography. Only BibTeX entries are exported.
    def to_xml
      xml = REXML::Document.new
      xml << REXML::XMLDecl.new('1.0','UTF-8')
      root = REXML::Element.new('bibliography')
      @entries.values.each { |e| root.add_element(e.to_xml) }
      xml << root
      xml
    end
    
    private

    def find_by_type(type)
      @data.find_all { |x| type.respond_to?(:inject) ? type.inject(false) { |s,n| s || x.instance_of?(n) } : x.instance_of?(type) }
    end

    def find_entry(key)
      entries.find { |e| e.key == key.to_s }
    end
  end
end
