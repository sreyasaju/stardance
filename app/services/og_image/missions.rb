module OgImage
  # Minimal mission OG image: uses the mission's banner attachment when
  # present, otherwise renders a placeholder with the mission name. Full
  # art direction is deferred — this exists so the `<meta og:image>` link in
  # missions/show resolves to a 1200×630 PNG instead of 404'ing on social
  # previews.
  class Missions < Base
    PREVIEWS = {
      "default" => -> { new(sample_mission) }
    }.freeze

    class << self
      def sample_mission
        OpenStruct.new(name: "Wario-Ware Clone", banner: nil)
      end
    end

    def initialize(mission)
      @mission = mission
      super()
    end

    def render
      if @mission.banner&.attached?
        download_attachment(@mission.banner) || render_placeholder
      else
        render_placeholder
      end
    end

    private

    def render_placeholder
      path = temp_path("mission_bg")
      MiniMagick::Tool.new("convert") do |convert|
        convert.size("#{WIDTH}x#{HEIGHT}")
        convert << "xc:#0d0a26"
        convert.gravity("center")
        convert.fill("#ffffff")
        convert.font(default_font_path)
        convert.pointsize(96)
        convert.draw("text 0,0 '#{escape_text(truncate_text(@mission.name, 40))}'")
        convert << path
      end
      @image = MiniMagick::Image.open(path)
      @image
    end

    def download_attachment(attachment)
      tempfile = Tempfile.new([ "mission_banner", ".bin" ])
      tempfile.binmode
      tempfile.write(attachment.download)
      tempfile.rewind
      @image = MiniMagick::Image.open(tempfile.path)
      @image.resize("#{WIDTH}x#{HEIGHT}^")
      @image.gravity("center")
      @image.crop("#{WIDTH}x#{HEIGHT}+0+0")
      @image.repage("+0+0")
      @image
    rescue StandardError => e
      Rails.logger.warn("OgImage::Missions: Failed to use banner: #{e.message}")
      nil
    ensure
      tempfile&.close
      tempfile&.unlink
    end

    def default_font_path
      # Mirrors fallback used elsewhere in OgImage::Base.
      "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    end
  end
end
