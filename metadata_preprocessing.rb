require 'fileutils'
require 'htmlentities'

unless (ENV['TRAVIS_TEST']) == 'true'
  require_relative '../bookmaker/core/header.rb'
  require_relative '../utilities/oraclequery.rb'
  require_relative '../utilities/isbn_finder.rb'
else
  puts " --- testing mode:  running travis build"
  require_relative './unit_testing/for_travis-bookmaker_submodule/bookmaker/core/header.rb'
end


# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

project_dir = Bkmkr::Project.input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].pop.to_s.split("_").shift

stage_dir = Bkmkr::Project.input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].pop.to_s.split("_").pop

imprint_json = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "imprints.json")

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")

xml_file = File.join(Bkmkr::Paths.project_tmp_dir, "#{Bkmkr::Project.filename}.xml")

title_js = File.join(Bkmkr::Paths.core_dir, "htmlmaker", "title.js")

# ---------------------- METHODS

def readFile(file, logkey='')
	filecontents = File.read(file)
	return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def findBookISBNs_metadataPreprocessing(logkey='')
  pisbn, eisbn, allworks = findBookISBNs(Bkmkr::Paths.outputtmp_html, Bkmkr::Project.filename)
  return pisbn, eisbn, allworks
rescue => logstring
  return '','',''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def findTitlepageImages(allimg, finalimg, logkey='')
  #get images matching name from dir
  etparr1 = Dir[allimg].select { |f| f.include?('epubtitlepage.')}
  ptparr1 = Dir[allimg].select { |f| f.include?('titlepage.')}
  etparr2 = Dir[finalimg].select { |f| f.include?('epubtitlepage.')}
  ptparr2 = Dir[finalimg].select { |f| f.include?('titlepage.')}

  #find epubtitlepage image matching name exactly, in order of precedence:
  # (files named epubtitlepage > new submittedimage > images from previous runs)
  if etparr1.any?
    epubtitlepage = etparr1.find { |e| /[\/|\\]epubtitlepage\./ =~ e }
  elsif etparr2.any?
    epubtitlepage = etparr2.find { |e| /[\/|\\]epubtitlepage\./ =~ e }
  elsif ptparr1.any?
    epubtitlepage = ptparr1.find { |e| /[\/|\\]titlepage\./ =~ e }
  elsif ptparr2.any?
    epubtitlepage = ptparr2.find { |e| /[\/|\\]titlepage\./ =~ e }
  else
    epubtitlepage = ""
  end

  # find podtitlepage matching name 'titlepage' exactly, prefer submitted images to those from prior runs
  if ptparr1.any?
    podtitlepage = ptparr1.find { |e| /[\/|\\]titlepage\./ =~ e }
  elsif ptparr2.any?
    podtitlepage = ptparr2.find { |e| /[\/|\\]titlepage\./ =~ e }
  else
    podtitlepage = ""
  end

  return epubtitlepage, podtitlepage
