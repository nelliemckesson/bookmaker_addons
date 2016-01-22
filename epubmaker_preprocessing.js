var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];

fs.readFile(file, function editContent (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

// add titlepage image if applicable
  if ($('section[data-titlepage="yes"]').length) {
  	//remove content
  	$('section[data-type="titlepage"]').empty();
  	//add header back in w nonprinting class
  	header = '<h1 class="ChapTitleNonprintingctnp">Title Page</h1>';
  	$('section[data-type="titlepage"]').prepend(header);
  	//add image holder
  	image = '<img class="titlepage" src="epubtitlepage.jpg"/>';
  	$('section[data-type="titlepage"]').append(image);
  }

  // add extra paragraph to copyright page
  $('section[data-type="copyright-page"] p:last-child').removeClass( "CopyrightTextsinglespacecrtx" ).addClass( "CopyrightTextdoublespacecrtxd" );

  var notice = '<p class="CopyrightTextsinglespacecrtx">Our eBooks may be purchased in bulk for promotional, educational, or business use. Please contact the Macmillan Corporate and Premium Sales Department at 1-800-221-7945, ext. 5442, or by e-mail at <a href="mailto:MacmillanSpecialMarkets@macmillan.com">MacmillanSpecialMarkets@macmillan.com</a>.</p>';

  $('section[data-type="copyright-page"]').append(notice);

  // remove halftitle page sections
  $('section[data-type="halftitlepage"]').remove();

  // add chap numbers to chap titles if specified
  $("h1[data-labeltext]").each(function () {
      var labeltext = $(this).attr('data-labeltext');
      $(this).prepend(labeltext + ": ");    
  });

$("span.spanhyperlinkurl:not(:has(a))").each(function () {
      var newlink = "<a href='" + $( this ).text() + "'>" + $( this ).text() + "</a>";
      var mypattern1 = new RegExp( "https?://", "g");
      var result1 = mypattern1.test($( this ).text());
      var mypattern2 = new RegExp( "^@", "g");
      var result2 = mypattern2.test($( this ).text());
      if (result1 === false && result2 === false) {
        newlink = newlink.replace("href='", "href='http://");
      }
      if (result1 === false && result2 === true) {
        newlink = newlink.replace("href='@", "href='https://twitter.com/");
      }
      $(this).empty();
      $(this).prepend(newlink); 
  });

  // convert small caps text to uppercase
  $('span.spansmcapboldscbold').val($('span.spansmcapboldscbold').val().toUpperCase());
  $('span.spansmallcapscharacterssc').val($('span.spansmallcapscharacterssc').val().toUpperCase());
  $('span.spansmcapitalscital').val($('span.spansmcapitalscital').val().toUpperCase());

  // remove textual toc for epub
  $('section.texttoc').remove();

  // remove print-only sections
  $('*[data-format="print"]').remove();

  var output = $.html();
	  fs.writeFile(file, output, function(err) {
	    if(err) {
	        return console.log(err);
	    }

	    console.log("Content has been updated!");
	});
});