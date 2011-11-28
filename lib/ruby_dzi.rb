# Ruby Dzi generator
# A fork from Deep Zoom Slicer project
#
# Ruby Dzi slices images and generates a dzi file that is compatible with DeepZoom or Seadragon
#
# Requirements: ImageMagick binaries installed (tested with ImageMagick 6.6.4-5)
#
# Plain magick implementation: Panter llc (http://www.panter.ch)
#
# Forked from: Marc Vitalis <marc.vitalis@live.com> 
#
# Original Author:: MESO Web Scapes (www.meso.net)
# By:: Sascha Hanssen <hanssen@meso.net>
# License:: MPL 1.1/GPL 3/LGPL 3
#
# Software distributed under the License is distributed on an "AS IS" basis,
# WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
# for the specific language governing rights and limitations under the
# License.
#
require 'rubygems'
require 'tmpdir'
require 'open-uri'

class RubyDzi

  attr_accessor :image_path, :name, :format, :output_ext, :quality, :dir,
                :tile_size, :strip, :profile_path, :filter

  def initialize(image_path)

    #set defaults
    @quality = 98
    @dir = '.'
    @tile_size = 256
    @output_ext = 'dzi'
    @profile_path = nil
    @strip = true
    @filter = nil

    @image_path = image_path

  end

  def generate!(name, format = 'jpg')
    @name = name
    @format = format
    
    @levels_root_dir     = File.join(@dir, @name + '_files')
    @xml_descriptor_path = File.join(@dir, @name + '.' + @output_ext)

    orig_width, orig_height = dimensions(@image_path)

    remove_files!
    Dir.mktmpdir do |tmp_dir|

      work_path = create_working_copy(tmp_dir, @image_path)

      # iterate over all levels (= zoom stages) and create slices
      max_level(orig_width, orig_height).downto(0) do |level|
        current_level_dir = File.join(@levels_root_dir, level.to_s)
        FileUtils.mkdir_p(current_level_dir)
        slice_image(work_path, current_level_dir, format, tile_size)
        work_path = halve(work_path)
      end

    end

    # generate xml descriptor and write file
    write_xml_descriptor(@xml_descriptor_path,
                         :tile_size => @tile_size,
                         :format    => @format,
                         :width     => orig_width,
                         :height    => orig_height)
  end

  def remove_files!
    files_existed = (File.file?(@xml_descriptor_path) or File.directory?(@levels_root_dir))

    File.delete @xml_descriptor_path if File.file? @xml_descriptor_path
    FileUtils.remove_dir @levels_root_dir if File.directory? @levels_root_dir

    return files_existed
  end

protected

  def max_level(width, height)
    return (Math.log([width, height].max) / Math.log(2)).ceil
  end

  def write_xml_descriptor(path, attr)
    attr = { :xmlns => 'http://schemas.microsoft.com/deepzoom/2008' }.merge attr
    
    xml = "<?xml version='1.0' encoding='UTF-8'?>" + 
          "<Image TileSize='#{attr[:tile_size]}' Overlap='0' " + 
            "Format='#{attr[:format]}' xmlns='#{attr[:xmlns]}'>" + 
          "<Size Width='#{attr[:width]}' Height='#{attr[:height]}'/>" + 
          "</Image>"

    open(path, "w") { |file| file.puts(xml) }
  end

  def split_to_filename_and_extension(path)
    extension = File.extname(path).gsub('.', '')
    filename  = File.basename(path, '.' + extension) 
    return filename, extension
  end 

  def valid_url?(urlStr)
    url = URI.parse(urlStr)
    Net::HTTP.start(url.host, url.port) do |http|
      return http.head(url.request_uri).code == "200"
    end
  end

  # copies image into tmp_dir and applies profiles
  def create_working_copy(tmp_dir, path)
    work_path = File.join(tmp_dir, File.basename(path))
    cmd = ['convert']
    cmd << "-filter #{@filter}" if @filter
    cmd << "'#{path}[0]'"
    cmd << '-strip' if @strip
    cmd << "-profile '#{@profile_path}'" if @profile_path
    cmd << "-quality #{@quality}" if @quality
    cmd << "'#{work_path}'"
    execute cmd.join(' ')
    work_path
  end
  
  # returns array of [cols rows]
  def dimensions(path)
    cmd = "identify -format '%w %h' '#{path}[0]'"
    answer = execute(cmd)
    parts = answer.split(/\s/)
    parts.map { |p| p.to_i }
  end

  # replaces the given image with one that is half the size
  def halve(path)
    cmd = "mogrify -resize '50%' '#{path}'"
    answer = execute(cmd)
    path
  end


  # use magick to slice the image given by workpath into tiles
  # the filenames are generated according to the deepzoom spec using magick's
  # fx calculations.
  # this is more or less the example given at
  # http://www.imagemagick.org/Usage/crop/#crop_tile
  def slice_image(work_path, current_level_dir, format, tile_size)
    cmd = "convert #{work_path} +repage +gravity -crop #{tile_size}x#{tile_size} " +
          "-set 'filename:tile' '%[fx:page.x/#{tile_size}]_%[fx:page.y/#{tile_size}]' " +
          File.join(current_level_dir, "%[filename:tile].#{format}")
    execute cmd
  end

  def execute(cmd)
    # puts "#{cmd}"
    answer = `#{cmd}`
    if $?.to_i == 0
      return answer
    else
      raise "Could not run [#{cmd}]. Returncode was: #{$?}"
    end
  end

end
