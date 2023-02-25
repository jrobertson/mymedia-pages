#!/usr/bin/env ruby

# file: mymedia-pages.rb


require 'mymedia'
require 'martile'
require 'kramdown'
require 'rxfileio'


module PageReader
  include RXFRead

  # read the source file
  #
  def read(raw_filename)

    filename = escape(raw_filename)
    FileX.read File.join(@media_src, filename)

  end

  # view the published file
  #
  def view(s)

    filepath = if s.count('/') > 1 then
      # archived file
      File.join(@home, @www, @public_type,  s.sub(/\.html$/,'') + '.html')
    else
      # static file
      File.join(@home, @www, @public_type, s.sub(/\.html$/,'') + '.html')
    end

    FileX.read(filepath)
  end

  def escape(s)
    s.gsub(/ +/,'_')#.gsub(/'/,'%27')
  end

end

class MyMediaPagesError < Exception
end

class MyMediaPages < MyMedia::Base
  include MyMedia::IndexReader
  include PageReader

  def initialize(media_type: media_type='pages',
       public_type: @public_type=media_type, ext: '.(html|md|txt)',
                 config: nil, log: nil, debug: false)
    
    raise MyMediaPagesError, 'Missing config' unless config
    
    super(media_type: media_type, public_type: @public_type=media_type,
                            ext: '.(html|md|txt)', config: config, log: log)

    @target_ext = '.html'
    @static_html = true
    @debug = debug
    
  end  
  
  def copy_publish(filename, raw_msg='')

    @log.info 'MyMediaPagesinside copy_publish' if @log
    @filename = filename
    #jr2022-10-09 src_path = File.join(@media_src, filename)
    src_path = filename

    if File.basename(src_path)[/[a-z]\d{6}T\d{4}\.(?:html)/] then      
      return file_publish(src_path, raw_msg)
    end

    file_publish(src_path, raw_msg) do |destination, raw_destination|

      ext = File.extname(src_path)
      
      if ext[/\.(?:md|txt)/] then      

        raw_dest_xml = raw_destination.sub(/html$/,'xml')
        dest_xml = destination.sub(/html$/,'xml')
        x_destination = raw_destination.sub(/\.html$/,ext)

        puts "src: %s dest: %s" % [src_path, x_destination] if @debug
        FileX.cp src_path, x_destination
        
        source = x_destination[/\/r\/#{@public_type}.*/]
        s = @website + source

        relative_path = s[/https?:\/\/[^\/]+([^$]+)/,1]
        src_content = FileX.read src_path
        doc = xml(src_content, relative_path, filename)

        return unless doc

        modify_xml(doc, raw_dest_xml)
        modify_xml(doc, dest_xml)

        @log.info 'mymedia_pages/copy_publish: after modify_xml' if @log

        FileX.write raw_destination,
            xsltproc(File.join(@home, @www, 'r', 'xsl', @public_type + '.xsl'),
                     raw_dest_xml)
        FileX.write destination,
            xsltproc(File.join(@home, @www, 'xsl', @public_type + '.xsl'),
                     dest_xml)

        html_filename = basename(@media_src, src_path).sub(/(?:md|txt)$/,'html')
        
        
        xml_filename = html_filename.sub(/html$/,'xml')

        FileX.mkdir_p File.dirname(File.join(File.dirname(destination),
                                             html_filename))
        FileX.cp destination, File.join(File.dirname(destination),
                                        html_filename)

        FileX.mkdir_p File.dirname( File.join(File.dirname(dest_xml),
                                              xml_filename))
        FileX.cp dest_xml, File.join(File.dirname(dest_xml), xml_filename)

        tags = doc.root.xpath('summary/tags/tag/text()')
        raw_msg = "%s %s" % [doc.root.text('summary/title'), 
                tags.map {|x| "#%s" % x }.join(' ')]
        
        
        @log.info "msg: %s tags: %s" % [raw_msg, tags.inspect] if @log


      else
        
        html_filename = basename(src_path)
        
        if html_filename =~ /\// then
          FileX.mkdir_p File.dirname(html_filename)
        end        
        
        FileX.cp src_path, destination
        FileX.cp src_path, raw_destination
        
        raw_msg = FileX.read(destination)[/<title>([^<]+)<\/title>/,1]
      end
            
      if not File.basename(src_path)[/[a-z]\d{6}T\d{4}\.(?:html|md|txt)/] then
        
        @log.info 'MyMediaPages::copy_publish before FileUtils' if @log

        html_filepath = File.join(@home, @www, @public_type, html_filename)
        FileX.mkdir_p File.dirname(html_filepath)
        FileX.cp destination, html_filepath

        if xml_filename then
          xml_filepath = File.join(@home, @www, @public_type,  xml_filename)
          FileUtils.cp dest_xml, xml_filepath
        end

        static_filepath = File.join(@home, @www, @public_type, 'static.xml')
        x_filename = @static_html == true ? html_filename : xml_filename        
        
        if @log then
          @log.info 'MyMediaPages::copy_publish ->file_publish ' +
              'before publish_dynarex'
        end
        
        target_url = File.join(@website,  @public_type, x_filename)
        target_url.sub!(/\.html$/,'') if @omit_html_ext
        publish_dynarex(static_filepath, {title: raw_msg, url: target_url })                  

      end

      [raw_msg, target_url]
    end    

  end

  def escape(s)
    s.gsub(/ +/,'_')#.gsub(/'/,'%27')
  end

  def writecopy_publish(raws, filename=nil)

    s = raws.strip.gsub(/\r/,'')

    title = escape(s.lines[0].chomp)
    filename ||= title + '.txt'
    FileX.write File.join(@media_src, filename), s

    copy_publish File.join(@media_src, filename)
  end

  
  private
  
  def htmlize(raw_buffer)

    buffer = Martile.new(raw_buffer, ignore_domainlabel: @domain).to_s
    lines = buffer.strip.lines.to_a
    puts 'lines: ' + lines.inspect if @debug

    raw_title = lines.shift.chomp
    puts 'lines 2): ' + lines.inspect if @debug

    raise MyMediaPagesError, 'invalid input file' if lines.empty?
    raw_tags = lines.pop[/[^>]+$/].split

    s = lines.join

    html = Kramdown::Document.new(s).to_html
    [raw_title, raw_tags, html]

  end  

  def microblog_title(doc)

    summary = doc.root.element('summary')

    title = summary.text('title')
    tags = summary.xpath('tags/tag/text()').map{|x| '#' + x}.join(' ')
    
    url = "%s/%s/yy/mm/dd/hhmmhrs.html" % [@website, @media_type]
    full_title = (url + title + ' ' + tags)

    if full_title.length > 140 then
      extra = full_title.length - 140
      title = title[0..-(extra)] + ' ...'
    end

    title + ' ' + tags

  end   
  
  
  def modify_xml(docx, filepath, xslpath='r/')

    if @debug then
      'mymedia_pages: inside modify_xml: docx.xml: ' + docx.xml.inspect
    end

    if @log then
      @log.info 'mymedia_pages: inside modify_xml: docx.xml: ' + docx.xml.inspect
    end
    
    doc = Rexle.new docx.xml pretty: false
    
    if @log then
      @log.info 'doc.xml:  ' + doc.xml.inspect if @log
    end

    raw_msg = microblog_title(doc)

    doc.instructions.push %w(xml-stylesheet title='XSL_formatting' type='text/xsl') \
                          + ["href='#{@website}/#{xslpath}xsl/#{@public_type}.xsl'"]

    yield(doc) if block_given?
    FileX.write filepath, doc.xml(declaration: true, pretty: false)
  end
  
  def xml(raw_buffer, filename, original_file)

    begin

      puts 'before htmlize'
      raw_title, raw_tags, html = htmlize(raw_buffer)
      puts 'after htmlize'

      doc = Rexle.new("<body>%s</body>" % html)    

      doc.root.xpath('//a').each do |x|

        next unless x.attributes[:href] and x.attributes[:href].empty?
        
        new_link = x.text.gsub(/\s/,'_')

        x.attributes[:href] = "#{@dynamic_website}/do/#{@public_type}/new/" \
            + new_link
        x.attributes[:class] = 'new'
        x.attributes[:title] = x.text + ' (page does not exist)'
      end
      
      body = doc.root.children.join

      # A special tag can be used to represent a metatag which indicates if 
      # the document access is to be made public. The special tag can either 
      # be a 'p' or 'public'

      access = raw_tags.last[/^(?:p|public)$/] ? raw_tags.pop : nil
      
      xml = RexleBuilder.new
      
      a = xml.page do 
        xml.summary do
          xml.title raw_title
          xml.tags { raw_tags.each {|tag| xml.tag tag }}
          xml.access access if access
          xml.source_url filename
          xml.source_file File.basename(filename)
          xml.original_file File.basename(original_file)
          xml.published Time.now.strftime("%d-%m-%Y %H:%M")
          xml.filetitle original_file[/.*(?=\.\w+$)/]
        end
        
        xml.body body
      end
            
    
    rescue
      raise MyMediaPagesError, 'xml(): ' + ($!).inspect
    end

    return Rexle.new(a)
  end  
  
  def xsltproc(xslpath, xmlpath)    
    
    if not FileX.exists? xslpath then
      raise MyMediaPagesError, 'Missing file - ' + xslpath
    end

    Nokogiri::XSLT(FileX.read(xslpath))\
            .transform(Nokogiri::XML(FileX.read(xmlpath))).to_xhtml(indent: 0)
  end
end

module PagesTestSetup
  include RXFileIOModule
  
  def set_paths(cur_dir, www_dir, media_dir)
    
    @cur_dir = cur_dir
    @dir, @www_dir, @media_dir = @public_type, www_dir, media_dir
    
  end

  def cleanup()

    # remove the previous test files
    #
    FileX.rm_r @www_dir + '/*', force: true
    puts "Previous #{@www_dir} files now removed!"
    
    FileX.rm_r @media_dir + '/*', force: true
    puts "Previous #{@media_dir} files now removed!"
    
  end
  
  def prep()
    
    # create the template files and directories
    #
    xsl_file = @public_type + '.xsl'
    xsl_src = File.join(@cur_dir, @public_type + '.xsl')
    
    www_dest = File.join(@www_dir, 'xsl', xsl_file)
    r_dest = File.join(@www_dir, 'r', 'xsl', xsl_file)
    index_dest = File.join(@www_dir, @public_type, 'index-template.html')

    FileX.mkdir_p File.dirname(www_dest)
    FileX.cp xsl_src, www_dest

    FileX.mkdir_p File.dirname(r_dest)
    FileX.cp xsl_src, r_dest

    FileX.mkdir_p File.dirname(index_dest)
    FileX.cp File.join(@cur_dir, 'index-template.html'), index_dest        

    FileUtils.mkdir_p File.join(@media_dir, @dir)
    
  end

  # create the input file
  #  
  def write(filename: '', content: '')

    File.write File.join(@media_dir, @dir, filename), content
    puts 'debug: filename: ' + filename.inspect

  end

end


class PagesTester23 < MyMediaPages
  
  include PagesTestSetup
  
  # it is assumed this class will be executed from a test directory 
  # containing the following auxillary files:
  #  - pages.xsl
  #  - index-template.html
  
  def initialize(config: '', cur_dir:  '', www_dir: '/tmp/www', 
                 media_dir: '/tmp/media', debug: false)
        
    super(config: config, debug: debug)
    set_paths(cur_dir, www_dir, media_dir)
    
  end

end
