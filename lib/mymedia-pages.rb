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
  def read(filename)
    FileX.read File.join(@media_src, escape(filename))
  end

  # view the published file
  #
  def view(filename)
    FileX.read File.join(@home, @public_type, filename)
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

    super(media_type: media_type, public_type: @public_type=media_type,
                            ext: '.(html|md|txt)', config: config, log: log)

    @target_ext = '.html'
    @static_html = true
    @debug = debug

  end

  def copy_publish(filename, raw_msg='')

    @log.info 'MyMediaPagesinside copy_publish' if @log
    @filename = filename
    src_path = File.join(@media_src, filename)

    if File.basename(src_path)[/[a-z]\d{6}T\d{4}\.(?:html)/] then
      return file_publish(src_path, raw_msg)
    end

    file_publish(src_path, raw_msg) do |destination, raw_destination|

      ext = File.extname(src_path)

      if ext[/\.(?:md|txt)/] then

        raw_dest_xml = raw_destination.sub(/html$/,'xml')
        dest_xml = destination.sub(/html$/,'xml')
        x_destination = raw_destination.sub(/\.html$/,ext)


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
            xsltproc("#{@home}/r/xsl/#{@public_type}.xsl", raw_dest_xml)

        FileX.write destination,
            xsltproc("#{@home}/#{@www}/xsl/#{@public_type}.xsl", dest_xml)

        html_filename = basename(@media_src, src_path)\
            .sub(/(?:md|txt)$/,'html')


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

        html_filename = basename(@media_src, src_path)

        if html_filename =~ /\// then
          FileX.mkdir_p File.dirname(html_filename)
        end

        FileX.cp src_path, destination
        FileX.cp src_path, raw_destination

        raw_msg = FileX.read(destination)[/<title>([^<]+)<\/title>/,1]
      end

      if not File.basename(src_path)[/[a-z]\d{6}T\d{4}\.(?:html|md|txt)/] then

        @log.info 'MyMediaPages::copy_publish before FileUtils' if @log
        FileX.mkdir_p File.dirname(@home + "/#{@public_type}/" + html_filename)
        FileX.cp destination, @home + "/#{@public_type}/" + html_filename

        if xml_filename then
          FileUtils.cp dest_xml, @home + "/#{@public_type}/" + xml_filename
        end

        static_filepath = @home + "/#{@public_type}/static.xml"
        x_filename = @static_html == true ? html_filename : xml_filename
        target_url = [@website, @public_type, x_filename].join('/')

        if @log then
          @log.info 'MyMediaPages::copy_publish ->file_publish ' +
              'before publish_dynarex'
        end

        target_url.sub!(/\.html$/,'') if @omit_html_ext
        publish_dynarex(static_filepath, {title: raw_msg, url: target_url })

      end

      [raw_msg, target_url]
    end

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
          xml.original_file original_file
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