rescue => logstring
  return '',''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def findFrontCover(pisbn, allimg, allworks, logkey='')
  coverdir = File.join(Bkmkr::Paths.done_dir, pisbn, "cover")
  allcover = File.join(coverdir, "*")
  # first find any cover files in the submitted images dir
  fcarr1 = Dir[allimg].select { |f| f.include?('_FC.')}

  # now narrow down the list of found covers to only include files that match the book isbns
  fcarr2 = []
  if fcarr1.any?
    fcarr1.each do |c|
      cisbn = c.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop.split("_").shift
      if allworks.include?(cisbn)
        fcarr2.push(c)
      end
    end
  end

  # now let's see if there are any old covers in the done dir
  if File.exist?(coverdir)
    fcarr3 = Dir[allcover].select { |f| f.include?('_FC.')}
  else
    fcarr3 = []
  end

  # priority is given to any newly submitted cover images
  if fcarr2.any?
    mycover = fcarr2.max_by(&File.method(:ctime))
    frontcover = mycover.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
  elsif fcarr3.any?
    mycover = fcarr3.max_by(&File.method(:ctime))
    frontcover = mycover.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
  else
    frontcover = ""
  end

  return frontcover
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def databaseLookup(pisbn, eisbn, logkey='')
  # validate 13 digit isbn
  test_pisbn_chars = pisbn.scan(/\d\d\d\d\d\d\d\d\d\d\d\d\d/)
  test_pisbn_length = pisbn.split(%r{\s*})
  test_eisbn_chars = eisbn.scan(/\d\d\d\d\d\d\d\d\d\d\d\d\d/)
  test_eisbn_length = eisbn.split(%r{\s*})

  # get a hash of edition information, attempt pisbn first, use eisbn as backup
  if test_pisbn_length.length == 13 and test_pisbn_chars.length != 0
    thissql = exactSearchSingleKey(pisbn, "EDITION_EAN")
    myhash = runQuery(thissql)
    if myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] and test_eisbn_length.length == 13 and test_eisbn_chars.length != 0
      thissql = exactSearchSingleKey(eisbn, "EDITION_EAN")
      myhash = runQuery(thissql)
    end
  elsif test_eisbn_length.length == 13 and test_eisbn_chars.length != 0
    thissql = exactSearchSingleKey(eisbn, "EDITION_EAN")
    myhash = runQuery(thissql)
  else
    myhash = {}
  end

  return myhash
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setAuthorInfo(myhash, html_contents, logkey='')
  # get meta info from html if it exists
  metabookauthor = html_contents.match(/(<meta name="author" content=")(.*?)("\/>)/i)
  # Finding author name(s)
  if !metabookauthor.nil?
    authorname = HTMLEntities.new.decode(metabookauthor[2]).encode('utf-8')
  elsif myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash['book']['WORK_COVERAUTHOR'].nil? or myhash['book']['WORK_COVERAUTHOR'].empty? or !myhash['book']['WORK_COVERAUTHOR']
    authorname = html_contents.scan(/<p[^>]*?class="TitlepageAuthorNameau".*?>(.*?)<.*?>/).join(", ")
    authorname = HTMLEntities.new.decode(authorname).encode('utf-8')
  else
    authorname = myhash['book']['WORK_COVERAUTHOR']
    authorname = authorname.encode('utf-8')
  end
  return authorname
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setBookTitle(myhash, html_contents, logkey='')
  # get meta info from html if it exists
  metabooktitle = html_contents.match(/(<meta name="title" content=")(.*?)("\/>)/i)
  # Finding book title
  if !metabooktitle.nil?
    booktitle = HTMLEntities.new.decode(metabooktitle[2]).encode('utf-8')
  elsif myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash["book"]["WORK_COVERTITLE"].nil? or myhash["book"]["WORK_COVERTITLE"].empty? or !myhash["book"]["WORK_COVERTITLE"]
    booktitle = html_contents.scan(/<h1[^<]*?class="TitlepageBookTitletit".*?>(.*?)<.*?>/).join(", ")
    booktitle = HTMLEntities.new.decode(booktitle).encode('utf-8')
  else
    booktitle = myhash["book"]["WORK_COVERTITLE"]
    booktitle = booktitle.encode('utf-8')
  end
  return booktitle
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setBookSubtitle(myhash, html_contents, logkey='')
  # get meta info from html if it exists
  metabooksubtitle = html_contents.match(/(<meta name="subtitle" content=")(.*?)("\/>)/i)
  # Finding book subtitle
  if !metabooksubtitle.nil?
    booksubtitle = HTMLEntities.new.decode(metabooksubtitle[2]).encode('utf-8')
  elsif myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash["book"]["WORK_SUBTITLE"].nil? or myhash["book"]["WORK_SUBTITLE"].empty? or !myhash["book"]["WORK_SUBTITLE"]
    booksubtitle = html_contents.scan(/<p[^<]*?class="TitlepageBookSubtitlestit".*?>(.*?)<.*?>/).join(", ")
    booksubtitle = HTMLEntities.new.decode(booksubtitle).encode('utf-8')
  else
    booksubtitle = myhash["book"]["WORK_SUBTITLE"]
    booksubtitle = booksubtitle.encode('utf-8')
  end
  return booksubtitle
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# find the publisher imprint based on the imprints.json database
# only called (by the following method) if biblio data & html metadata unavailable
def getImprint(projectdir, json, logkey='')
  data_hash = Mcmlln::Tools.readjson(json)
  arr = []
  # loop through each json record to see if imprint name matches formalname
  data_hash['imprints'].each do |p|
    if p['shortname'] == projectdir
      arr << p['formalname']
    end
  end
  # in case of multiples, grab just the last entry and return it
  if arr.nil? or arr.empty?
    path = "Macmillan"
  else
    path = arr.pop
  end
  return path
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setImprint(myhash, project_dir, imprint_json, logkey='')
  # get meta info from html if it exists
  metaimprint = File.read(Bkmkr::Paths.outputtmp_html).match(/(<meta name="imprint" content=")(.*?)("\/>)/i)
  # Finding imprint name
  # imprint = File.read(Bkmkr::Paths.outputtmp_html).scan(/<p class="TitlepageImprintLineimp">.*?</).to_s.gsub(/\["<p class=\\"TitlepageImprintLineimp\\">/,"").gsub(/"\]/,"").gsub(/</,"")
  # Manually populating for now, until we get the DB set up
  if !metaimprint.nil?
    imprint = HTMLEntities.new.decode(metaimprint[2])
  elsif myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash["book"]["IMPRINT_DESC"].nil? or myhash["book"]["IMPRINT_DESC"].empty? or !myhash["book"]["IMPRINT_DESC"]
    imprint = getImprint(project_dir, imprint_json, 'get_imprint_from_json')
  else
    imprint = myhash["book"]["IMPRINT_DESC"]
    imprint = imprint.encode('utf-8')
  end
  return imprint
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setPublisher(myhash, imprint, logkey='')
  # get meta info from html if it exists
  metapublisher = File.read(Bkmkr::Paths.outputtmp_html).match(/(<meta name="publisher" content=")(.*?)("\/>)/i)
  # Finding publisher
  if !metapublisher.nil?
    publisher = HTMLEntities.new.decode(metapublisher[2])
  else
    publisher = imprint
  end
  return publisher
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setTemplate(myhash, logkey='')
  # get meta info from html if it exists
  metatemplate = File.read(Bkmkr::Paths.outputtmp_html).match(/(<meta name="template" content=")(.*?)("\/>)/i)
  if !metatemplate.nil?
    template = HTMLEntities.new.decode(metatemplate[2])
    logstring = "Design template: #{template}"
  else
    template = ""
    logstring = "Design template: default"
  end
  puts logstring
  return metatemplate, template
