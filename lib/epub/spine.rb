module Epub
  class Spine
    OPF_XPATH      = '//xmlns:spine'
    OPF_ITEM_XPATH = '//xmlns:itemref'

    def initialize(rootdoc, epub)
      @epub   = epub
      @xmldoc = rootdoc.xpath(OPF_XPATH).first
    end


    def items
      manifest = @epub.manifest
      items = []

      nodes do |node|
        id = node.attributes['idref']
        items << manifest[id] if id
      end

      items
    end


    def toc
      @epub.manifest[toc_manifest_id]
    end


    def to_s
      @xmldoc.to_s
    end

    def toc_manifest_id
      toc_manifest_id = @xmldoc.attributes['toc']
      toc_manifest_id.to_s.strip
    end

    private

      def nodes
        @xmldoc.xpath(OPF_ITEM_XPATH).each do |node|
          yield(node)
        end
      end

  end
end