# encoding: utf-8

require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'
require_relative '../utilities/ftp_functions.rb'

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

# full path to the image error file
image_error = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "IMAGE_ERROR.txt")

# specs for image resizing
maxheight = 5.5
maxwidth = 3.5
grid = 16.0

# ftp url
ftpdirext = "http://www.macmillan.tools.vhost.zerolag.com/bookmaker/bookmakerimg/#{Metadata.project_dir}_#{Metadata.stage_dir}/#{Metadata.pisbn}"
ftpdirint = "/files/html/bookmaker/bookmakerimg/#{Metadata.project_dir}_#{Metadata.stage_dir}/#{Metadata.pisbn}"

pdftmp_dir = File.join(Bkmkr::Paths.project_tmp_dir_img, "pdftmp")
pdfmaker_dir = File.join(Bkmkr::Paths.core_dir, "pdfmaker")
pdf_tmp_html = File.join(Bkmkr::Paths.project_tmp_dir, "pdf_tmp.html")
assets_dir = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker")
finalimagedir = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "images")

pdfmakerpreprocessingjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "pdfmaker_preprocessing.js")


# ---------------------- METHODS
## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def makeFolder(path, logkey='')
  unless File.exist?(path)
    Dir.mkdir(path)
  else
	 logstring = 'n-a'
	end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def copyFile(src, dest, logkey='')
	Mcmlln::Tools.copyFile(src, dest)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def readHtml(file, logkey='')
	filecontents = File.read(file)
	return filecontents
rescue => logstring
	return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# get and prepare titlepage
def convertTitlepage(podfiletype, podtitlepagearc, podtitlepagetmp, logkey='')
  if podfiletype == "jpg"
    FileUtils.cp(podtitlepagearc, podtitlepagetmp)
    logstring = 'already a jpg, just moved file'
  else
    `convert "#{podtitlepagearc}" "#{podtitlepagetmp}"`
    logstring = "moved and converted (file was #{podfiletype})"
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# gets image conversion specs to fit the images to the grid
def calcImgSizes(res, file, maxheight, maxwidth, grid)
  myres = res.to_f
  myheight = `identify -format "%h" "#{file}"`
  myheight = myheight.to_f
  myheightininches = (myheight / myres)
  mywidth = `identify -format "%w" "#{file}"`
  mywidth = mywidth.to_f
  mywidthininches = (mywidth / myres)
  # if current height or width exceeds max, resize to max, proportionately
  if mywidthininches > maxwidth or myheightininches > maxheight then
    targetheight = maxheight * myres
    targetwidth = maxwidth * myres
    `convert "#{file}" -density #{myres} -resize "#{targetwidth}x#{targetheight}>" -quality 100 "#{file}"`
  end
  myheight = `identify -format "%h" "#{file}"`
  myheight = myheight.to_f
  myheightininches = (myheight / myres)
  mymultiple = ((myheight / myres) * 72.0) / grid
  if mymultiple <= 1
    resizecmd = ""
  else
    newheight = ((mymultiple.floor * grid) / 72.0) * myres
    resizecmd = "-resize \"x#{newheight}\" "
  end
  return resizecmd
rescue => e
  return "error method calcImgSize: #{e}"
end

#if any images are in 'done' dir, grayscale and upload them to macmillan.tools site
def prepDoneDirImages(pdftmp_dir, maxheight, maxwidth, grid, logkey='')
  images = Dir["#{Bkmkr::Paths.project_tmp_dir_img}/*"].select {|f| File.file? f}
  image_count = images.count
  corrupt = []
  processed = []

  if image_count > 0
    FileUtils.cp Dir["#{Bkmkr::Paths.project_tmp_dir_img}/*"].select {|f| test ?f, f}, pdftmp_dir
    pdfimages = Dir.entries(pdftmp_dir).select { |f| !File.directory? f }
    pdfimages.each do |i|
      puts "resizing and grayscaling #{i}"
      pdfimage = File.join(pdftmp_dir, "#{i}")
      if i.include?("fullpage")
        #convert command for ImageMagick should work the same on any platform
        `convert "#{pdfimage}" -colorspace gray "#{pdfimage}"`
        processed << pdfimage
      else
        myres = `identify -format "%y" "#{pdfimage}"`
        if myres.nil? or myres.empty? or !myres
          corrupt << pdfimage
        else
          resize = calcImgSizes(myres, pdfimage, maxheight, maxwidth, grid)
          if !resize.match(/^error/)
            `convert "#{pdfimage}" -density #{myres} #{resize}-quality 100 -colorspace gray "#{pdfimage}"`
          else
            logstring = resize  #log any errors returned from calcImgSizes method
          end
        end
        processed << pdfimage
      end
    end
  else
    logstring = 'n-a (no images in done dir)'
  end

  return image_count, corrupt, processed
rescue => logstring
  return '',[],[]
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def overwriteHtml(path, filecontents, logkey='')
	Mcmlln::Tools.overwriteFile(path, filecontents)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def writeImageErrors(arr, file, logkey='')
  # Writes an error text file in the done\pisbn\ folder that lists all missing image files as stored in the missing array
  if arr.any?
    File.open(file, 'a+') do |output|
      output.puts "IMAGE PROCESSING ERRORS:"
      output.puts "The following images encountered processing errors and may be corrupt:"
      arr.each do |m|
        output.puts m
      end
    end
  else
    logstring = 'n-a'
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def copyFilesinDir(dir, dest, logkey='')
  Mcmlln::Tools.copyAllFiles(dir, dest)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def getFilesinDir(path, logkey='')
	files = Mcmlln::Tools.dirListFiles(path)
	return files
rescue => logstring
	return []
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

