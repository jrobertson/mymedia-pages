#!/usr/bin/env ruby

# file: mymedia-pages.rb


require 'mymedia'


class MyMediaPages < MyMedia::Base

  def initialize(media_type: media_type='pages',
       public_type: @public_type=media_type, ext: '.(html|md|txt)',config: nil)
    
    super(media_type: media_type, public_type: @public_type=media_type,
                                        ext: '.(html|md|txt)', config: config)
    @media_src = "%s/media/%s" % [@home, media_type]
    @target_ext = '.html'
    @static_html = true
    
  end  
  
  def copy_publish(filename, raw_msg='')
    
    @filename = filename
    src_path = File.join(@media_src, filename)

    if File.basename(src_path)[/[pwn]\d{6}T\d{4}\.(?:html)/] then      
      return file_publish(src_path, raw_msg)
    end
    
    file_publish(src_path, raw_msg) do |destination, raw_destination|
      
      #FileUtils.cp src_path, destination
      #FileUtils.cp src_path, raw_destination   
      
      ext = File.extname(src_path)
      
      if ext[/\.(?:md|txt)/] then      

        raw_dest_xml = raw_destination.sub(/html$/,'xml')
        dest_xml = destination.sub(/html$/,'xml')
        x_destination = raw_destination.sub(/\.html$/,ext)

        FileUtils.cp src_path, x_destination
        
        source = x_destination[/\/r\/#{@public_type}.*/]
        s = @website + source

        relative_path = s[/https?:\/\/[^\/]+([^$]+)/,1]

        doc = xml(File.open(src_path, 'r').read, relative_path, filename)
        
        modify_xml(doc, raw_dest_xml)
        modify_xml(doc, dest_xml,'')

        basic_xsl = File.read "#{@home}/r/xsl/#{@public_type}.xsl"
                
        File.write raw_destination, 
          Nokogiri::XSLT(basic_xsl)\
            .transform(Nokogiri::XML(File.read raw_dest_xml))

        xsl = File.read "#{@home}/#{@www}/xsl/#{@public_type}.xsl"

        File.write destination, 
           Nokogiri::XSLT(xsl).transform(Nokogiri::XML(File.read dest_xml))

        html_filename = File.basename(src_path).sub(/(?:md|txt)$/,'html')
        xml_filename = html_filename.sub(/html$/,'xml')
        FileUtils.cp destination, File.dirname(destination) + html_filename
        FileUtils.cp dest_xml, File.dirname(dest_xml) + xml_filename


        #target_url = [@website, @public_type, html_filename].join('/')

      else
        FileUtils.cp src_path, destination
        FileUtils.cp src_path, raw_destination   
      end

      if not File.basename(src_path)[/[pwn]\d{6}T\d{4}\.(?:html|md|txt)/] then
        


        FileUtils.cp destination, @home + "/#{@public_type}/" + html_filename
        FileUtils.cp dest_xml, @home + "/#{@public_type}/" + xml_filename

        static_filepath = @home + "/#{@public_type}/static.xml"          

        x_filename = @static_html == true ? html_filename : xml_filename

        
        target_url = [@website, @public_type, x_filename].join('/')

        publish_dynarex(static_filepath, {title: x_filename, url: target_url })          
        

      end
      
      tags = doc.root.xpath('summary/tags/tag/text()')

      raw_msg = "%s %s" % [doc.root.text('summary/title'), 
              tags.map {|x| "#%s" % x }.join]      

      [raw_msg, target_url]
    end    

  end
  
  
  private
  
  def htmlize(raw_buffer)

    buffer = Martile.new(raw_buffer).to_html

    lines = buffer.strip.lines.to_a
    raw_title = lines.shift.chomp
    raw_tags = lines.pop[/[^>]+$/].split

    s = lines.join.gsub(/(?:^\[|\s\[)[^\]]+\]\((https?:\/\/[^\s]+)/) do |x|
      
      next x if x[/#{@domain}/]
      s2 = x[/https?:\/\/([^\/]+)/,1].split(/\./)
      r = s2.length >= 3 ? s2[1..-1] :  s2
      "%s [%s]" % [x, r.join('.')]
    end      

    html = RDiscount.new(s).to_html
    [raw_title, raw_tags, html]

  end  

  def microblog_title(doc)

    summary = doc.root.element('summary')
    title = summary.text('title')
    tags = summary.xpath('tags/tag/text()').map{|x| '#' + x}.join ' '

    url = "%s/%s/yy/mm/dd/hhmmhrs.html" % [@website, @media_type]
    full_title = (url + title + ' ' + tags)

    if full_title.length > 140 then
      extra = full_title.length - 140
      title = title[0..-(extra)] + ' ...'
    end

    title + ' ' + tags

  end   
  
  
  def modify_xml(docx, filepath, xslpath='r/')
    
    doc = docx.clone
    raw_msg = microblog_title(doc)
    doc.instructions.push %w(xml-stylesheet title='XSL_formatting' type='text/xsl') \
                                      + ["href='#{@website}/#{xslpath}xsl/#{@public_type}.xsl'"]
    doc = yield(doc) if block_given?
    File.write filepath, doc.xml(pretty: true)    
  end
  
  def xml(raw_buffer, filename, original_file)

    begin

      raw_title, raw_tags, html = htmlize(raw_buffer)

      doc = Rexle.new("<body>%s</body>" % html)    

      doc.root.xpath('//a').each do |x|

        next unless x.attributes[:href].empty?
        
        new_link = x.text.gsub(/\s/,'_')

        x.attributes[:href] = "#{@dynamic_website}/do/#{@public_type}/new/" + new_link
        x.attributes[:class] = 'new'
        x.attributes[:title] = x.text + ' (page does not exist)'
      end
      
      body = doc.root.children.join

      
      xml = RexleBuilder.new
      
      a = xml.page do 
        xml.summary do
          xml.title raw_title
          xml.tags { raw_tags.each {|tag| xml.tag tag }}
          xml.source_url filename
          xml.source_file File.basename(filename)
          xml.original_file original_file
          xml.published Time.now.strftime("%d-%m-%Y %H:%M")
          xml.filetitle original_file[/.*(?=\.\w+$)/]
        end
        
        xml.body body
      end
    
    rescue
      @logger.debug "mymedia-pages.rb: html: " + ($!).to_s
    end
    
    return Rexle.new(a)
  end  
  
  
end