rescue => logstring
  return '',''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# determine directory name for assets e.g. css, js, logo images
def getResourceDir(imprint, json, logkey='')
  data_hash = Mcmlln::Tools.readjson(json)
  arr = []
  # loop through each json record to see if imprint name matches formalname
  data_hash['imprints'].each do |p|
    if p['formalname'] == imprint
      arr << p['shortname']
    end
  end
  # in case of multiples, grab just the last entry and return it
  if arr.nil? or arr.empty?
    path = "generic"
  else
    path = arr.pop
  end
  return path
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setPdfCssFile(metatemplate, template, pdf_css_dir, stage_dir, resource_dir, logkey='')
  if !metatemplate.nil? and File.file?("#{pdf_css_dir}/#{resource_dir}/#{template}.css")
    pdf_css_file = "#{pdf_css_dir}/#{resource_dir}/#{template}.css"
  elsif File.file?("#{pdf_css_dir}/#{resource_dir}/#{stage_dir}.css")
    pdf_css_file = "#{pdf_css_dir}/#{resource_dir}/#{stage_dir}.css"
  elsif File.file?("#{pdf_css_dir}/#{resource_dir}/pdf.css")
    pdf_css_file = "#{pdf_css_dir}/#{resource_dir}/pdf.css"
  else
    pdf_css_file = "#{pdf_css_dir}/torDOTcom/pdf.css"
  end
  return pdf_css_file
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setEpubCssFile(metatemplate, template, epub_css_dir, stage_dir, resource_dir, logkey='')
  if !metatemplate.nil? and File.file?("#{epub_css_dir}/#{resource_dir}/#{template}.css")
    epub_css_file = "#{epub_css_dir}/#{resource_dir}/#{template}.css"
  elsif File.file?("#{epub_css_dir}/#{resource_dir}/#{stage_dir}.css")
    epub_css_file = "#{epub_css_dir}/#{resource_dir}/#{stage_dir}.css"
  elsif File.file?("#{epub_css_dir}/#{resource_dir}/epub.css")
    epub_css_file = "#{epub_css_dir}/#{resource_dir}/epub.css"
  else
    epub_css_file = "#{epub_css_dir}/generic/epub.css"
  end
  return epub_css_file
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# get JS file for pdf and edit title info to match our book
def setupPdfJSfile(proj_js_file, fallback_js_file, pdf_js_file, booktitle, authorname, logkey='')
  if File.file?(proj_js_file)
    js_file = proj_js_file
  elsif File.file?(fallback_js_file)
    js_file = fallback_js_file
  else
    js_file = " "
  end
  if File.file?(js_file)
    FileUtils.cp(js_file, pdf_js_file)
    jscontents = File.read(pdf_js_file).gsub(/BKMKRINSERTBKTITLE/,"\"#{booktitle}\"").gsub(/BKMKRINSERTBKAUTHOR/,"\"#{authorname}\"")
    File.open(pdf_js_file, 'w') do |output|
      output.write jscontents
    end
  else
    logstring = 'neither proj_js nor fallback_js_file found'
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setTOCvalFromHTML(logkey='')
  if Mcmlln::Tools.checkFileExist(Bkmkr::Paths.outputtmp_html)
    check_toc = File.read(Bkmkr::Paths.outputtmp_html).scan(/class=".*?texttoc.*?"/)
    if check_toc.any?
      toc_value = "true"
    else
      toc_value = "false"
    end
  else
    toc_value = "false"
  end
  return toc_value
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def writeConfigJson(hash, json, logkey='')
  Mcmlln::Tools.write_json(hash, json)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping Bkmkr::Tools.runnode in a new method for this script; to return a result for json_logfile
