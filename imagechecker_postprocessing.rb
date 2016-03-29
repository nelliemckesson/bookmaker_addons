require 'fileutils'

require_relative '../header.rb'
require_relative '../metadata.rb'

# ---------------------- VARIABLES
# The locations to check for images
imagedir = Bkmkr::Paths.submitted_images

final_dir_images = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "images")

final_cover = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "cover", Metadata.frontcover)

# full path to the image error file
image_error = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "IMAGE_ERROR.txt")

# path to placeholder image
missing = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "images", "generic", "missing.jpg")

# ---------------------- METHODS
# If an image_error file exists, delete it
def checkErrorFile(file)
  if File.file?(file)
    Mcmlln::Tools.deleteFile(file)
  end
end

def listImages(file)
  # An array of all the image files referenced in the source html file
  imgarr = File.read(file).scan(/img src=".*?"/)
  # remove duplicate image names from source array
  imgarr = imgarr.uniq
  imgarr
end

def checkImages(imglist, inputdirlist, finaldirlist, inputdir, finaldir)
  # An empty array to store filenames with bad types
  format = []
  supported = []

  # Checks to see if image format is supported
  imglist.each do |m|
    match = m.split("/").pop.gsub(/"/,'')
    matched_file = File.join(inputdir, match)
    matched_file_pickup = File.join(finaldir, match)
    imgformat = match.split(".").pop.downcase
    unless imgformat == "jpg" or imgformat == "jpeg" or imgformat == "png" or imgformat == "pdf" or imgformat == "ai"
      format << match
    else
      supported << match
    end
  end
  return format, supported
end

def convertImages(arr, dir)
  if arr.any?
    arr.each do |c|
      filename = c.split(".").shift
      imgformat = c.split(".").pop.downcase
      imgpath = File.join(dir, c)
      jpg = "#{filename}.jpg"
      unless imgformat == "jpg"
        myres = `identify -format "%y" "#{pdfimage}"`
        if myres.nil? or myres.empty? or !myres
          corrupt << c
        else
          `convert "#{c}" -density #{myres} -quality 100 "#{jpg}"`
        end
      end
    end
  end
end

# replace bad images with placeholder
def insertPlaceholders(arr, html, placeholder, dest)
  filecontents = File.read(html)
  if arr.any?
    arr.each do |r|
      filecontents = filecontents.gsub(/#{r}/,"missing.jpg")
    end
    Mcmlln::Tools.copyFile(placeholder, dest)
  end
  return filecontents
end

# replace image references with jpg file format
def replaceFormats(arr, html)
  filecontents = File.read(html)
  if arr.any?
    arr.each do |r|
      imgfilename = r.split(".").shift
      jpgimage = File.join("#{imgfilename}.jpg")
      filecontents = filecontents.gsub(/#{r}/,jpgimage)
    end
  end
  return filecontents
end

def writeTypeErrors(arr, file)
  # Writes an error text file in the done\pisbn\ folder that lists all low res image files as stored in the resolution array
  if arr.any?
    File.open(file, 'a+') do |output|
      output.puts "IMAGE FORMAT ERRORS:"
      output.puts "Images should use one of the following image formats: .jpg, .jpeg, .png, .ai, .pdf."
      output.puts "The following images have unsupported image types:"
      arr.each do |r|
        output.puts r
      end
    end
  end
end

# ---------------------- PROCESSES

images = Mcmlln::Tools.dirList(imagedir)

finalimages = Mcmlln::Tools.dirList(final_dir_images)

checkErrorFile(image_error)

# run method: listImages
imgarr = listImages(Bkmkr::Paths.outputtmp_html)

# run method: checkImages
format, supported = checkImages(imgarr, images, finalimages, imagedir, final_dir_images)
puts format
puts supported

# run method: insertPlaceholders
insertPlaceholders(format, Bkmkr::Paths.outputtmp_html, missing, Bkmkr::Paths.project_tmp_dir_img)

# run method: writeTypeErrors
writeTypeErrors(format, image_error)

# run method: replaceFormats
filecontents = replaceFormats(imgarr, Bkmkr::Paths.outputtmp_html)

File.open(Bkmkr::Paths.outputtmp_html, 'w') do |output| 
  output.write filecontents
end

# ---------------------- LOGGING

# Printing the test results to the log file
File.open(Bkmkr::Paths.log_file, 'a+') do |f|
  f.puts "----- IMAGECHECKER_POSTPROCESSING PROCESSES"
  f.puts ""
end