#!/usr/bin/env ruby

# file: mymedia-pages.rb


require 'mymedia-blogbase'


class MyMediaPages < MyMediaBlogBase

  def initialize(config: nil)
    
    super(media_type: 'pages', public_type: @public_type='pages', ext: '.(html|md)', config: config)
    @media_src = "%s/media/pages" % @home
  end
  
  def copy_publish_to_be_removed(src_path, raw_msg='')
    msg = super(src_path, raw_msg)
  end
  
  def copy_publish(filename, raw_msg='')
    
    @filename = filename
    src_path = File.join(@media_src, filename)

    if File.basename(src_path)[/[pw]\d{6}T\d{4}\.(?:html)/] then      
      return file_publish(src_path, raw_msg)
    end
    
    file_publish(src_path, raw_msg) do |destination, raw_destination|
      
      #FileUtils.cp src_path, destination
      #FileUtils.cp src_path, raw_destination   
      
      if File.extname(src_path) == '.md' then      
        
        raw_dest_xml = raw_destination.sub(/html$/,'xml')          
        md_destination = raw_destination.sub(/html$/,'md')
        FileUtils.cp src_path, md_destination
        
        source = md_destination[/\/r\/#{@public_type}.*/]
        s = @website + source
        absolute_path = s[/https?:\/\/[^\/]+([^$]+)/,1]

        doc = xml(File.open(src_path, 'r').read, 
                        absolute_path, filename)          
        
        modify_xml(doc, raw_dest_xml)

        basic_xsl = File.read "#{@home}/r/xsl/#{@public_type}.xsl"
                
        File.write raw_destination, 
          Nokogiri::XSLT(basic_xsl)\
            .transform(Nokogiri::XML(File.read raw_dest_xml))

        xsl = File.read "#{@home}/#{@www}/xsl/#{@public_type}.xsl"

        File.write destination, 
           Nokogiri::XSLT(xsl).transform(Nokogiri::XML(File.read raw_dest_xml))
        else
          FileUtils.cp src_path, destination
          FileUtils.cp src_path, raw_destination   
      end
      

      if not File.basename(src_path)[/[pw]\d{6}T\d{4}\.(?:html|md)/] then
        html_filename = File.basename(src_path).sub(/md$/,'html')

        FileUtils.cp destination, @home + "/#{@public_type}/" + html_filename
        html_filepath = @home + "/#{@public_type}/static.xml"          
        target_url = [@website, @public_type, html_filename].join('/')
        publish_dynarex(html_filepath, {title: html_filename, url: target_url })          
        tags = doc.root.xpath('summary/tags/tag/text()')

        raw_msg = "%s %s" % [doc.root.text('summary/title'), 
               tags.map {|x| "#%s" % x }.join]

      end

      [raw_msg, target_url]
    end    

  end
  
  private
  
  def modify_xml(doc, filepath)
    
    raw_msg = microblog_title2(doc)
    doc.instructions.push %w(xml-stylesheet title='XSL_formatting' type='text/xsl') + ["href='#{@website}/r/xsl/#{@public_type}.xsl'"]
    doc = yield(doc) if block_given?
    File.write filepath, doc.xml(pretty: true)    
  end
     
  
end