def localRunNode(jsfile, args, logkey='')
	Bkmkr::Tools.runnode(jsfile, args)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# ---------------------- PROCESSES
# for logging purposes
puts "RUNNING METADATA_PREPROCESSING"

pisbn, eisbn, allworks = findBookISBNs_metadataPreprocessing('find_book_ISBNs')

allimg = File.join(Bkmkr::Paths.submitted_images, "*")
finalimg = File.join(Bkmkr::Paths.done_dir, pisbn, "images", "*")

# find titlepage images
epubtitlepage, podtitlepage = findTitlepageImages(allimg, finalimg, 'find_titlepage_images')
@log_hash['epubtitlepage'] = epubtitlepage
@log_hash['podtitlepage'] = podtitlepage

# Find front cover
frontcover = findFrontCover(pisbn, allimg, allworks, 'find_frontcover')
@log_hash['frontcover'] = frontcover

# connect to DB for all other metadata
myhash = databaseLookup(pisbn, eisbn, 'get_Biblio_metadata')

#feedback for plaintext & json log
unless myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book']
  logstring = "DB Connection SUCCESS: Found a book record"
else
  logstring = "No DB record found; falling back to manuscript fields"
end
puts logstring
@log_hash['query_status'] = logstring

# read in html for use getting title metadata
html_contents = readFile(Bkmkr::Paths.outputtmp_html, 'get_outputtmp_html_contents')

