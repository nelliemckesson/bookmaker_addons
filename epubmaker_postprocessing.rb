require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately after to epubmaker

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")
file = File.read(configfile)
data_hash = JSON.parse(file)

OEBPS_dir = File.join(Bkmkr::Paths.project_tmp_dir, "OEBPS")
zipepub_py = File.join(Bkmkr::Paths.core_dir, "epubmaker", "zipepub.py")

# Add links back to TOC to chapter heads
searchdir = File.join(OEBPS_dir, "ch[0-9][0-9]*.html")
chapfiles = Dir.glob(searchdir)

chapfiles.each do |c|
	replace = File.read(c).gsub(/(<section data-type="chapter".*?><h1.*?>)(.*?)(<\/h1>)/, "\\1<a href=\"toc01.html\">\\2</a>\\3")
	File.open(c, "w") {|file| file.puts replace}
end

# fix toc entry in ncx
# fix title page text in ncx
ncxcontents = File.read("#{OEBPS_dir}/toc.ncx")
replace = ncxcontents.gsub(/<navLabel><text\/><\/navLabel><content src="toc/,"<navLabel><text>Contents</text><\/navLabel><content src=\"toc").gsub(/(<navLabel><text>)([a-zA-Z\s]*?)(<\/text><\/navLabel><content src="titlepage)/,"\\1Title Page\\3")
File.open("#{OEBPS_dir}/toc.ncx", "w") {|file| file.puts replace}

# hide toc entry in html toc
# fix title page text in html toc
htmlcontents = File.read("#{OEBPS_dir}/toc01.html")
copyright_li = htmlcontents.match(/<li data-type="copyright-page".*?<\/li>/)
replace = htmlcontents.gsub(/(titlepage01.html#.*?">)(.*?)(<\/a>)/,"\\1Title Page\\3").gsub(/(<li data-type="copyright-page">)/,"<li data-type=\"toc\" class=\"Nonprinting\"><a href=\"toc01.html\">Contents</a></li>\\1").gsub(/(<li data-type="preface")(><a href=".*">Newsletter Sign-up)/,"\\1 class=\"Nonprinting\"\\2").gsub(/<li data-type="cover"><a href="\#bookcover01"\/>/,"<li data-type=\"cover\" class=\"Nonprinting\"><a href=\"cover.html\">Cover</a>")
File.open("#{OEBPS_dir}/toc01.html", "w") {|file| file.puts replace}

# add toc to text flow
opfcontents = File.read("#{OEBPS_dir}/content.opf")
copyright_tag = opfcontents.scan(/<itemref idref="copyright-page/)
tocid = opfcontents.match(/(id=")(toc-.*?)(")/)[2]
toc_tag = opfcontents.match(/<itemref idref="toc-.*?"\/>/)
if copyright_tag.any?
	replace = opfcontents.gsub(/#{toc_tag}/,"").gsub(/(<itemref idref="copyright-page)/,"#{toc_tag}\\1")
else 
	replace = opfcontents.gsub(/#{toc_tag}/,"").gsub(/(<\/spine)/,"#{toc_tag}\\1")
end
File.open("#{OEBPS_dir}/content.opf", "w") {|file| file.puts replace}

# remove titlepage.jpg if exists
podtitlepagetmp = File.join(OEBPS_dir, "titlepage.jpg")
if File.file?(podtitlepagetmp)
	FileUtils.rm(podtitlepagetmp)
end

csfilename = "#{Metadata.eisbn}_EPUB"

# zip epub
Bkmkr::Tools.runpython(zipepub_py, "#{csfilename}.epub #{Bkmkr::Paths.project_tmp_dir}")

FileUtils.cp("#{Bkmkr::Paths.project_tmp_dir}/#{csfilename}.epub", "#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}")

# Renames final epub for firstpass
if data_hash['stage'].include? "egalley" or data_hash['stage'].include? "firstpass"
  FileUtils.mv("#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/#{Metadata.eisbn}_EPUB.epub", "#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/#{Metadata.eisbn}_EPUBfirstpass.epub")
end