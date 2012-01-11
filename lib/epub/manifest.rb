require 'digest/md5'
require 'pathname'

module Epub
  # Make this hash accessible
  class Manifest
    OPF_XPATH       = '//xmlns:manifest'
    OPF_ITEMS_XPATH = '//xmlns:item'
    OPF_ITEM_XPATH  = '//xmlns:item[@id="%s"]'

    XML_NS = {
      'xmlns' => 'http://www.idpf.org/2007/opf'
    }

    def initialize(rootdoc, epub)
      @epub = epub
      reload_xmldoc
    end

    def reload_xmldoc
      @xmldoc = @epub.opf_xml.xpath(OPF_XPATH, 'xmlns' => XML_NS['xmlns'])
    end
    

    # Flattens the epub
    def normalize!
      # Flatten epub items
      items(:image, :html, :css, :misc) do |item,node|
        item.normalize!
      end

      # Flatten manifest
      items do |item,node|
        # Renames based on asbsolute path from base
        node['href'] = item.normalized_hashed_path(:relative_to => @epub.opf_path)

        # Move the file to flattened location
        @epub.file.mv item.abs_filepath, item.normalized_hashed_path
      end

      @epub.save_opf!(@xmldoc, OPF_XPATH)
      @epub.file.mv @epub.opf_path, "OEBPS/content.opf"

      # Move the opf file
      opf_path = "OEBPS/content.opf"
      @epub.opf_path = opf_path

      # Reset the XMLDOC
      reload_xmldoc
    end



    # Pretty display
    def to_s
      @xmldoc.to_s
    end


    ###
    # Accessors
    ###
    def assets
      items :image, :css, :misc
    end


    def images
      items :image
    end

    
    def html
      items :html
    end


    def css
      items :css
    end


    def misc
      items :misc
    end


    # Iterate over each item in the file, optional type specifier
    def items(*types)
      items = []
      nodes do |node|
        href = CGI::unescape(node.attributes['href'].to_s)

        item = item_for_path(href)

        if types.size < 1 || types.include?(item.type)
          if block_given?
            yield(item,node)
          else
            items << item
          end
        end
      end
      items if !block_given?
    end

    # Access item by id, for example `epub.manifest["cover-image"]` will grab the file for
    # the following XML entry
    # 
    #     <item id="cover-image" href="OEBPS/assets/cover.jpg" media-type="image/jpeg"/>
    #
    def [](key)
      item_for_path path_from_id(key)
    end


    def path_from_id(key)
      xpath = OPF_ITEM_XPATH % key
      nodes = @xmldoc.xpath(xpath)

      case nodes.size
      when 0
        return nil
      when 1
        node = nodes.first
        href = CGI::unescape(node.attributes['href'].to_s)
        return Pathname.new(href).cleanpath.to_s
      else
        raise "XPath match more than one entry"
      end
    end


    def abs_path_from_id(key)
      rel  = path_from_id(key)
      base = ::File.dirname(@epub.opf_path)
      path = ::File.join(base, rel)
      Pathname.new(path).cleanpath.to_s
    end


    def rel_path(path)
      base = Pathname.new(@epub.opf_path)
      path = Pathname.new(path)
      path = path.relative_path_from(base.dirname)
      path.to_s
    end


    def id_for_path(path)
      if node = node_for_path(path)
        return node.attributes['id'].to_s
      else
        nil
      end
    end


    def id_for_abs_path(path)
      id_for_path rel_path(path)
    end


    def item_for_path(path)
      # TODO: Need to get media type here also
      node = node_for_path(path)

      return nil if !node

      id         = node.attributes['id'].to_s
      media_type = node.attributes['media-type'].to_s
      href       = node.attributes['href'].to_s

      klass = nil

      # Is it the TOC
      if @epub.spine.toc_manifest_id == id
        klass = Toc
      end

      # Get type based on media-type
      if !klass && media_type
        case media_type
          when 'text/css'
            klass = CSS
          when /^image\/.*$/
            klass = Image
          when /^application\/xhtml.*$/
            klass = HTML
        end
      end

      # Get type based on file extension
      if !klass
        case href
          when /\.(css)$/
            klass = CSS
          when /\.(png|jpeg|jpg|gif|svg)$/
            klass = Image
          when /\.(html|xhtml)$/
            klass = HTML
        end
      end

      klass = Item if !klass

      item = klass.new(@epub, {
        :id => id
      })

      item
    end


    def item_for_abs_path(path)
      item_for_path rel_path(path)
    end


    def item(opts)
      path = nil
      if opts[:path]
        path = rel_path(opts[:path])
      elsif opts[:id]
        path = path_from_id(opts[:path])
      else
        raise "Not options given"
      end

      item_for_path(path)
    end



    private

      def nodes
        @xmldoc.xpath(OPF_ITEMS_XPATH).each do |node|
          yield(node)
        end
      end


      def node_for_path(path)
        nodes do |node|
          if node.attributes['href'].to_s == path
            return node
          end
        end
        nil
      end

  end
end