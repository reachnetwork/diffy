module Diffy
  class HtmlFormatter

    def initialize(diff, options = {})
      @diff = diff
      @options = options
      @old_line_num = 0
      @new_line_num = 0
    end

    def to_s
      if @options[:highlight_words]
        wrap_lines(highlighted_words)
      else
        wrap_lines(@diff.map{|line| wrap_line(ERB::Util.h(line))})
      end
    end

    private

    def wrap_line(line)
      cleaned = clean_line(line)
      case line
      when /^(---|\+\+\+|\\\\)/
        "    <tr class=\"diff-comment\"><td class=\"gutter-old\"></td><td class=\"gutter-new\"></td><td class=\"line\">#{line.chomp}</td></tr>"
      when /^\+/
        @new_line_num += 1
        "    <tr class=\"ins\"><td class=\"gutter-old\"></td><td class=\"gutter-new\">#{@new_line_num}</td><td class=\"line\">#{cleaned}</td></tr>"
      when /^-/
        @old_line_num += 1
        "    <tr class=\"del\"><td class=\"gutter-old\">#{@old_line_num}</td><td class=\"gutter-new\"></td><td class=\"line\">#{cleaned}</td></tr>"
      when /^ /
        @old_line_num += 1
        @new_line_num += 1
        "    <tr class=\"unchanged\"><td class=\"gutter-old\">#{@old_line_num}</td><td class=\"gutter-new\">#{@new_line_num}</td><td class=\"line\">#{cleaned}</td></tr>"
      when /^@@/
        "    <tr class=\"diff-block-info\"><td class=\"gutter-old\"></td><td class=\"gutter-new\"></td><td class=\"line\">#{line.chomp}</td></tr>"
      end
    end

    # remove +/- or wrap in html
    def clean_line(line)
      if @options[:include_plus_and_minus_in_html]
        line.sub(/^(.)/, '<span class="symbol">\1</span>')
      else
        line.sub(/^./, '')
      end.chomp
    end

    def wrap_lines(lines)
      if lines.empty?
        %'<div class="diff"></div>'
      else
        %'<div class="diff" data-old-gutter="#{@old_line_num.to_s.length}" data-new-gutter="#{@new_line_num.to_s.length}">\n  <table>\n#{lines.join("\n")}\n  </table>\n</div>\n'
      end
    end

    def highlighted_words
      chunks = @diff.each_chunk.
        reject{|c| c == '\ No newline at end of file'"\n"}

      processed = []
      lines = chunks.each_with_index.map do |chunk1, index|
        next if processed.include? index
        processed << index
        chunk1 = chunk1
        chunk2 = chunks[index + 1]
        if not chunk2
          next ERB::Util.h(chunk1)
        end

        dir1 = chunk1.each_char.first
        dir2 = chunk2.each_char.first
        case [dir1, dir2]
        when ['-', '+']
          if chunk1.each_char.take(3).join("") =~ /^(---|\+\+\+|\\\\)/ and
              chunk2.each_char.take(3).join("") =~ /^(---|\+\+\+|\\\\)/
            ERB::Util.h(chunk1)
          else
            line_diff = Diffy::Diff.new(
                                        split_characters(chunk1),
                                        split_characters(chunk2),
                                        Diffy::Diff::ORIGINAL_DEFAULT_OPTIONS
                                        )
            hi1 = reconstruct_characters(line_diff, '-')
            hi2 = reconstruct_characters(line_diff, '+')
            processed << (index + 1)
            [hi1, hi2]
          end
        else
          ERB::Util.h(chunk1)
        end
      end.flatten
      lines.map{|line| line.each_line.map(&:chomp).to_a if line }.flatten.compact.
        map{|line|wrap_line(line) }.compact
    end

    def split_characters(chunk)
      chunk.gsub(/^./, '').each_line.map do |line|
        if @options[:ignore_crlf]
          (line.chomp.split('') + ['\n']).map{|chr| ERB::Util.h(chr) }
        else
          chars = line.sub(/([\r\n]$)/, '').split('')
          # add escaped newlines
          chars << '\n'
          chars.map{|chr| ERB::Util.h(chr) }
        end
      end.flatten.join("\n") + "\n"
    end

    def reconstruct_characters(line_diff, type)
      enum = line_diff.each_chunk.to_a
      enum.each_with_index.map do |l, i|
        re = /(^|\\n)#{Regexp.escape(type)}/
        case l
        when re
          highlight(l)
        when /^ /
          if i > 1 and enum[i+1] and l.each_line.to_a.size < 4
            highlight(l)
          else
            l.gsub(/^./, '').gsub("\n", '').
              gsub('\r', "\r").gsub('\n', "\n")
          end
        end
      end.join('').split("\n").map do |l|
        type + l.gsub('</strong><strong>' , '')
      end
    end

    def highlight(lines)
      "<strong>" +
        lines.
          # strip diff tokens (e.g. +,-,etc.)
          gsub(/(^|\\n)./, '').
          # mark line boundaries from higher level line diff
          # html is all escaped so using brackets should make this safe.
          gsub('\n', '<LINE_BOUNDARY>').
          # join characters back by stripping out newlines
          gsub("\n", '').
          # close and reopen strong tags.  we don't want inline elements
          # spanning block elements which get added later.
          gsub('<LINE_BOUNDARY>',"</strong>\n<strong>") + "</strong>"
    end
  end
end
