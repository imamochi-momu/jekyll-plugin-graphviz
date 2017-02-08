# encoding: utf-8
#
# (The MIT License)

require 'digest'
require 'liquid'
require 'open3'

module Jekyll
  module Graphviz
    class XGraphvizBlock < Liquid::Block
      include Liquid::StandardFilters
      GRAPHVIZ_DIR = "image/graphviz"
      DIV_CLASS_ATTR = "container"
      # The regular expression syntax checker. Start with the language specifier.
      # Follow that by zero or more space separated options that take one of two
      # forms:
      #
      # 1. name
      # 2. name=value
      SYNTAX = /^([a-zA-Z0-9.+#-]+)((\s+\w+(=\w+)?)*)$/

      def initialize(tag_name, markup, tokens)
        super
        puts("\n-> initialize " + markup)

        @inline = true
        @link = false
        @url = "#{Digest::MD5.hexdigest(Time.now.to_s)}.gv"
        @opts = ""
        @class = ""
        @style = ""
        @graphviz_dir = GRAPHVIZ_DIR

        @format, @params = markup.strip.split(' ', 2);
        @tag_name = tag_name
        @layout = "dot"
        #initialize options
        parse_args(markup)

      end

      def read_config(name, site)
        cfg = site.config["graphviz"]
        return if cfg.nil?
        value = cfg[name]
      end

      def split_params(params)
        return params.split(" ").map(&:strip)
      end

      def parse_args(markup)
        args = markup.split(/(\w+=".*")|(\w+=.+)/).select {|s| !s.strip.empty?}
        p args
        args.each do |arg|
          arg.strip!
          if arg =~ /(\w+)="(.*)"/
            eval("@#{$1} = \'#{$2}\'")
            p "@1:#{$1} = #{$2}"
            next
          end
          if arg =~ /(\w+)=(.+)/
            eval("@#{$1} = \'#{$2}\'")
            p "@2:#{$1} = #{$2}"
            next
          end
        end
      end

      def render(context)
      #initialize options
        site = context.registers[:site]
        value = read_config("destination", site)

        @graphviz_dir = value if !value.nil?

       puts("\n=> render")
        folder = File.join(site.source, @graphviz_dir) #dest
        FileUtils.mkdir_p(folder)

        puts("\tfolder -> "+folder.to_s)
          puts("\tinline -> #{@inline}")
          puts("\tlink -> #{@link}")
          puts("\turl -> #{@url}")
          puts("\tlayout -> #{@layout}")
          puts("\tformat -> #{@format}")

        non_markdown = /(&amp|&lt|&nbsp|&quot|&gt|<\/p>|<\/h.>)/m

        # preprocess text
        code = super

        svg = ""
        inputfile = nil

        @url = "#{Digest::MD5.hexdigest(code)}.gv"
        svg = generate_graph_from_content(context, code, folder, inputfile)
        output = wrap_with_div(svg)

        output
        #output trigger last stdout is what gets display
      end

      def blank?
        false
      end

      def generate_graph_from_content(context, code, folder, inputfile)
        site = context.registers[:site]
        filename = File.basename(@url, ".gv") + "." + @format
        output = File.join(@graphviz_dir, filename)
        unless File.exist?(output) then
          destination = File.join(folder, filename).strip
          dot_cmd = "dot -K#{@layout} -T#{@format} -o #{destination} #{@opts} #{inputfile}"
          run_dot_cmd(dot_cmd, code)
          puts("\n output =" + output)
        end
        # Add the file to the list of static files for the final copy once generated
        st_file = Jekyll::StaticFile.new(site, site.source, @graphviz_dir, filename)#@graphviz_dir, filename)
        site.static_files << st_file

        if @style.empty? or @style.nil?
          @style = ""
        else
          @style = %[style="#{@style}"]
        end

        return "<img #{@style} src='#{output}'>"
      end

      def run_dot_cmd(dot_cmd,code)
        puts("\tdot_cmd -> "+dot_cmd)
        Open3.popen3( dot_cmd ) do |stdin, stdout, stderr, wait_thr|
          stdout.binmode
          stdin.print(code)
          stdin.close

          err = stderr.read
          if not (err.nil? || err.strip.empty?)
            raise "Error from #{dot_cmd}:\n#{err}"
          end

          svg = stdout.read

          svg.force_encoding('UTF-8')
          exit_status = wait_thr.value
            unless exit_status.success?
              abort "FAILED !!! #{dot_cmd}"
            end
          return svg
        end
      end


      def remove_declarations(svg)
        svg.sub(/<!DOCTYPE .+?>/im,'').sub(/<\?xml .+?\?>/im,'')
      end

      def remove_xmlns_attrs(svg)
        svg.sub(%[xmlns="http://www.w3.org/2000/svg"], '')
          .sub(%[xmlns:xlink="http://www.w3.org/1999/xlink"], '')
      end

      def wrap_with_div(svg)
        if @class.empty? or @class.nil?
          classNames = %[class="graphviz"]
        else
          classNames = %[class="graphviz #{@class}"]
        end

        if @style.empty? or @style.nil?
          style = ""
        else
          style = %[style="#{@style}"]
        end

        if @caption.nil? or @caption.empty?
          caption = ""
        else
          caption = %[<figcaption>#{@caption}</figcaption>]
        end

        %[<figure #{classNames} #{style} ><div class="graphviz">#{svg}</div>#{caption}</figure>]
      end

    end

  end
end

Liquid::Template.register_tag('graphviz', Jekyll::Graphviz::XGraphvizBlock)
