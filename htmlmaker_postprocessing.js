var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];
var booktitle = process.argv[3]; 
var bookauthor = process.argv[4];
var pisbn = process.argv[5];
var imprint = process.argv[6];
var publisher = process.argv[7];

fs.readFile(file, function editContent (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

  // merge contiguous small caps char styles
  $("p[class^='ChapOpeningText']").each(function (i) {
   $(this).children("span.spansmallcapscharacterssc").each(function () {
        var that = this.previousSibling;
        var testing = $(that).hasClass('spansmallcapscharacterssc');
        if ((that && that.nodeType === 1 && that.tagName === this.tagName && typeof $(that).attr('class') !== 'undefined' && $(that).hasClass('spansmallcapscharacterssc') === true) || (!that)) {
          $(this).addClass("chapopener");
        }
      });
    });

  //function to merge all contiguous spans
 $("span, em").each(function () {
    var that = this.previousSibling;
    var thisclass = $(this).attr('class');
    var previousclass = $(that).attr('class');
    if ((that && that.nodeType === 1 && that.tagName === this.tagName && typeof $(that).attr('class') !== 'undefined' && thisclass === previousclass)) {
      var document = $;
      var node = document.createElement(this.tagName);
      while (that.firstChild) {
          node.appendChild(that.firstChild);
      }
      while (this.firstChild) {
          node.appendChild(this.firstChild);
      }
      this.parentNode.insertBefore(node, this.nextSibling);
      that.parentNode.removeChild(that);
      this.parentNode.removeChild(this);
 
    }
  });



  var output = $.html();
    fs.writeFile(file, output, function(err) {
      if(err) {
          return console.log(err);
      }

      console.log("Content has been updated!");
  });
});