# Setting metadata vars for config.json:
# Prioritize metainfo from html, then edition info from biblio, then scan html for tagged data
authorname = setAuthorInfo(myhash, html_contents, 'set_author_info')
@log_hash['author_name'] = authorname

booktitle = setBookTitle(myhash, html_contents, 'set_book_title')
@log_hash['book_title'] = booktitle

booksubtitle = setBookSubtitle(myhash, html_contents, 'set_book_subtitle')
@log_hash['book_subtitle'] = booksubtitle

imprint = setImprint(myhash, project_dir, imprint_json, 'set_imprint')
@log_hash['imprint'] = imprint

publisher = setPublisher(myhash, imprint, 'set_publisher')
@log_hash['publisher'] = publisher

metatemplate, template = setTemplate(myhash, 'set_template')


# print and epub css files
epub_css_dir = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "epubmaker", "css")
pdf_css_dir = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "css")

resource_dir = getResourceDir(imprint, imprint_json, 'get_resource_dir')
@log_hash['resource_dir'] = resource_dir
puts "Resource dir: #{resource_dir}"

pdf_css_file = setPdfCssFile(metatemplate, template, pdf_css_dir, stage_dir, resource_dir, 'set_pdf_CSS_file')
@log_hash['pdf_css_file'] = pdf_css_file
puts "PDF CSS file: #{pdf_css_file}"

epub_css_file = setEpubCssFile(metatemplate, template, epub_css_dir, stage_dir, resource_dir, 'set_epub_CSS_file')
@log_hash['epub_css_file'] = epub_css_file
puts "Epub CSS file: #{epub_css_file}"


proj_js_file = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "scripts", resource_dir, "pdf.js")
fallback_js_file = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "scripts", "torDOTcom", "pdf.js")
pdf_js_file = File.join(Bkmkr::Paths.project_tmp_dir, "pdf.js")

# get JS file for pdf and edit title info to match our book
setupPdfJSfile(proj_js_file, fallback_js_file, pdf_js_file, booktitle, authorname, 'setup_pdf_JS_file')

#check the xml in tmp for toc_value
toc_value = setTOCvalFromHTML('set_TOC_value_From_xml')

# Generating the json metadata

if stage_dir == "firstpass" or stage_dir == "egalley" or stage_dir == "galley" or stage_dir == "arc-sans" or stage_dir == "arc-serif" or stage_dir == "RBM" or stage_dir == "test" and frontcover.empty?
  frontcoverval = "#{pisbn}_FC.jpg"
else
  frontcoverval = frontcover
end

datahash = {}
datahash.merge!(title: booktitle)
datahash.merge!(subtitle: booksubtitle)
datahash.merge!(author: authorname)
datahash.merge!(productid: pisbn)
datahash.merge!(printid: pisbn)
datahash.merge!(ebookid: eisbn)
datahash.merge!(imprint: imprint)
datahash.merge!(publisher: publisher)
datahash.merge!(project: project_dir)
datahash.merge!(stage: stage_dir)
datahash.merge!(resourcedir: resource_dir)
datahash.merge!(printcss: pdf_css_file)
datahash.merge!(printjs: pdf_js_file)
datahash.merge!(ebookcss: epub_css_file)
datahash.merge!(pod_toc: toc_value)
datahash.merge!(frontcover: frontcoverval)
unless epubtitlepage.nil?
  datahash.merge!(epubtitlepage: epubtitlepage)
end
unless podtitlepage.nil?
  datahash.merge!(podtitlepage: podtitlepage)
end

# write to config.json file
writeConfigJson(datahash, configfile, 'write_config_jsonfile')

# set html title to match JSON
if booktitle.nil? or booktitle.empty? or !booktitle
  booktitle = Bkmkr::Project.filename
end

# replace html book title with ours
localRunNode(title_js, "#{Bkmkr::Paths.outputtmp_html} \"#{booktitle}\"", 'run_node_title_js')

# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
