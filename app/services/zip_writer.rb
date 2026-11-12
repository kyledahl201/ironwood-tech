require "zlib"

# Builds a small .zip in memory from [name, text] pairs, with nothing but
# Ruby's standard library. Enough for a handful of Markdown files.
class ZipWriter
  DOS_TIME = 0          # midnight
  DOS_DATE = (46 << 9) | (1 << 5) | 1 # 2026-01-01: a fixed date keeps the file the same on every build
  UTF8_NAMES = 0x0800

  def self.build(entries)
    body = +"".b
    directory = +"".b
    entries.each do |name, text|
      name = name.b
      data = text.to_s.b
      packed = Zlib::Deflate.new(Zlib::BEST_COMPRESSION, -Zlib::MAX_WBITS).deflate(data, Zlib::FINISH)
      fields = [ 20, UTF8_NAMES, 8, DOS_TIME, DOS_DATE, Zlib.crc32(data), packed.bytesize, data.bytesize, name.bytesize, 0 ]
      offset = body.bytesize
      body << [ 0x04034b50, *fields ].pack("VvvvvvVVVvv") << name << packed
      directory << [ 0x02014b50, 20, *fields, 0, 0, 0, 0, offset ].pack("VvvvvvvVVVvvvvvVV") << name
    end
    body + directory + [ 0x06054b50, 0, 0, entries.size, entries.size, directory.bytesize, body.bytesize, 0 ].pack("VvvvvVVv")
  end
end