#wrapping ftp class method in its own separate method: to write to jsonlog here and leave class methods more general.
def ftpSetupMethod(parentfolder, childfolder, logkey='')
  ftpsetup = Ftpfunctions.createDirs(parentfolder, childfolder)
  return ftpsetup
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

#wrapping ftp class method in its own separate method: to write to jsonlog here and leave class methods more general.
def ftpUpload(ftpdirint, pdftmp_dir, ftplist, logkey='')
  ftpstatus = Ftpfunctions.uploadImg(ftpdirint, pdftmp_dir, ftplist)
  return ftpstatus
rescue => logstring
  return ''
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

# fixes images in html, keep final words and ellipses from breaking
def fixHtmlImageSrcAndKTs(pdf_tmp_html, ftpdirext, logkey='')
  filecontents = File.read(pdf_tmp_html).gsub(/src="images\//,"src=\"#{ftpdirext}/")
                                        .gsub(/([a-zA-Z0-9]?[a-zA-Z0-9]?[a-zA-Z0-9]?\s\. \. \.)/,"<span class=\"bookmakerkeeptogetherkt\">\\0</span>")
                                        .gsub(/(\s)(\w\w\w*?\.)(<\/p>)/,"\\1<span class=\"bookmakerkeeptogetherkt\">\\2</span>\\3")
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end


# fixes em dash breaks (requires UTF 8 encoding)
def fixEmdashes(pdf_tmp_html, logkey='')
  filecontents = File.read(pdf_tmp_html, :encoding=>"UTF-8").gsub(/(.)?(—\??\.?!?”?’?)(.)?/,"\\1\\2&\#8203;\\3")
                                                            .gsub(/(<p class="FrontSalesQuotefsq">“)(A)/,"\\1&\#8202;\\2")
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end


# ---------------------- PROCESSES

# create pdf tmp directory
makeFolder(pdftmp_dir, 'mkdir_pdftmp_dir')

copyFile(Bkmkr::Paths.outputtmp_html, pdf_tmp_html, 'cp_html_to_pdftmp')

readHtml(pdf_tmp_html, 'read_pdfhtml')

# get and prepare titlepage
unless Metadata.podtitlepage == "Unknown"
  puts "found a pod titlepage image"
  @log_hash['get_titlepage'] = "found a pod titlepage image"
  tpfilename = Metadata.podtitlepage.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
  podfiletype = tpfilename.split(".").pop
  podtitlepagearc = File.join(finalimagedir, tpfilename)
  podtitlepagetmp = File.join(Bkmkr::Paths.project_tmp_dir_img, "titlepage_fullpage.jpg")
  # move or (if necessary) convert titlepage
  convertTitlepage(podfiletype, podtitlepagearc, podtitlepagetmp, 'convert_titlepage')
  # insert titlepage image
  filecontents = filecontents.gsub(/(<section data-type="titlepage")/,"\\1 data-titlepage=\"yes\"")
else
  @log_hash['get_titlepage'] = 'n-a: no podtitlepage found'
end

overwriteHtml(pdf_tmp_html, filecontents, 'overwrite_pdfhtml_1')

#if any images are in 'done' dir, grayscale and upload them to macmillan.tools site
image_count, corrupt, processed = prepDoneDirImages(pdftmp_dir, maxheight, maxwidth, grid, 'prep_images_in_done_dir')

# run method: writeMissingErrors
writeImageErrors(corrupt, image_error, 'write_image_errfiles')

# copy assets to tmp upload dir and upload to ftp
copyFilesinDir("#{assets_dir}/images/#{Metadata.project_dir}", pdftmp_dir, 'copy_assets_to_pdftmp_dir')

ftplist = getFilesinDir(pdftmp_dir, 'get_file_list_for_ftp')

ftpsetup = ftpSetupMethod("#{Metadata.project_dir}_#{Metadata.stage_dir}", Metadata.pisbn, 'mkdirs_on_ftp_site')
ftpstatus = ftpUpload(ftpdirint, pdftmp_dir, ftplist, 'upload_imgs_to_ftp')

# run node.js content conversions
args = "\"#{pdf_tmp_html}\" \"#{Metadata.booktitle}\" \"#{Metadata.bookauthor}\" \"#{Metadata.pisbn}\" \"#{Metadata.imprint}\" \"#{Metadata.publisher}\""
localRunNode(pdfmakerpreprocessingjs, args, 'run_pdfmaker-pre_js')

# fixes images in html, keep final words and ellipses from breaking
fixHtmlImageSrcAndKTs(pdf_tmp_html, ftpdirext, 'fix_html_image_src_and_keeptogethers')

overwriteHtml(pdf_tmp_html, filecontents, 'overwrite_pdfhtml_2')

# fixes em dash breaks (requires UTF 8 encoding)
fixEmdashes(pdf_tmp_html, 'fix_emdashes_in_html')

overwriteHtml(pdf_tmp_html, filecontents, 'overwrite_pdfhtml_3')

# TESTING

# Printing the test results to the log file
File.open(Bkmkr::Paths.log_file, 'a+') do |f|
  f.puts "----- PDFMAKER-PREPROCESSING PROCESSES"
  f.puts "Processed the following images:"
  f.puts processed
  if corrupt.any?
      f.puts "IMAGE PROCESSING ERRORS:"
      f.puts "The following images encountered processing errors and may be corrupt:"
      f.puts corrupt
  end
  f.puts "Uploaded the following images to the ftp:"
  f.puts ftpstatus
end

# ---------------------- LOGGING

@log_hash['image_count'] = image_count
if processed.any?
  @log_hash['processed_images'] = processed
end
if corrupt.any?
  @log_hash['corrupt_images'] = corrupt
end
@log_hash['ftp_status'] = ftpstatus

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
