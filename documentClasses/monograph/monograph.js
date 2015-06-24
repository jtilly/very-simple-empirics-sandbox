<script type="text/javascript">
window.onload = startup;
document.onkeydown=processKeyInput;

var intScrolling; //Interval Handler.
var currentChapterClone; //Will contain the clone of the |.chapter| element currently being displayed.
var currentSlideClone;  //Will contain the clone of the |.slide| element currently being displayed.

/*
\subsection{Document Preparation}

The |startup()| function initializes the document preparation step. Its functioning depends on whether or not the document was loaded as a reference to one of its contituent boxes, in which case only the box is displayed, or not,
in which case the document is displayed one chapter or appendix at a time within a ``frame''. The frame contains a chapter-level navigation bar at the top and a footer at the bottom.
*/

function startup() {

    /* The first task to undertake when displaying a monograph is the restyling of appendix chapter numbers. The processor gives these ordinary arabic numerals, but we wish replace them with the corresponding Latin letters. It might seem silly to undertake this first, but the chapter numbers get copied into the table of contents and the navigation bar. To ensure that they are correct there, we change them here. See the definition of |restyleAppendixChapterNumbers| below for details. */

    restyleAppendixChapterNumbers();

    /* Next, we gather all of the document's |style| elements into an array and remove the style for slide mode. (Of course, this remains available for later insertion when the reader wants to start a slide show. */

    getStylesFromXHTML();
    removeSlideScreenStyle();

    /* Add controls for revealing and covering hidden code. */
    prepareHiddenCode();

    /* The current instance of the document in the browser is either a reference to the main document or to a box, which is a subdocument. These get styled very, very differently. For a box, we insert only the box's contents and the standard document footer. The main document gets a navigation bar and a single chapter placed into a chapter ``frame'', which is much like a slide frame in the |article| document class. To determine whether or not the document was opened with a reference to a box, we retrieve the URL's |\emph{id}| suffix from |window.location.hash| and compare it to the names of the document's boxes.*/
    var thisHash=window.location.hash;
    
    /* If |thisHash| is non-empty, then we remove the leading ``|\#|'' and replace instances of ``|\%{}20|'' with spaces. */
    if (thisHash==""){

    } else {

	thisHash=thisHash.slice(1);
	thisHash=thisHash.replace(/%20/g," ");
    }
	
    //Collect all of the document's boxes into an array.
    var allDivs=document.getElementsByTagName("div");
    allBoxes = new Array();
    for (var i=0; i< allDivs.length; i++) {
	if (allDivs[i].className.search('^box$')>=0){
	    allBoxes[allBoxes.length]=allDivs[i];
	}
    }

    //Search the document's boxes for the target object.
    var chosenBox=-1;
    var i=0;
    while(i<allBoxes.length){

	var thisTarget=namedDecendent(allBoxes[i],thisHash);
	if(thisTarget){
	    chosenBox=i;
	    break;
	}
	i++;

    }

    /* If the reference is to a box, then |chosenBox| will be nonnegative. In this case, we remove the top-level |bodyPages| and |onlyCode| elements and replace them with the selected box and a footer. Otherwise, we remove all of the boxes and prepare the ``slide-show'' of chapters. */

    var body=document.getElementsByTagName("body")[0];
    if(chosenBox>=0) {

	var bodyPages=document.getElementById("bodyPages");
	var onlyCode=document.getElementById("onlyCode");
	body.removeChild(bodyPages);
	body.removeChild(onlyCode);

	var footer=createFooter();
	var thisBox=allBoxes[chosenBox];
	body.appendChild(thisBox);
	body.appendChild(footer);

    //Change the title tag to match the box's caption. This requires us to use Javascript for something that the CSS normally accomplishes, placing a period between the chapter number and the float number.
	var thisCaption=thisBox.getElementsByClassName("caption")[0].cloneNode(true);
	var addedPeriod=document.createTextNode(".");
	var thisCaptionBoxNumber=thisCaption.getElementsByClassName("floatNumber")[0];
	thisCaption.insertBefore(addedPeriod,thisCaptionBoxNumber);
	var windowTitle=window.document.head.getElementsByTagName("title")[0];;
	windowTitle.textContent=thisCaption.textContent;
     
    } else {
	//Remove all of the boxes.
	for(var i=0;i<allBoxes.length; i++){
	    var thisParent=allBoxes[i].parentNode;
	    thisParent.removeChild(allBoxes[i]);
	}
	//Create chapters for the front matter and the list of code.
	createCodelistChapter();
	createFrontmatterChapter();
	
	//Collect the chapters into an array and assign identifiers to those without them. (Currently, this overwrites chapter identifiers. Needs to be fixed.)
	arrayOfChapters = getChapters();
	numberOfChapters = arrayOfChapters.length;
	createChapterIdentifiers();

	//To manage the switches between chapters (and their slideshows), record the current chapter number and prepared slide show number in global variables. Here, "0" refers to the chapter of frontmatter.
	currentChapterNumber=0; //Initialize at the frontmatter.
	currentSlideShowNumber=0; //If the reader initilizes a slide show and this differs from |currentChapterNumber|, then the program creates a slide show from the current chapter.
	//Finally, we initialize a few global variables for the management of the navigation bars, both in the chapter frame and slideshow frame.

	navigationScrollControlVisible=false; //Indicator of whether or not the horizontal navigation controls are visible. This gets reset by |processResizeWindow|.
	scrollSpeed=3; //Index of scrolling speed applied to navigation bar.
	navigationBarLeftOffset=0; //Used to record the results of the scrolling.

    /* 
       The screen view of prose mode displays one chapter at a time wihin the \emph{chapter frame}. This has navigation tools in the header and bibliographic information in the footer. The document management code places a clone of the currently selected chapter within it.*/

	var chapterFrame=createChapterFrame();
	redirectInternalLinks(chapterFrame);
	insertChapterIntoFrame(currentChapterNumber);
	isDisplayingChapterScreen=true;
	isDisplayingSlideScreen=false;

	//Create the initial chapter's slide show, because the code that starts a slide show expects one to already exist.
	createFrontmatterSlideShow();

	//Run |processResizeWindow| to ensure that the navigation bar controls are available, both now and whenever the window gets resized.
	processResizeWindow();
	window.onresize=processResizeWindow;

    }
}

/*
\subsubsection{Style Sheet Management}

\function{|getStylesFromXHTML()|\label{getStylesFromXHTML}}

This is just a copy of the same function from the |article| class with the cases appopriately modified.

*/


function getStylesFromXHTML(){

    documentHeader=document.getElementsByTagName("head")[0];
    var headersChildren=documentHeader.childNodes;
    var lookingForComment=true;
    var lookingForStyle=false;
    var styleType;
    for(var i=0;i<headersChildren.length;i++){
	
	if(lookingForComment){
	    
	    if (headersChildren[i].nodeType==8){
		styleType=headersChildren[i].textContent;
		lookingForComment=false;
		lookingForStyle=true;
	    }

	} else if(lookingForStyle){
	    if(headersChildren[i].nodeType==1){
		lookingForComment=true;
		lookingForStyle=false;
		thisStyle=headersChildren[i];
		switch(styleType){

		case "common":
		    commonStyle=thisStyle;
		    break;

		case "chapterScreen":
		    chapterScreenStyle=thisStyle;
		    break;

		case "slideScreen":
		    slideScreenStyle=thisStyle;
		    break;

		}
	    }

	}
	
    }
}
/* 
   Note that |getStyleSheetsFromXHTML()| has the (desired) side effect of defining |documentHeader| as a global variable. 

   The remaining style sheet management functions simply add and remove the mode-view specific style sheets. The order of style sheets matters, because rules appearing later  take precidence over earlier conflicting rules. By using the |appendChild| method, we guarantee that the mode-view specific style sheets always come after the common style sheet.\footnote{However, the division of labor between the common and mode-view specific style sheets makes this ordering relatively unimportant.} */

//\function{|removeChapterScreenStyle()|}
function removeChapterScreenStyle() {
    documentHeader.removeChild(chapterScreenStyle);
}
//\function{|addChapterScreenStyle()|}
function addChapterScreenStyle() {
    documentHeader.appendChild(chapterScreenStyle);
}

//\function{|removeSlideScreenStyle()|}
function removeSlideScreenStyle() {
    documentHeader.removeChild(slideScreenStyle);
}

//\function{|addSlideScreenStyle()|}
function addSlideScreenStyle(){
    documentHeader.appendChild(slideScreenStyle);
}


/* \subsubsection{Initial Restyling} */

function restyleAppendixChapterNumbers(){
    
    //Each appendix chapter number initially is within a span with class |chapterNumber| that iself is either
    //\begin{itemize}
    // \item Within an anchor with class |appendixref|, or
    // \item within a header with class |chapterAppendix|, |sectionAppendix|, or |subsectionAppendix|.
    //\end{itemize}
    //We handle these two cases sequentially. 
    
// For the first case, we gather all of the document's anchors and change the |chapterNumbers| in those with the appropriate class.
    var allAnchors = document.getElementsByTagName("a");
    for(var i=0; i < allAnchors.length;i++){
	
	if(allAnchors[i].className.search('^appendixref$')>=0) {
	    var thisAnchorsSpans=allAnchors[i].getElementsByTagName("span");    
	    for(var j=0; j< thisAnchorsSpans.length;j++){
		if(thisAnchorsSpans[j].className.search('^chapterNumber$')>=0){
		    var currentText=thisAnchorsSpans[j].childNodes[0];
		    var thisInt=parseInt(currentText.data);
		    //Remove the current text and replace it.
		    thisAnchorsSpans[j].removeChild(currentText);
		    var newText=String.fromCharCode(64+thisInt);
		    var newTextNode=document.createTextNode(newText);
		    thisAnchorsSpans[j].appendChild(newTextNode);
		}
	    }
	}
    }
//The second case proceeds similarly.

    var tags = [ "h1","h2","h3","h4","h5","h6" ];
    
    for(var hLevel=0;hLevel<tags.length;hLevel++){
	var allHeadings=document.getElementsByTagName(tags[hLevel]);
	for(var i=0; i<allHeadings.length;i++){
	    if(allHeadings[i].className.search('Appendix$')>=0) {
		var thisHeadingsSpans=allHeadings[i].getElementsByTagName("span");
		for(var j=0; j<thisHeadingsSpans.length;j++){
		    if(thisHeadingsSpans[j].className.search('^chapterNumber$')>=0){
			var currentText=thisHeadingsSpans[j].childNodes[0];
			var thisInt=parseInt(currentText.data);
			thisHeadingsSpans[j].removeChild(currentText);
			var newText=String.fromCharCode(64+thisInt);
			var newTextNode=document.createTextNode(newText);
			thisHeadingsSpans[j].appendChild(newTextNode);
		    }
		}
	    }
	}
    }
    
}
/*
\subsubsection{Additions for Article Mode}

We group functions |beautifyFrontMatter()|, |createTableOfContents()|, and |createArticleFooter()| together because they all create elements to enhance the article mode's appearance. 
\function{|beautifyFrontMatter()|}

The first of these functions implements two simple (and rather straightforward) beautifications to the front matter.
\begin{itemize}
\item Create a paragraph with the single word ``Abstract'' above the abstract.
\item Place a horizontal rule above the table of thanks.
\end{itemize}
Although both of these tasks seem like tasks for the CSS |:before| pseudo class, that can only \emph{select} document elements, not create them outright.
*/

function beautifyFrontMatter(){

    var frontMatter=document.getElementById("frontMatter");

    //If there is an abstract, then place ``Abstract:'' in a pararagraph centered above it.
    var abstract=document.getElementById("documentAbstract");
    if(abstract){
	var newParagraph=document.createElement("p");
	var newText=document.createTextNode("Abstract");
	newParagraph.appendChild(newText);
	newParagraph.style.textAlign="center";
    
	frontMatter.insertBefore(newParagraph,abstract);
    }

    //If there is a |documentThanks| table, put a horizontal rule above it. and give it a healthy top margin to visually separate it from the abstract.
    var thanks=document.getElementById("documentThanks");
    if(thanks){
	var newHorizontalRule=document.createElement("hr");
	newHorizontalRule.style.borderColor="black";
	newHorizontalRule.style.width="90%";

	//If there is also an abstract, give the rule a healthy top margin for visual separation.
	if(abstract){
	    newHorizontalRule.style.marginTop="1em";
	}

	frontMatter.insertBefore(newHorizontalRule,thanks);

    }

}

/*
\function{|createTableOfContents()|}

If the author has used a |\backslash{section}| command to structure the article, then we wish to create a table of contents. By construction, each of its entries is linked to the relevant place in the document, so it can serve as a navigation aid. Although |start()| calls |createTableOfContents()| for this task, the function |createBranchList()| does the real heavy lifting.

*/

function createTableOfContents(){

    var bodyPages=document.getElementById("bodyPages");

    //Determine if the user has created any chapters. If so, create the table of contents.
    var h2List=bodyPages.getElementsByTagName("h2");
    //By construction, every |h3| tag should have the class name ``|chapter|.'' 
    //Nevertheless, we check to ensure that at least one of them does.
    var hasChapters=false;
    for(var i=1;i<h2List.length;i++){
	if(h2List[i].className=="chapter"){
	    hasChapters=true;
	}
    }

    if(hasChapters){

	//Create a division to contain the table of contents.
	var tableOfContents=document.createElement("div");
	tableOfContents.id="tableOfContents";
    
	//Create a paragraph to label the table of contents,
	//populate it, style it, and insert it into the document.
	var newParagraph=document.createElement("p");
	var newText=document.createTextNode("Contents");
	newParagraph.appendChild(newText);
	newParagraph.style.textAlign="center";
	tableOfContents.appendChild(newParagraph);

	//Finally, create and insert the actual table of contents list.
	var tableOfContentsList=createBranchList(bodyPages,0);
	tableOfContents.appendChild(tableOfContentsList);
    
    }
    else{
	var tableOfContents=null;
    }
    return tableOfContents;
}

/*
\begin{figure}
\centeredimage{documentTreeSection.png}
\caption{A portion of a document's DOM tree in Safari's Web Inspector\label{documentTreeSection}}
\end{figure}

\function{|createBranchList()|}
 
The output of |createTableOfContents| is a |ul| tag with an item for each section. Those sections with subsections also contain lists of the subsections, and the subsection items contain lists of any subsubsections. To construct this, we use the information embedded within the DOM tree. It uses the DOM tree find sections, subsections, and subsubsections and place them into nested lists. Figure \ref{documentTreeSection} illustrates this information with a portion of a document's tree viewed with Safari's Web Inspector. The article's content is contained within the |body| tag's top-level division |bodyPages|. After an empty paragraph, its first child is a |div| with class name |section|. That |div|'s first child is a header with the same class name which itself contains information for the section's enumeration and the section's name. For subsections and subsubsections, |h4| and |h5| tags contain the analogous information. 

To create the table of contents, we proceed through the DOM tree copying these header tags' contents into the appropriate list items.

*/


function createBranchList(e,level){

    //Use |level| to determine which type of division we seek. Put the result into |levelName| 
    //and the name of the corresponding header tag into |levelHeaderTag|.
    var levelName;
    var levelHeaderTag;
    switch(level){
    case 0: levelName="chapter";       levelHeaderTag="h2"; break;
    case 1: levelName="section";       levelHeaderTag="h3"; break;
    case 2: levelName="subsection";    levelHeaderTag="h4"; break;
    case 3: levelName="subsubsection"; levelHeaderTag="h5"; break;
    default: return null; 
    }

    //Create an array of all |div| decendents of |e| with |className| equal to |levelName|.
    var allDivs = e.getElementsByTagName("div");
    var allBranches = new Array();
    for (var i = 0; i< allDivs.length; i++) {
	if (allDivs[i].className.search('^' + levelName + '$')>=0){
	    allBranches[allBranches.length] = allDivs[i];
	}
    }

    //Run through the array to create the desired list. 
    var branchList=document.createElement("ul");

    var thisListItem;
    var thisAnchor;
    var thisBranchssHeader;
    var thisHeadersChildren;
    var thisChildsClone;
    var thisBranchsId;
    var thisBranchsClassName;
    var thisBranchsList;

    for(i=0;i<allBranches.length;i++){

	//Recover element |i|'s header and its contents.
	thisBranchsHeader=allBranches[i].getElementsByTagName(levelHeaderTag)[0];
	thisHeadersChildren=thisBranchsHeader.childNodes;
	thisBranchsId=thisBranchsHeader.id;
	thisBranchsClassName=thisBranchsHeader.className;

	//Create a list of this branch's' constituent branches.
	thisBranchsList=createBranchList(allBranches[i],level+1);
	
	//Create the anchor to be placed in the list item.
	thisAnchor=document.createElement("a");
	thisAnchor.href="#"+thisBranchsId;
	for(j=0;j<thisHeadersChildren.length;j++){

	    thisChildsClone=thisHeadersChildren[j].cloneNode(true);
	    thisAnchor.appendChild(thisChildsClone);

	}
	
	//Create the list item for this section.
	thisListItem=document.createElement("li");
	thisListItem.className=thisBranchsClassName;
	thisListItem.appendChild(thisAnchor);
	if(thisBranchsList){
	    thisListItem.appendChild(thisBranchsList);
	}
	
	//Place the list item into the list.
	branchList.appendChild(thisListItem);

    }    

    return branchList;


}

/*

\begin{figure}
\centeredimage{articleFooterDocumentTree.png}
\caption{The article footer in |hello.c|'s documen tree\label{articleFooterDocumentTree}}
\end{figure}

\function{|createArticleFooter()|}

A fixed footer with bibiliographic information is the final addition to the article mode. We include this so that authors can give their own names and any classification information the prominence they deserve and/or require. Figure \ref{articleFooterDocumentTree} shows |hello.c|'s document tree expanded to show the article footer and its child nodes. Creating this from the content of |frontMatter| is tedious but straightforward.

 */
function createArticleFooter(){

    var articleFooter=document.createElement("div");
    articleFooter.id="articleFooter";
    //Insert the article's footer before the |onlyCode| division.
    var body=document.getElementsByTagName("body")[0];
    var onlyCode=document.getElementById("onlyCode");
    body.insertBefore(articleFooter,onlyCode);

    //Add a |div| containing the document's bibliographic information: title, authors, and date.
    var footerBibliographicInformation=document.createElement("div");
    footerBibliographicInformation.id="articleFooterBibliographicInformation";
    articleFooter.appendChild(footerBibliographicInformation);

    //Create a |span| containing the document's title and add it to the footer's bibliographic information.
    var footerTitle=document.createElement("span");
    footerTitle.id="articleFooterTitle";

    var documentTitle=document.getElementById("documentTitle");
    if(documentTitle){
	var documentTitleContent=documentTitle.childNodes;
	var thisChildsClone;

	for(var i=0;i<documentTitleContent.length;i++){

	    thisChildsClone=documentTitleContent[i].cloneNode(true);
	    footerTitle.appendChild(thisChildsClone);

	}
    } else {
    }

    footerBibliographicInformation.appendChild(footerTitle);

    //Add a span containing the document's authors.
    var footerAuthorList=document.createElement("span");
    footerAuthorList.id="articleFooterAuthorList";

    var authorList=document.getElementById("authorList");
    if(authorList){
	var authorListContent=authorList.childNodes;

	for(var j=0;j<authorListContent.length;j++){
	    thisChildsClone=authorListContent[j].cloneNode(true);
	    footerAuthorList.appendChild(thisChildsClone);
	}
    } else {
    }
    footerBibliographicInformation.appendChild(footerAuthorList);    

    //Add a div containing the document's union bugs.
    var footerUnionBugs=document.createElement("div");
    footerUnionBugs.id="articleFooterUnionBugs";

    var unionBugs=document.getElementById("unionBugs");
    if(unionBugs){
	var unionBugsContent=unionBugs.childNodes;

	for(var k=0;k<unionBugsContent.length;k++){
	    thisChildsClone=unionBugsContent[k].cloneNode(true);
	    footerUnionBugs.appendChild(thisChildsClone);
	}
    } else {
    }
    articleFooter.appendChild(footerUnionBugs);

    //Add a span containing the document's date.
    var slideFooterDate=document.createElement("span");
    slideFooterDate.id="articleFooterDate";

    var documentDate=document.getElementById("documentDate");
    if(documentDate){
	var documentDateContent=documentDate.childNodes;
    
	for(var l=0;l<documentDateContent.length;l++){
	    thisChildsClone=documentDateContent[l].cloneNode(true);
	    slideFooterDate.appendChild(thisChildsClone);
	}
    } else {
    }
    footerBibliographicInformation.appendChild(slideFooterDate);

    //Add a |div| containing the document's classification directive.
    
    var slideFooterClassification=document.createElement("div");
    slideFooterClassification.id="articleFooterClassification";    

    var documentClassification=document.getElementById("classification");
    if(documentClassification){

	var documentClassificationContent=documentClassification.childNodes;

	for(var m=0;m<documentClassificationContent.length;m++){
	    thisChildsClone=documentClassificationContent[m].cloneNode(true);
	    slideFooterClassification.appendChild(thisChildsClone);
	}

    } else {
    }
    articleFooter.appendChild(slideFooterClassification);


}

/*
\function{|createFrontmatterChapter()|}
*/

function createFrontmatterChapter(){

    //The chapter of front matter gets inserted at the start of the |bodyPages| division.
    var bodyPages=document.getElementById("bodyPages");
    var bodyPagesChildren=bodyPages.childNodes;
    
    var frontmatterChapter=document.createElement("div");
    frontmatterChapter.className="chapter";
    frontmatterChapter.id="frontmatterChapter";
    bodyPages.insertBefore(frontmatterChapter,bodyPagesChildren[0]);


    //The frontmatter chapter first gets an |h2| tag with its title ``Front Matter''.
    var frontmatterHeader=document.createElement("h2");
    frontmatterHeader.class="chapter";
    frontmatterHeader.id="_comppFrontmatter";
    frontmatterChapter.appendChild(frontmatterHeader);
    
    var frontmatterName=document.createElement("span");
    frontmatterName.class="sectionName";
    frontmatterHeader.appendChild(frontmatterName);
    
    var newText=document.createTextNode("Front Matter");
    frontmatterName.appendChild(newText);

    //The remainder of the front matter chapter consists of a number of ``pages.''. The first of these is the cover page, which displays the title, cover art (if any), and the authors.
    var coverPage=document.createElement("div");
    coverPage.id="coverPage";
    frontmatterChapter.appendChild(coverPage);

    //Place the title at the top of the cover page
    var coverPageTitle=document.createElement("p");
    coverPageTitle.id="coverPageTitle";
    
    var documentTitle=document.getElementById("documentTitle");
    if(documentTitle){
	var coverPageTitleContent=documentTitle.childNodes;
	var thisChildsClone;

	for(var i=0;i<coverPageTitleContent.length;i++){

	    thisChildsClone=coverPageTitleContent[i].cloneNode(true);
	    coverPageTitle.appendChild(thisChildsClone);

	}
    } else { 
    
    }
    coverPage.appendChild(coverPageTitle);

    //The next addition to the cover page is the cover art.
    var coverArt=document.getElementById("coverArt");
    coverPage.appendChild(coverArt);

    //Finally, we add the list of authors.
    var coverPageAuthorList=document.createElement("p");
    coverPageAuthorList.id="coverPageAuthorList";

    var authorList=document.getElementById("authorList");
    if(authorList){
	var authorListContent=authorList.childNodes;

	for(var j=0;j<authorListContent.length;j++){
	    thisChildsClone=authorListContent[j].cloneNode(true);
	    coverPageAuthorList.appendChild(thisChildsClone);
	}
    } else {

    }
    coverPage.appendChild(coverPageAuthorList);    

    //The next page provides a table of contents. We simply make this with the |createTableOfContents()| function and append it to the |frontmatterChapter|.
    var tableOfContents=createTableOfContents();
    frontmatterChapter.appendChild(tableOfContents);

    //Next comes the dedication page. This is a paragraph tag, but we give it the same styling as a single page.
    var dedication=document.getElementById("documentDedication");
    frontmatterChapter.appendChild(dedication);

    //Finally, we add the preface division and its table of footnotes.
    var preface=document.getElementById("documentPreface");
    frontmatterChapter.appendChild(preface);
}

/*
\function{|createEndnoteChapter|}
*/
function createEndnoteChapter(){

    //The chapter of end notes is just a clone of the |footnotes| division inserted at the end of the |bodyPages| division.
    var footnoteDivision=document.getElementById("footnotes");
    endnoteChapter=footnoteDivision.cloneNode(true);
    endnoteChapter.id="endnotes";
    endnoteChapter.className="chapter"

    var endnoteHeader=document.createElement("h2");
    endnoteHeader.className="chapter";
    endnoteHeader.id="_comppEndnote";
    endnoteChapter.appendChild(endnoteHeader);

    var endnoteName=document.createElement("span");
    endnoteName.class="sectionName";
    endnoteHeader.appendChild(endnoteName);
    
    var newText=document.createTextNode("Notes");
    endnoteName.appendChild(newText);
    
    var bodyPages=document.getElementById("bodyPages");
    bodyPages.appendChild(endnoteChapter);

}

function createCodelistChapter(){

   //The code listing chapter is just a clone of the |onlyCode| division inserted at the end of the |bodyPages| division.
    codelistChapter=document.createElement("div");
    codelistChapter.id="codelist";
    codelistChapter.className="chapter"
    
    var codelistHeader=document.createElement("h2");
    codelistHeader.className="chapterAppendix";
    codelistHeader.id="_comppCodelist";
    codelistChapter.appendChild(codelistHeader);

    var codelistName=document.createElement("span");
    codelistName.className="sectionName";
    codelistHeader.appendChild(codelistName);
    
    var newText=document.createTextNode("Code Listing");
    codelistName.appendChild(newText);
    
    var onlycodeDivision=document.getElementById("onlyCode");
    codelistChapter.appendChild(onlycodeDivision);


    var bodyPages=document.getElementById("bodyPages");
    bodyPages.appendChild(codelistChapter);
}


/* Hidden Code/Code Folds */

function prepareHiddenCode(){

    /* Place all hidden code spans into an array. */
    var allHiddenCode=document.getElementsByClassName("hiddencode");

    /* Cycle through the hidden code spans, find the |workingCode| tables they contain, add a |control| cell to eachrow, append the more/less controls to the first row's |conrol| cell, and add an |elipsis| row to each table after the first row.. */
    for(var i=0; i<allHiddenCode.length;i++){

	var allTables=allHiddenCode[i].getElementsByTagName("table");
	var allWorkingCode= new Array();
	for(var j=0;j<allTables.length;j++){
	    if(allTables[j].className.search('^workingCode$')>=0){
		allWorkingCode[allWorkingCode.length]=allTables[j];
	    }
	}

	for(var j=0; j<allWorkingCode.length;j++){
	    var moreAnchor=document.createElement("span");
	    moreAnchor.className="showCode";
	    var moreImage=document.createElement("img");
	    moreImage.src="data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9Im5vIj8+CjwhLS0gQ3JlYXRlZCB3aXRoIElua3NjYXBlIChodHRwOi8vd3d3Lmlua3NjYXBlLm9yZy8pIC0tPgoKPHN2ZwogICB4bWxuczpkYz0iaHR0cDovL3B1cmwub3JnL2RjL2VsZW1lbnRzLzEuMS8iCiAgIHhtbG5zOmNjPSJodHRwOi8vY3JlYXRpdmVjb21tb25zLm9yZy9ucyMiCiAgIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyIKICAgeG1sbnM6c3ZnPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIKICAgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIgogICB4bWxuczpzb2RpcG9kaT0iaHR0cDovL3NvZGlwb2RpLnNvdXJjZWZvcmdlLm5ldC9EVEQvc29kaXBvZGktMC5kdGQiCiAgIHhtbG5zOmlua3NjYXBlPSJodHRwOi8vd3d3Lmlua3NjYXBlLm9yZy9uYW1lc3BhY2VzL2lua3NjYXBlIgogICB3aWR0aD0iMjQiCiAgIGhlaWdodD0iMjQiCiAgIGlkPSJzdmc1MDg3IgogICB2ZXJzaW9uPSIxLjEiCiAgIGlua3NjYXBlOnZlcnNpb249IjAuNDguNCByOTkzOSIKICAgc29kaXBvZGk6ZG9jbmFtZT0ic2hvdy5zdmciPgogIDxkZWZzCiAgICAgaWQ9ImRlZnM1MDg5IiAvPgogIDxzb2RpcG9kaTpuYW1lZHZpZXcKICAgICBpZD0iYmFzZSIKICAgICBwYWdlY29sb3I9IiNmZmZmZmYiCiAgICAgYm9yZGVyY29sb3I9IiM2NjY2NjYiCiAgICAgYm9yZGVyb3BhY2l0eT0iMS4wIgogICAgIGlua3NjYXBlOnBhZ2VvcGFjaXR5PSIwLjAiCiAgICAgaW5rc2NhcGU6cGFnZXNoYWRvdz0iMiIKICAgICBpbmtzY2FwZTp6b29tPSIyOS4yOTE2NjciCiAgICAgaW5rc2NhcGU6Y3g9IjYuNzc2NjcxMyIKICAgICBpbmtzY2FwZTpjeT0iMTIuMDc1NzgyIgogICAgIGlua3NjYXBlOmRvY3VtZW50LXVuaXRzPSJweCIKICAgICBpbmtzY2FwZTpjdXJyZW50LWxheWVyPSJsYXllcjEiCiAgICAgc2hvd2dyaWQ9InRydWUiCiAgICAgaW5rc2NhcGU6d2luZG93LXdpZHRoPSIxNjgwIgogICAgIGlua3NjYXBlOndpbmRvdy1oZWlnaHQ9IjkxOCIKICAgICBpbmtzY2FwZTp3aW5kb3cteD0iMCIKICAgICBpbmtzY2FwZTp3aW5kb3cteT0iMCIKICAgICBpbmtzY2FwZTp3aW5kb3ctbWF4aW1pemVkPSIxIj4KICAgIDxpbmtzY2FwZTpncmlkCiAgICAgICB0eXBlPSJ4eWdyaWQiCiAgICAgICBpZD0iZ3JpZDUwOTUiCiAgICAgICBlbXBzcGFjaW5nPSI1IgogICAgICAgdmlzaWJsZT0idHJ1ZSIKICAgICAgIGVuYWJsZWQ9InRydWUiCiAgICAgICBzbmFwdmlzaWJsZWdyaWRsaW5lc29ubHk9InRydWUiIC8+CiAgPC9zb2RpcG9kaTpuYW1lZHZpZXc+CiAgPG1ldGFkYXRhCiAgICAgaWQ9Im1ldGFkYXRhNTA5MiI+CiAgICA8cmRmOlJERj4KICAgICAgPGNjOldvcmsKICAgICAgICAgcmRmOmFib3V0PSIiPgogICAgICAgIDxkYzpmb3JtYXQ+aW1hZ2Uvc3ZnK3htbDwvZGM6Zm9ybWF0PgogICAgICAgIDxkYzp0eXBlCiAgICAgICAgICAgcmRmOnJlc291cmNlPSJodHRwOi8vcHVybC5vcmcvZGMvZGNtaXR5cGUvU3RpbGxJbWFnZSIgLz4KICAgICAgICA8ZGM6dGl0bGU+PC9kYzp0aXRsZT4KICAgICAgPC9jYzpXb3JrPgogICAgPC9yZGY6UkRGPgogIDwvbWV0YWRhdGE+CiAgPGcKICAgICBpbmtzY2FwZTpsYWJlbD0iTGF5ZXIgMSIKICAgICBpbmtzY2FwZTpncm91cG1vZGU9ImxheWVyIgogICAgIGlkPSJsYXllcjEiCiAgICAgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCwtMTAyOC4zNjIyKSI+CiAgICA8cmVjdAogICAgICAgcnk9IjAuNzUiCiAgICAgICByeD0iMC4wMjU2MDQ1NTIiCiAgICAgICB0cmFuc2Zvcm09Im1hdHJpeCgwLDEsLTEsMCwwLDApIgogICAgICAgeT0iLTIwLjk2MTU5NCIKICAgICAgIHg9IjEwMzguNDg3MiIKICAgICAgIGhlaWdodD0iMTgiCiAgICAgICB3aWR0aD0iMy43NSIKICAgICAgIGlkPSJyZWN0NTYwNyIKICAgICAgIHN0eWxlPSJjb2xvcjojMDAwMDAwO2ZpbGw6Izg2YWE4NztmaWxsLW9wYWNpdHk6MTtmaWxsLXJ1bGU6bm9uemVybztzdHJva2U6bm9uZTtzdHJva2Utd2lkdGg6MC4yNTAwMDAwMDAwMDAwMDAwMDttYXJrZXI6bm9uZTt2aXNpYmlsaXR5OnZpc2libGU7ZGlzcGxheTppbmxpbmU7b3ZlcmZsb3c6dmlzaWJsZTtlbmFibGUtYmFja2dyb3VuZDphY2N1bXVsYXRlIiAvPgogICAgPHBhdGgKICAgICAgIHN0eWxlPSJmaWxsOm5vbmU7c3Ryb2tlOiM4NmFhODc7c3Ryb2tlLXdpZHRoOjFweDtzdHJva2UtbGluZWNhcDpidXR0O3N0cm9rZS1saW5lam9pbjptaXRlcjtzdHJva2Utb3BhY2l0eToxIgogICAgICAgZD0ibSA1LDEwMzEuODYyMiAtNCwwIDAsMTcgNCwwIgogICAgICAgaWQ9InBhdGg2MjM3IgogICAgICAgaW5rc2NhcGU6Y29ubmVjdG9yLWN1cnZhdHVyZT0iMCIgLz4KICAgIDxwYXRoCiAgICAgICBpbmtzY2FwZTpjb25uZWN0b3ItY3VydmF0dXJlPSIwIgogICAgICAgaWQ9InBhdGg2MjM5IgogICAgICAgZD0ibSAxOC45MjMxODYsMTAzMS44NjIyIDQsMCAwLDE3IC00LDAiCiAgICAgICBzdHlsZT0iZmlsbDpub25lO3N0cm9rZTojODZhYTg3O3N0cm9rZS13aWR0aDoxcHg7c3Ryb2tlLWxpbmVjYXA6YnV0dDtzdHJva2UtbGluZWpvaW46bWl0ZXI7c3Ryb2tlLW9wYWNpdHk6MSIgLz4KICAgIDxyZWN0CiAgICAgICBzdHlsZT0iY29sb3I6IzAwMDAwMDtmaWxsOiM4NmFhODc7ZmlsbC1vcGFjaXR5OjE7ZmlsbC1ydWxlOm5vbnplcm87c3Ryb2tlOm5vbmU7c3Ryb2tlLXdpZHRoOjAuMjUwMDAwMDAwMDAwMDAwMDA7bWFya2VyOm5vbmU7dmlzaWJpbGl0eTp2aXNpYmxlO2Rpc3BsYXk6aW5saW5lO292ZXJmbG93OnZpc2libGU7ZW5hYmxlLWJhY2tncm91bmQ6YWNjdW11bGF0ZSIKICAgICAgIGlkPSJyZWN0NjI2MCIKICAgICAgIHdpZHRoPSIzLjc1IgogICAgICAgaGVpZ2h0PSIxOCIKICAgICAgIHg9Ii0xMy44MzY1OTQiCiAgICAgICB5PSItMTA0OS4zNjIyIgogICAgICAgdHJhbnNmb3JtPSJzY2FsZSgtMSwtMSkiCiAgICAgICByeD0iMC4wMjU2MDQ1NTIiCiAgICAgICByeT0iMC43NSIgLz4KICA8L2c+Cjwvc3ZnPgo=";
	    moreAnchor.appendChild(moreImage);
	    moreAnchor.style.cursor="pointer";
	    moreAnchor.onclick=showCode;

	    var lessAnchor=document.createElement("span");
	    lessAnchor.className="hideCode";
	    var lessImage=document.createElement("img");
	    lessImage.src="data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9Im5vIj8+CjwhLS0gQ3JlYXRlZCB3aXRoIElua3NjYXBlIChodHRwOi8vd3d3Lmlua3NjYXBlLm9yZy8pIC0tPgoKPHN2ZwogICB4bWxuczpkYz0iaHR0cDovL3B1cmwub3JnL2RjL2VsZW1lbnRzLzEuMS8iCiAgIHhtbG5zOmNjPSJodHRwOi8vY3JlYXRpdmVjb21tb25zLm9yZy9ucyMiCiAgIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyIKICAgeG1sbnM6c3ZnPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIKICAgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIgogICB4bWxuczpzb2RpcG9kaT0iaHR0cDovL3NvZGlwb2RpLnNvdXJjZWZvcmdlLm5ldC9EVEQvc29kaXBvZGktMC5kdGQiCiAgIHhtbG5zOmlua3NjYXBlPSJodHRwOi8vd3d3Lmlua3NjYXBlLm9yZy9uYW1lc3BhY2VzL2lua3NjYXBlIgogICB3aWR0aD0iMjQiCiAgIGhlaWdodD0iMjQiCiAgIGlkPSJzdmc1MDg3IgogICB2ZXJzaW9uPSIxLjEiCiAgIGlua3NjYXBlOnZlcnNpb249IjAuNDguNCByOTkzOSIKICAgc29kaXBvZGk6ZG9jbmFtZT0iaGlkZS5zdmciPgogIDxkZWZzCiAgICAgaWQ9ImRlZnM1MDg5IiAvPgogIDxzb2RpcG9kaTpuYW1lZHZpZXcKICAgICBpZD0iYmFzZSIKICAgICBwYWdlY29sb3I9IiNmZmZmZmYiCiAgICAgYm9yZGVyY29sb3I9IiM2NjY2NjYiCiAgICAgYm9yZGVyb3BhY2l0eT0iMS4wIgogICAgIGlua3NjYXBlOnBhZ2VvcGFjaXR5PSIwLjAiCiAgICAgaW5rc2NhcGU6cGFnZXNoYWRvdz0iMiIKICAgICBpbmtzY2FwZTp6b29tPSIyOS4yOTE2NjciCiAgICAgaW5rc2NhcGU6Y3g9IjYuNzc2NjcxMyIKICAgICBpbmtzY2FwZTpjeT0iMTIuMDc1NzgyIgogICAgIGlua3NjYXBlOmRvY3VtZW50LXVuaXRzPSJweCIKICAgICBpbmtzY2FwZTpjdXJyZW50LWxheWVyPSJsYXllcjEiCiAgICAgc2hvd2dyaWQ9InRydWUiCiAgICAgaW5rc2NhcGU6d2luZG93LXdpZHRoPSIxNjgwIgogICAgIGlua3NjYXBlOndpbmRvdy1oZWlnaHQ9IjkxOCIKICAgICBpbmtzY2FwZTp3aW5kb3cteD0iMCIKICAgICBpbmtzY2FwZTp3aW5kb3cteT0iMCIKICAgICBpbmtzY2FwZTp3aW5kb3ctbWF4aW1pemVkPSIxIj4KICAgIDxpbmtzY2FwZTpncmlkCiAgICAgICB0eXBlPSJ4eWdyaWQiCiAgICAgICBpZD0iZ3JpZDUwOTUiCiAgICAgICBlbXBzcGFjaW5nPSI1IgogICAgICAgdmlzaWJsZT0idHJ1ZSIKICAgICAgIGVuYWJsZWQ9InRydWUiCiAgICAgICBzbmFwdmlzaWJsZWdyaWRsaW5lc29ubHk9InRydWUiIC8+CiAgPC9zb2RpcG9kaTpuYW1lZHZpZXc+CiAgPG1ldGFkYXRhCiAgICAgaWQ9Im1ldGFkYXRhNTA5MiI+CiAgICA8cmRmOlJERj4KICAgICAgPGNjOldvcmsKICAgICAgICAgcmRmOmFib3V0PSIiPgogICAgICAgIDxkYzpmb3JtYXQ+aW1hZ2Uvc3ZnK3htbDwvZGM6Zm9ybWF0PgogICAgICAgIDxkYzp0eXBlCiAgICAgICAgICAgcmRmOnJlc291cmNlPSJodHRwOi8vcHVybC5vcmcvZGMvZGNtaXR5cGUvU3RpbGxJbWFnZSIgLz4KICAgICAgICA8ZGM6dGl0bGUgLz4KICAgICAgPC9jYzpXb3JrPgogICAgPC9yZGY6UkRGPgogIDwvbWV0YWRhdGE+CiAgPGcKICAgICBpbmtzY2FwZTpsYWJlbD0iTGF5ZXIgMSIKICAgICBpbmtzY2FwZTpncm91cG1vZGU9ImxheWVyIgogICAgIGlkPSJsYXllcjEiCiAgICAgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCwtMTAyOC4zNjIyKSI+CiAgICA8cmVjdAogICAgICAgcnk9IjAuNzUiCiAgICAgICByeD0iMC4wMjU2MDQ1NTIiCiAgICAgICB0cmFuc2Zvcm09Im1hdHJpeCgwLDEsLTEsMCwwLDApIgogICAgICAgeT0iLTIwLjk2MTU5NCIKICAgICAgIHg9IjEwMzguNDg3MiIKICAgICAgIGhlaWdodD0iMTgiCiAgICAgICB3aWR0aD0iMy43NSIKICAgICAgIGlkPSJyZWN0NTYwNyIKICAgICAgIHN0eWxlPSJjb2xvcjojMDAwMDAwO2ZpbGw6I2Q1NjA2MztmaWxsLW9wYWNpdHk6MTtmaWxsLXJ1bGU6bm9uemVybztzdHJva2U6bm9uZTtzdHJva2Utd2lkdGg6MC4yNTttYXJrZXI6bm9uZTt2aXNpYmlsaXR5OnZpc2libGU7ZGlzcGxheTppbmxpbmU7b3ZlcmZsb3c6dmlzaWJsZTtlbmFibGUtYmFja2dyb3VuZDphY2N1bXVsYXRlIiAvPgogICAgPHBhdGgKICAgICAgIHN0eWxlPSJmaWxsOm5vbmU7c3Ryb2tlOiNkNTYwNjM7c3Ryb2tlLXdpZHRoOjFweDtzdHJva2UtbGluZWNhcDpidXR0O3N0cm9rZS1saW5lam9pbjptaXRlcjtzdHJva2Utb3BhY2l0eToxIgogICAgICAgZD0ibSA1LDEwMzEuODYyMiAtNCwwIDAsMTcgNCwwIgogICAgICAgaWQ9InBhdGg2MjM3IgogICAgICAgaW5rc2NhcGU6Y29ubmVjdG9yLWN1cnZhdHVyZT0iMCIgLz4KICAgIDxwYXRoCiAgICAgICBpbmtzY2FwZTpjb25uZWN0b3ItY3VydmF0dXJlPSIwIgogICAgICAgaWQ9InBhdGg2MjM5IgogICAgICAgZD0ibSAxOC45MjMxODYsMTAzMS44NjIyIDQsMCAwLDE3IC00LDAiCiAgICAgICBzdHlsZT0iZmlsbDpub25lO3N0cm9rZTojZDU2MDYzO3N0cm9rZS13aWR0aDoxcHg7c3Ryb2tlLWxpbmVjYXA6YnV0dDtzdHJva2UtbGluZWpvaW46bWl0ZXI7c3Ryb2tlLW9wYWNpdHk6MSIgLz4KICA8L2c+Cjwvc3ZnPgo=";
	    lessAnchor.appendChild(lessImage);
	    lessAnchor.style.cursor="pointer";
	    lessAnchor.onclick=hideCode;

	    var ellipsisRow=document.createElement("tr");
	    ellipsisRow.className="ellipsis";
	    var ellipsisRowFileName=document.createElement("td");
	    ellipsisRowFileName.className="fileName";
	    var ellipsisRowLineNumber=document.createElement("td");
	    ellipsisRowLineNumber.className="lineNumber";
	    ellipsisRowLineNumber.textContent="⋮";
	    var ellipsisRowWorkingCodeLine=document.createElement("td");
	    ellipsisRowWorkingCodeLine.className="workingCodeLine";
	    ellipsisRow.appendChild(ellipsisRowFileName);
	    ellipsisRow.appendChild(ellipsisRowLineNumber);
	    ellipsisRow.appendChild(ellipsisRowWorkingCodeLine);

	    var thisWorkingCode=allWorkingCode[j].getElementsByTagName("tbody")[0];
	    var theseRows=thisWorkingCode.getElementsByTagName("tr");
	    thisWorkingCode.insertBefore(ellipsisRow,theseRows[1]);

	    for(var k=0; k<theseRows.length;k++){
		var thisControlCell=document.createElement("td");
		thisControlCell.className="hiddenCodeControl";
		var thisRow=theseRows[k];
		var thisRowsCells=thisRow.getElementsByTagName("td");
		thisRow.insertBefore(thisControlCell,thisRowsCells[1]);
		if(k==0){
		    thisControlCell.appendChild(moreAnchor);
		    thisControlCell.appendChild(lessAnchor);
		    lessAnchor.click();
		}
	    }
	}
    }
}

//The following function gets called when the user clicks a control to hide code.
function hideCode(){

    //First, establish familial relations.
    var parent=this.parentNode; //This should be the control's host cell.
    var grandParent=parent.parentNode; //This should be the host cell's row.
    var greatGrandParent=grandParent.parentNode; //This should be the host cell's table.
    var siblings=parent.childNodes;

    //Second, hide the span that was clicked.
    this.style.display='none';

    //Find the span' sibling |showCode| span and display it.
    for(var i=0; i<siblings.length;i++){

	if(siblings[i].className && siblings[i].className.search('^showCode$')>=0){
	    siblings[i].style.display='inline';
	}
    }

    //Third, hide all but the first two and final rows of this table.
    var grandPiblings=greatGrandParent.getElementsByTagName("tr");
    for(var i=1; i<grandPiblings.length-1;i++){
	if(i==1){
	    grandPiblings[i].style.display='table-row';
	} else {
	    grandPiblings[i].style.display='none';
	}
    }

}

//The following function gets called when the user clicks a control to show code.
function showCode(){

    //First, establish familial relations.
    var parent=this.parentNode; //This should be the control's host cell.
    var grandParent=parent.parentNode; //This should be the host cell's row.
    var greatGrandParent=grandParent.parentNode; //This should be the host cell's table.
    var siblings=parent.childNodes;
    

    //Second, hide the span that was clicked.
    this.style.display='none';

    //Find the span' sibling |hideCode| span and display it.
    for(var i=0; i<siblings.length;i++){

	if(siblings[i].className && siblings[i].className.search('^hideCode$')>=0){
	    siblings[i].style.display='inline';
	}
    }

    //Third, show all rows of this table except the second, which should be hidden.
    var grandPiblings=greatGrandParent.getElementsByTagName("tr");
    for(var i=0; i<grandPiblings.length;i++){
	if(i==1){
	    grandPiblings[i].style.display='none';
	} else{
	    grandPiblings[i].style.display='table-row';
	}
    }
}


/*
\function{|getChapters()|}

Each slide is embedded within a |div| tag with the class name |slide|. The code that places these into an array is straightforward.
 */

function getChapters(){
	var allDivs = document.getElementsByTagName("div");
	var allChapters = new Array();
	for (var i = 0; i< allDivs.length; i++) {
	    if (allDivs[i].className.search('^chapter$')>=0) {
			allChapters[allChapters.length] = allDivs[i];
		}
	}
	return allChapters;
}

/*
\function{|createChapterIdentifers()|}

Navigation between chapters in the screen view requires each slide to be identified. This function does so by setting each chapter's |id| property to |_comppChapter#|
*/
function createChapterIdentifiers() {
	for (var n = 0; n < numberOfChapters; n++) {
		var e = arrayOfChapters[n]; 
		var id = '_comppChapter' + n.toString();
		e.setAttribute('id',id);
	}
}

/*
\function{|createChapterFrame()|}

In the screen view of prose mode, the currently selected chapter is placed within a \emph{frame}. This is a division containing a header (with navigation controls) and a footer with bibliographic information. 
 */

function createChapterFrame(){

    //An eponymous division encompasses the chapter frame's elments.
    var chapterFrame=document.createElement("div");
    chapterFrame.id="chapterFrame";
    
    //Place the chapter frame at the start of the |body| tag.
    var documentBody=document.getElementsByTagName("body")[0];
    var documentBodyChildren=documentBody.childNodes;
    documentBody.insertBefore(chapterFrame,documentBodyChildren[0]);
    
    //Divisions also contain the chapter frame's header and footer.
    var chapterHeader=document.createElement("div");
    var chapterFooter=createFooter();
    chapterHeader.id="chapterHeader";

    chapterFrame.appendChild(chapterHeader);
    chapterFrame.appendChild(chapterFooter);

    //The header contains only the navigation bar.
    var chapterNavigationBar = document.createElement("div");
    chapterNavigationBar.id="chapterNavigationBar";
    
    //The chapter navigation bar contains three children: spans to anchor the left and right control buttons and a |<ul>| containing the table of contents.
    var chapterNavigationLeftControlAnchor=document.createElement("span");
    var chapterNavigationRightControlAnchor=document.createElement("span");
    chapterNavigationLeftControlAnchor.id="chapterNavigationLeftControlAnchor";
    chapterNavigationRightControlAnchor.id="chapterNavigationRightControlAnchor";

    var bodyPages=document.getElementById("bodyPages");    
    var chapterNavigationSectionList=createBranchList(bodyPages,0);

    chapterNavigationBar.appendChild(chapterNavigationLeftControlAnchor);
    chapterNavigationBar.appendChild(chapterNavigationSectionList);
    chapterNavigationBar.appendChild(chapterNavigationRightControlAnchor);
    chapterHeader.appendChild(chapterNavigationBar);
    /*
      To finish the navigation bar's construction, we define functions for |onmouseover| and |onmouseout| that given them the desired behavior of scrolling the navigation bar to the left and the right. The helper functions |scrollNavigationBarLeft| and |scrollNavigationBarRight| are defined below.
     */
    
        //Hovering over the right navigation control makes the navigation bar scroll to the left.
    chapterNavigationRightControlAnchor.onmouseover=new Function("",'document.getElementById("chapterNavigationRightControlAnchor").style.background="blue"; intScrolling=setInterval(scrollNavigationBarLeft,10);');
    chapterNavigationRightControlAnchor.onmouseout=new Function("", 'document.getElementById("chapterNavigationRightControlAnchor").style.background="white"; clearInterval(intScrolling);');

    //Hovering over the left navigation control makes the navigation bar scroll to the right.
    chapterNavigationLeftControlAnchor.onmouseover=new Function("",'document.getElementById("chapterNavigationLeftControlAnchor").style.background="blue"; intScrolling=setInterval(scrollNavigationBarRight,10);');
    chapterNavigationLeftControlAnchor.onmouseout=new Function("", 'document.getElementById("chapterNavigationLeftControlAnchor").style.background="white"; clearInterval(intScrolling);');

    return chapterFrame;

}

function createFooter(){
    var footer=document.createElement("div");
    footer.id="footer";
    //Next, we fill the chapter frame's footer. Start with a |div| containing the document's core bibliographic information: title, authors, and date.
    var footerBibliographicInformation=document.createElement("div");
    footerBibliographicInformation.id="footerBibliographicInformation";
    footer.appendChild(footerBibliographicInformation);

    //Create a |span| containing the document's title and add it to the footer's bibliographic information.
    var footerTitle=document.createElement("span");
    footerTitle.id="footerTitle";

    var documentTitle=document.getElementById("documentTitle");
    if(documentTitle){
	var documentTitleContent=documentTitle.childNodes;
	var thisChildsClone;

	for(var i=0;i<documentTitleContent.length;i++){

	    thisChildsClone=documentTitleContent[i].cloneNode(true);
	    footerTitle.appendChild(thisChildsClone);

	}
    } else {
    }

    footerBibliographicInformation.appendChild(footerTitle);

    //Add a span containing the document's authors to the bibliographic information.
    var footerAuthorList=document.createElement("span");
    footerAuthorList.id="footerAuthorList";

    var authorList=document.getElementById("authorList");
    if(authorList){
	var authorListContent=authorList.childNodes;

	for(var j=0;j<authorListContent.length;j++){
	    thisChildsClone=authorListContent[j].cloneNode(true);
	    footerAuthorList.appendChild(thisChildsClone);
	}
    } else {
    }
    footerBibliographicInformation.appendChild(footerAuthorList);    

    //Add a span containing the document's date to the bibliographic information.
    var footerDate=document.createElement("span");
    footerDate.id="footerDate";

    var documentDate=document.getElementById("documentDate");
    if(documentDate){
	var documentDateContent=documentDate.childNodes;
    
	for(var l=0;l<documentDateContent.length;l++){
	    thisChildsClone=documentDateContent[l].cloneNode(true);
	    footerDate.appendChild(thisChildsClone);
	}
    } else {
    }
    footerBibliographicInformation.appendChild(footerDate);


    //Add a div containing the document's union bugs to the footer.
    var footerUnionBugs=document.createElement("div");
    footerUnionBugs.id="footerUnionBugs";

    var unionBugs=document.getElementById("unionBugs");
    if(unionBugs){
	var unionBugsContent=unionBugs.childNodes;

	for(var k=0;k<unionBugsContent.length;k++){
	    thisChildsClone=unionBugsContent[k].cloneNode(true);
	    footerUnionBugs.appendChild(thisChildsClone);
	}
    } else {
    }
    footer.appendChild(footerUnionBugs);

    //Add a |div| containing the document's classification directive to the footer.
    var footerClassification=document.createElement("div");
    footerClassification.id="footerClassification";

    var documentClassification=document.getElementById("classification");
    if(documentClassification){

	var documentClassificationContent=documentClassification.childNodes;

	for(var m=0;m<documentClassificationContent.length;m++){
	    thisChildsClone=documentClassificationContent[m].cloneNode(true);
	    footerClassification.appendChild(thisChildsClone);
	}

    } else {
    }
    footer.appendChild(footerClassification);

    return footer;
}

/*
  \function{|scrollNavigationBarLeft()|}
 */
function scrollNavigationBarLeft() {
    var navigationBar=document.getElementById("chapterNavigationBar");
    var navigationBarTotalWidth=navigationBar.scrollWidth;
    var windowWidth=window.innerWidth;
    if(navigationBarLeftOffset+scrollSpeed<navigationBarTotalWidth-windowWidth+30){//The |30| is a fudge factor so that the navigation control doesn't obscure the navigation bar's last link.
	navigationBarLeftOffset+=scrollSpeed;
    }
    navigationBar.style.left=-navigationBarLeftOffset+"px";
    //The following line seems to be necessary to prevent the navigation bar's content from becoming clipped.
    navigationBar.style.width=navigationBarTotalWidth+"px";

}

/* 
   \function{|scrollNavigationBarRight()|}
 */ 
function scrollNavigationBarRight() {
    var navigationBar=document.getElementById("chapterNavigationBar");
    var navigationBarTotalWidth=navigationBar.scrollWidth;
    if (navigationBarLeftOffset>scrollSpeed){
	navigationBarLeftOffset-=scrollSpeed;
    }
    navigationBar.style.left=-navigationBarLeftOffset+"px";
    //The following line seems to be necessary to prevent the navigation bar's content from becoming clipped.
    navigationBar.style.width=navigationBarTotalWidth+"px";

}

/*
\function{|redirectInternalLinks()|}
*/

function redirectInternalLinks(element){

    var arrayOfAnchors=element.getElementsByTagName('a'); //Put all of the anchors into an array.

//Determine the browser's current target. We need this to classify links as internal and external.
    var thisPagesURL = window.location.href; //Current page browser is pointed to
    thisPagesURL = thisPagesURL.slice(0, thisPagesURL.length - window.location.hash.length); //Drop anything past a hash. What remains is the ``root'' URL.
    
//Cycle through the anchors. For each one, determine whether it is internal and (if so) make the appropriate changes.
    for (var i=0; i<arrayOfAnchors.length;i++) {
	var hrefContents=arrayOfAnchors[i].href;
	var targetURL = hrefContents.match('^'+thisPagesURL+'#[_a-zA-Z0-9]+'); //Internal anchors begin with a hash sign and may contain only letters, numbers, and the underscore.
	if(targetURL){ //The variable |targetURL| will evaluate to |false| unless there was a match above.

	    //Get the target element's identifier from |hrefContents| and retrieve the target itself.
	    var hashLocation=hrefContents.search('#[_a-zA-Z0-9]+');
	    var targetId=hrefContents.slice(hashLocation+1,hrefContents.length);
	    var target=document.getElementById(targetId);

	    var targetChapter;

	    /*If |target| is null, then |targetURL| points to a location not currently part of the document. For such an anchor, we ensure that it opens a new window. */
	    if(target==null){
		arrayOfAnchors[i].onclick= new Function("","window.open('"+hrefContents+"');" );
	    }
	    /*
	    If the target is on a slide, then add an event handler to |onclick| that swaps the current slide for the desired slide.
	    */
	    else if (targetChapter = encompassingChapter(target)) {
//Find the encompassing slide's number, which is embedded in its |id| by |createSlideIdentifiers|.
		var targetChapterNumber=targetChapter.id.match('[0-9]+');
//Determine the percentage vertical offset for the target. This depends on whether or not this is a caption, a chapter heading, or something else.	    		
		var offsetPercentage=50;
		if(target.className.search('^chapter')>=0){
		    offsetPercentage=0;
		}
		if(target.className.search('^caption')>=0){
		    offsetPercentage=66;
		}
//Create the event handler. This only swaps the slides if |isDisplayingSlideScreen| is true.						     
		arrayOfAnchors[i].onclick = new Function("","if(isDisplayingChapterScreen){removeChapterFromFrame(currentChapterNumber);currentChapterNumber="+targetChapterNumber+"; insertChapterIntoFrame("+targetChapterNumber+"); window.location.href = \"\#"+targetId+"\"; verticallyPositionCurrentElement("+offsetPercentage+"); return false;}");
	    }
	} 
	else { //The link is external. Redirect the user to an external window if it is clicked.
	    arrayOfAnchors[i].onclick = new Function(""," if (isDisplayingChapterScreen){ var externalLinkTarget=window.open('"+hrefContents+"','externalLinkView'); externalLinkTarget.focus(); return false;}");
	}
    }
}

/*
\function{|encompassingChapter(element)|}

The function to return an element's encompassing chapter is recursive and straightforward.

 */

function encompassingChapter(element){

    if (element == null || element.nodeName=='BODY') return null;
    else if (element.className=="chapter" && element.tagName=="DIV") return element;
    else return encompassingChapter(element.parentNode);

}

/*
\function{|division(e)|}
The function for returning the header level from an element's tag relies only on a simple regular expression.
*/

function division(e) {
    var thisTag = e.nodeName.toLowerCase();
    if(thisTag.match('^h[1-6]$')){
	return thisTag.slice(1);
    } else {
	return false;
    }
}

/*

\function{|nextSlideOrHighHeadingDecendingFromParent(e,d)|}	  
The next function returns the next slide or header with level at or below |d| decending from the element's parent.
This function works recursively. If the given element has children, then the first child is examined to see if it fits the bill. If not, the function calls itself with the child as its argument. If this call returns a non-null object, return it. If not, then the argument's next sibling is examined. If this call returns a non-null object, the the function returns it. If neither call returns a non-null object, then the function returns null.
*/
function nextSlideOrHighHeadingDecendingFromParent(e,d) {
    var slideInChildren;
    var slideInSiblings;
    var childNodesDivision;
    var siblingNodesDivision;

    /* We first check to see if the given element has a first child. If it fits the bill, return it. If not, call this function with the first child as its argument and return any non-null output from this call. */
    if (e.firstChild) {
	if ((childNodesDivision=division(e.firstChild)) && childNodesDivision <= d) {//The element's first child is a division with a low enough level.
	    return e.firstChild;
	}
	else if ((e.firstChild.className) && (e.firstChild.className.toLowerCase().match("slide"))) { //The first child has the class |slide|, so return it.
	    return e.firstChild;
	} else { //The first child does not have the class |slide|, so call this function with the first child as its argument.
	    slideInChildren=nextSlideOrHighHeadingDecendingFromParent(e.firstChild,d);
	    if(slideInChildren){
		return slideInChildren;
	    }
	}
    }
    /*
      If execution continues here, then there is no slide or low-level heading decending from |e|. Check to see if |e| has a next sibling. If it is a slide or low-level division, we return it. If not, we call this function with the next sibling as its argument. We return the output from this call, whether or not it is null.
       */
    if(e.nextSibling) {//The given element has a sibling.
	if ((siblingNodesDivision=division(e.nextSibling)) && (siblingNodesDivision <=d)){//The element's next sibling is a division with a low enough level.
	    return e.nextSibling;
	}
	else if ((e.nextSibling.className) && (e.nextSibling.className.toLowerCase().match("slide"))) { //The next sibling has the class |slide|, so return it.
	    return e.nextSibling;
	} else { //The next sibling does not have the class |slide|, so call this function with the next sibling as its argument.
	    slideInSiblings=nextSlideOrHighHeadingDecendingFromParent(e.nextSibling,d);
	    if(slideInSiblings){
		return slideInSiblings;
	    } else { //If we have made it here, there is no slide in the argument's children, its siblings, or its siblings' children. Return null.
		return null;
	    }
	}
    } 
    /*
      If we have reached this point, then |e| has no sibling and its children (if any) contain no slides. End the search and return |null|.
     */
    else {
	return null;
    }

}

/*
\function{|isInSlideFrame(e)|}
 */


function isInSlideFrame(e){
    if (e==null || e.nodeName=='BODY'){
	return false;
    }

    if (e.id=="slideFrame"){
	return true;
    } else {
	return isInSlideFrame(e.parentElement);
    }
}

/*
\function{|createHandoutFooters()|}

The print view of slide mode creates handouts for presentations. It is standard for each page of these handouts to have a footer with relevant bibliographic and information classification information.  This function creates these footers as child divisions of each |slide| division.

 */

function createHandoutFooters(){

    //Retrieve relevant information from the front matter.
    var documentTitle=document.getElementById("documentTitle");
    if(documentTitle){
	var documentTitleContent=documentTitle.childNodes;
    }

    var documentAuthorList=document.getElementById("authorList");
    if(documentAuthorList){
	var documentAuthorListContent=documentAuthorList.childNodes;
    }

    var documentUnionBugs=document.getElementById("unionBugs");
    if(documentUnionBugs){
	var documentUnionBugsContent=documentUnionBugs.childNodes;
    }

    var documentDate=document.getElementById("documentDate");
    if(documentDate){
	var documentDateContent=documentDate.childNodes;
    }

    var documentClassification=document.getElementById("classification"); //This |id| should really be changed to conform with the rest of the front matter |id|s.
    if(documentClassification){
	var documentClassificationContent=documentClassification.childNodes;
    }

    //Cycle through the individual slides/sheets and create a printable footer for each one.
    var thisSheetsFooter;
    var thisFootersBibliographicInformation;
    var thisFootersTitle;
    var thisFootersAuthorList;
    var thisFootersUnionBugs;
    var thisFootersDate;
    var thisFootersClassification;
    var thisChildsClone;
    var j;

    for(var i=0;i<arrayOfSlides.length;i++){

	//Create the footer division.
	thisSheetsFooter=document.createElement("div");
	thisSheetsFooter.className="handoutFooter";
	arrayOfSlides[i].appendChild(thisSheetsFooter);

	//Create and populate the division to contain bibliographic information.
	thisFootersBibliographicInformation=document.createElement("div");
	thisFootersBibliographicInformation.className="handoutFooterBibliographicInformation";
	thisSheetsFooter.appendChild(thisFootersBibliographicInformation);
	
	thisFootersTitle=document.createElement("span");
	thisFootersTitle.className="handoutFooterTitle";
	thisFootersBibliographicInformation.appendChild(thisFootersTitle);
	
	if(documentTitleContent){
	    for(j=0;j<documentTitleContent.length;j++){
		thisChildsClone=documentTitleContent[j].cloneNode(true);
		thisFootersTitle.appendChild(thisChildsClone);
	    }
	}

	thisFootersAuthorList=document.createElement("span");
	thisFootersAuthorList.className="handoutFooterAuthorList";
	thisFootersBibliographicInformation.appendChild(thisFootersAuthorList);
	
	if(documentAuthorListContent){
	    for(j=0;j<documentAuthorListContent.length;j++){
		thisChildsClone=documentAuthorListContent[j].cloneNode(true);
		thisFootersAuthorList.appendChild(thisChildsClone);
	    }
	}

	thisFootersDate=document.createElement("span");
	thisFootersDate.className="handoutFooterDate";
	thisFootersBibliographicInformation.appendChild(thisFootersDate);
	
	if(documentDateContent){
	    for(j=0;j<documentDateContent.length;j++){
		thisChildsClone=documentDateContent[j].cloneNode(true);
		thisFootersDate.appendChild(thisChildsClone);
	    }
	}

	//Create and populate the division to contain the union bugs.
	thisFootersUnionBugs=document.createElement("div");
	thisFootersUnionBugs.className="handoutFooterUnionBugs";
	thisSheetsFooter.appendChild(thisFootersUnionBugs);

	if(documentUnionBugsContent){
	    for(j=0;j<documentUnionBugsContent.length;j++){
		thisChildsClone=documentUnionBugsContent[j].cloneNode(true);
		thisFootersUnionBugs.appendChild(thisChildsClone);
	    }
	}

	//Create and populate the division to contain the document's classification.
	thisFootersClassification=document.createElement("div");
	thisFootersClassification.className="handoutFooterClassification";
	thisSheetsFooter.appendChild(thisFootersClassification);

	if(documentClassificationContent){
	    for(j=0;j<documentClassificationContent.length;j++){
		thisChildsClone=documentClassificationContent[j].cloneNode(true);
		thisFootersClassification.appendChild(thisChildsClone);
	    }
	}

	//Create and populate this slide's handout counter.
	if(i>0){
	    thisFootersCounter=document.createElement("div");
	    thisFootersCounter.className="handoutFooterCounter";
	    thisSheetsFooter.appendChild(thisFootersCounter);

	    thisFootersCounterContent=document.createTextNode((i+1)+'/'+(numberOfSlides));
	    thisFootersCounter.appendChild(thisFootersCounterContent);
	}
	    
    }

}


/*
\subsection{Document Management}
*/

function processKeyInput(evt){

    //Store the keys ASCII codes in variables.

    var keyH=72;
    var keyP=80;
    var keyS=83;
    var keySpaceBar = 32;
    var keyRightArrow = 39;
    var keyDownArrow = 40;
    var keyLeftArrow = 37;
    var keyUpArrow = 38;

    //Capture the keystroke.
    if(evt) {
	var thisKey = evt.which;
    }
    else {
	var thisKey=window.event.keyCode;
    }


    switch(thisKey){

    case keyS: //Toggles between slide mode and prose mode.
	if (isDisplayingChapterScreen){
	    //The user wishes to switch to slide mode. First, hide everything and apply the appropriate style sheets.
	    removeChapterScreenStyle();
	    addSlideScreenStyle();

	    isDisplayingChapterScreen=false;
	    isDisplayingSlideScreen=true;
	    
            //Run |processResizeWindow| so that the navigation controls appear on startup if needed.
	    processResizeWindow();
	    
	    //If the current chapter number does not match the current slideshow number, then we need to destroy the currently resident slideshow and create one for the current chapter.
	    if (currentChapterNumber != currentSlideShowNumber){
		destroySlideShow(arrayOfChapters[currentSlideShowNumber]);
		currentSlideShowNumber=currentChapterNumber;
		if(currentChapterNumber>0){
		    createSlideShow(arrayOfChapters[currentChapterNumber]);
		} else {
		    createFrontmatterSlideShow();
		}
	    }
	    
	} else if(isDisplayingSlideScreen){
	    removeSlideScreenStyle();
	    addChapterScreenStyle();
	    processResizeWindow();

	    isDisplayingProseScreen=true;
	    isDisplayingSlideScreen=false;

	    isDisplayingChapterScreen=true;
	    isDisplayingSlideScreen=false;

	} else if(isDisplayingProsePrint){ 
	    removeProsePrintStyle();
	    addSlidePrintStyle();

	    isDisplayingProsePrint=false;
	    isDisplayingSlidePrint=true;
	} else if(isDisplayingSlidePrint){
	    removeSlidePrintStyle();
	    addProsePrintStyle();

	    isDisplayingSlidePrint=false;
	    isDisplayingProsePrint=true;
	}
	break;
	    
    case keyP:
	if (isDisplayingProseScreen){
	    removeProseScreenStyle();
	    addProsePrintStyle();

	    isDisplayingProseScreen=false;
	    isDisplayingProsePrint=true;
	} else if(isDisplayingProsePrint) {
	    removeProsePrintStyle();
	    addProseScreenStyle();

	    isDisplayingProseScreen=true;
	    isDisplayingProsePrint=false;
	} else if(isDisplayingSlideScreen){
	    removeSlideScreenStyle();
	    addSlidePrintStyle();

	    isDisplayingSlideScreen=false;
	    isDisplayingSlidePrint=true;
	    
	    removeSlideFromFrame();
	} else if(isDisplayingSlidePrint){
	    removeSlidePrintStyle();
	    addSlideScreenStyle();

	    processResizeWindow();

	    isDisplayingSlidePrint=false;
	    isDisplayingSlideScreen=true;

	    insertSlideIntoFrame(currentSlideNumber);
	} else if(isDisplayingCodeScreen){
	    removeCodeScreenStyle();
	    addCodePrintStyle();

	    isDisplayingCodeScreen=false;
	    isDisplayingCodePrint=true;
	} else if(isDisplayingCodePrint){
	    removeCodePrintStyle();
	    addCodeScreenStyle();

	    isDisplayingCodePrint=false;
	    isDisplayingCodeScreen=true;
	}
	    
	break;
       
    case keyH: //The user has requested some help.
	if(isDisplayingProseScreen||isDisplayingProsePrint){
	    alert("C\tToggle code mode.\nS\tToggle slide mode.\nP\tToggle print view.\nH\tDisplay this help screen.");
	} else if(isDisplayingCodeScreen||isDisplayingCodePrint){
	    alert("C\tToggle code code.\nP\tToggle print view.\nH\tDisplay this help screen.");
	} else if(isDisplayingSlidePrint) {
	    alert("S\tToggle slide mode.\nP\tToggle print view.\nH\tDisplay this help screen.");
	} else if(isDisplayingSlideScreen){
	    alert("Space Bar, \u2192, or \u2193\tAdvance one slide.\n\u2190 or \u2191\t\t\tRetreat one slide.\nS\t\t\t\tToggle view of slide show.\nP\t\t\t\tToggle print view.\nH\t\t\t\tDisplay this help screen.");
	}

	/*
	  The remaining key commands control the slide show.

	 */
    case keyRightArrow:
    case keyDownArrow:
    case keySpaceBar:
	if (isDisplayingSlideScreen && (currentSlideNumber+1<numberOfSlides)){
	    removeSlideFromFrame();
	    currentSlideNumber++;
	    insertSlideIntoFrame(currentSlideNumber);
	}
	break;

    case keyLeftArrow:
    case keyUpArrow:
	if(isDisplayingSlideScreen && (currentSlideNumber>0)){
	    removeSlideFromFrame();
	    currentSlideNumber--;
	    insertSlideIntoFrame(currentSlideNumber);
	}
	break;

    }

}

//Function to resize required components when the window gets created or resized.
function processResizeWindow(){

    //If the window has been resized, there is not enough room to display the navigation bar, and the scroll controls are not visible, then add the scroll controls.
    var navigationBar=document.getElementById("chapterNavigationBar");
    var leftNavigationScrollControl=document.getElementById("chapterNavigationLeftControlAnchor");
    var rightNavigationScrollControl=document.getElementById("chapterNavigationRightControlAnchor");

    var leftNavigationScrollControlContents;
    var rightNavigationScrollControlContents;

    var navigationBarWidth=navigationBar.scrollWidth;
    var windowWidth=window.innerWidth;
    
    if ((windowWidth<navigationBarWidth) && (!navigationScrollControlVisible)){

	var leftControlText=document.createTextNode("\u21E6");
	leftNavigationScrollControl.appendChild(leftControlText);

	var rightControlText=document.createTextNode("\u21E8");
	rightNavigationScrollControl.appendChild(rightControlText);
	navigationScrollControlVisible=true;

    } 

    //If the window has been resized, there is not enough room to display the navigation bar, and the scroll controls are visible, then move the navigation bar to the right so that as much of it as possible is showing.
    if ((windowWidth<navigationBarWidth) && navigationScrollControlVisible){
	
	if (navigationBarLeftOffset>navigationBarWidth-windowWidth+30){
	    navigationBarLeftOffset=navigationBarWidth-windowWidth+30;
	    navigationBar.style.left=-navigationBarLeftOffset+"px";
	    navigationBar.style.width=navigationBarWidth+"px";
	}

    }

    //If the window has been resized and there is enough room to display the navigation bar, remove the scroll controls and any existing left offset.
    if ((windowWidth>=navigationBarWidth) && navigationScrollControlVisible){
	
	var leftNavigationScrollControlContents=leftNavigationScrollControl.firstChild;
	leftNavigationScrollControl.removeChild(leftNavigationScrollControlContents);

	var rightNavigationScrollControlContents=rightNavigationScrollControl.firstChild;
	rightNavigationScrollControl.removeChild(rightNavigationScrollControlContents);

	navigationScrollControlVisible=false;

	navigationBarLeftOffset=0;
	navigationBar.style.left=-navigationBarLeftOffset+"px";
	navigationBar.style.width=navigationBarWidth+"px";
	
    }
}

//The following functions put a chapter into the frame and remove it from the frame.
function insertChapterIntoFrame(n){

    var chapterFrame=document.getElementById("chapterFrame");
    var chapterFooter=document.getElementById("chapterFooter");
    highlightNavigationBarLink(arrayOfChapters[n]);
    currentChapterClone=arrayOfChapters[n].cloneNode(true);
    redirectInternalLinks(arrayOfChapters[n]);
    chapterFrame.insertBefore(arrayOfChapters[n]);
}

function removeChapterFromFrame(n){

    var chapterFrame=document.getElementById("chapterFrame");
    chapterFrame.removeChild(arrayOfChapters[n]);
    bodyPages.appendChild(arrayOfChapters[n])
}

// |slideCounter()| changes the counter on the bottom of the page
// The counter lives in it's own <div> with id of |"slideCounter"|.
function slideCounter() {
    
    //Retrieve the |slideCounter| element.
    var slideCounterDiv=document.getElementById('slideCounter');
    
    //Remove any existing contents.
    var oldSlideCounterDivContent=slideCounterDiv.childNodes[0];
    if(oldSlideCounterDivContent){
	slideCounterDiv.removeChild(oldSlideCounterDivContent);
    }

    //Place the new counter into it.
    var newSlideCounterDivContent=document.createTextNode((currentSlideNumber+1)+'/'+(numberOfSlides));
    slideCounterDiv.appendChild(newSlideCounterDivContent);

    //Choose whether or not the slide counter should be displayed.
    if (currentSlideNumber == 0) { //Don't show slide count in title slide
	slideCounterDiv.style.visibility = 'hidden';
    } else {
	slideCounterDiv.style.visibility = 'visible';
    }
}


//Function to link each slide to a navigation bar list item.
function highlightNavigationBarLink(aChapter) {
    
    //Arrange all of the navigation bar's anchors into an  array.
    var navigationBar=document.getElementById("chapterNavigationBar");
    var arrayOfAnchors=navigationBar.getElementsByTagName("a");

    //Examine the navigation bar's links for the chapter's id.

    var aChapterId=aChapter.id;
    //The chapter's id does \emph{not} correspond to the |id| property of its heading, and it is this we need to match with the anchor's target. Conveniently, these headings are each chapter's first child.
    aChapterHeadingId=aChapter.firstChild.id;
    

	for(var i=0; i<arrayOfAnchors.length; i++){
	    
	    //If the anchor's |href| ends with the chapter's |id|, then style it red.
	    if (arrayOfAnchors[i].href.match("#"+aChapterHeadingId+"$")){
		arrayOfAnchors[i].style.color="#C98300";
	    } else { //Otherwise, style it green.
		arrayOfAnchors[i].style.color="#08C";
	    }
	    
	}
}


//Function to link each slide to a navigation bar list item.
function highlightSlideNavigationBarLink(aSlide) {
    
    //We begin with finding the ``youngest'' decendent of the given slide, which can be the slide itself.
    var childObj;
    var parentObj = aSlide;
    
    while (childObj=parentObj.lastChild){
	parentObj=childObj;
    }

    //Next, find the encompassing section of the youngest decendent.
    var thisSection=encompassingSection(parentObj);

    //Arrange all of the navigation bar's anchors into an  array.
    var navigationBar=document.getElementById("slideNavigationBar");
    var arrayOfAnchors=navigationBar.getElementsByTagName("a");

    //If |thisSection| is null, then there is nothing to highlight. Set all of the links to the base color. Otherwise, we proceed to examine all of the navigation bar's links.
    
    if (thisSection){

	var thisSectionId=thisSection.id;

	for(var i=0; i<arrayOfAnchors.length; i++){
	    
	    //If the anchor's |href| ends with the encompassing section's |id|, then style it red.
	    if (arrayOfAnchors[i].href.match("#"+thisSectionId+"$")){
		arrayOfAnchors[i].style.color="#C98300";
	    } else { //Otherwise, style it green.
		arrayOfAnchors[i].style.color="#08C";
	    }
	    
	}

    } else {
	for(var i=0; i<arrayOfAnchors.length; i++){
	    arrayOfAnchors[i].style.color="#08c";
	}
    }
}

//Function to find the given slide's encompassing section.

function encompassingSection(e){

    var previousSibling;
    var parent;
    //See if the element has a previous sibling.
    if (previousSibling=e.previousSibling){ //If there is a previous sibling, then see if it is a division. If so, we are done. If not, call this function with the previous sibling as the argument.
	if ((d=division(previousSibling)) && d==3){
	    return previousSibling;
	} else {
	    return encompassingSection(previousSibling);
	}
    } else if (parent=e.parentNode) {//If there is no previous sibling, is there a parent node?
	if ((d=division(parent)) && d==3){ //If the parent node is a section, we are done. Otherwise, call this function with the parent as the argument.
	    return parent;
	} else {
	    return encompassingSection(parent);
	}
    } else {//The element has no previous sibling or parent, so the search failed. Return null.

	return null;

    }
}

function createFrontmatterSlideShow(){

    //Create the title slide. 

    var excludefromtextDivision=document.createElement("div");
    excludefromtextDivision.className="excludefromtext";
    //Place the |excludefromtext| division at the start of the given chapter.
    var chapterChildren=arrayOfChapters[0].childNodes;
    arrayOfChapters[0].insertBefore(excludefromtextDivision,chapterChildren[0]);

    var titleSlideDivision=document.createElement("div");
    titleSlideDivision.className="titleSlide";
    excludefromtextDivision.appendChild(titleSlideDivision);

    var titleSlide=document.createElement("div");
    titleSlide.className="slide";
    titleSlideDivision.appendChild(titleSlide);

    //Put the document title, cover art, and list of authors into the slide.
    var documentTitle=document.getElementById("documentTitle");
    var titleSlideTitle=documentTitle.cloneNode(true);
    titleSlideTitle.className="titleSlideTitle";
    titleSlide.appendChild(titleSlideTitle);

    var coverArt=document.getElementById("coverArt");
    var titleSlideCoverArt=coverArt.cloneNode(true);
    titleSlideCoverArt.className="titleSlideCoverArt";
    titleSlideCoverArt.id="";
    titleSlide.appendChild(titleSlideCoverArt);

    var authorList=document.getElementById("authorList");
    var titleSlideAuthorList=authorList.cloneNode(true);
    titleSlideAuthorList.className="titleSlideAuthorList";
    titleSlide.appendChild(titleSlideAuthorList);

    //With that completed, gather the slides together.
    arrayOfSlides=getSlides(arrayOfChapters[0]);
    numberOfSlides=arrayOfSlides.length;
    createSlideIdentifiers();

    //Create the slide frame for this show. Unlike all of the others, this contains has no navigation bar. 

    //An eponymous division encompasses the slide frame's elments.
    var slideFrame=document.createElement("div");
    slideFrame.id="slideFrame";
    
    //Place the slide frame at the start of the |body| tag.
    var documentBody=document.getElementsByTagName("body")[0];
    var documentBodyChildren=documentBody.childNodes;
    documentBody.insertBefore(slideFrame,documentBodyChildren[0]);
    
    //Divisions also contain the slide frame's header and footer.
    var slideHeader=document.createElement("div");
    var slideFooter=document.createElement("div");
    slideHeader.id="slideHeader";
    slideFooter.id="slideFooter";
    var slideNavigationBar = document.createElement("div");
    slideNavigationBar.id="slideNavigationBar";
    slideHeader.appendChild(slideNavigationBar);

    slideFrame.appendChild(slideHeader);
    slideFrame.appendChild(slideFooter);

    //Next, we fill the slide footer. Start with a division to contain the slide counter.
    var slideCounter=document.createElement("div");
    slideCounter.id="slideCounter";
    slideFooter.appendChild(slideCounter);

    //Add a |div| containing the document's bibliographic information: document title, chapter title, authors, and date.
    var footerBibliographicInformation=document.createElement("div");
    footerBibliographicInformation.id="slideFooterBibliographicInformation";
    slideFooter.appendChild(footerBibliographicInformation);

    //Create a |span| containing the document's title and add it to the footer's bibliographic information.
    var footerTitle=document.createElement("span");
    footerTitle.id="slideFooterTitle";

    var documentTitle=document.getElementById("documentTitle");
    if(documentTitle){
	var documentTitleContent=documentTitle.childNodes;
	var thisChildsClone;

	for(var i=0;i<documentTitleContent.length;i++){

	    thisChildsClone=documentTitleContent[i].cloneNode(true);
	    footerTitle.appendChild(thisChildsClone);

	}
    } else {
    }

    footerBibliographicInformation.appendChild(footerTitle);

    //Add a span containing the document's authors.
    var footerAuthorList=document.createElement("span");
    footerAuthorList.id="slideFooterAuthorList";

    var authorList=document.getElementById("authorList");
    if(authorList){
	var authorListContent=authorList.childNodes;

	for(var j=0;j<authorListContent.length;j++){
	    thisChildsClone=authorListContent[j].cloneNode(true);
	    footerAuthorList.appendChild(thisChildsClone);
	}
    } else {
    }
    footerBibliographicInformation.appendChild(footerAuthorList);    

    //Add a div containing the document's union bugs.
    var footerUnionBugs=document.createElement("div");
    footerUnionBugs.id="slideFooterUnionBugs";

    var unionBugs=document.getElementById("unionBugs");
    if(unionBugs){
	var unionBugsContent=unionBugs.childNodes;

	for(var k=0;k<unionBugsContent.length;k++){
	    thisChildsClone=unionBugsContent[k].cloneNode(true);
	    footerUnionBugs.appendChild(thisChildsClone);
	}
    } else {
    }
    slideFooter.appendChild(footerUnionBugs);

    //Add a span containing the document's date.
    var slideFooterDate=document.createElement("span");
    slideFooterDate.id="slideFooterDate";

    var documentDate=document.getElementById("documentDate");
    if(documentDate){
	var documentDateContent=documentDate.childNodes;
    
	for(var l=0;l<documentDateContent.length;l++){
	    thisChildsClone=documentDateContent[l].cloneNode(true);
	    slideFooterDate.appendChild(thisChildsClone);
	}
    } else {
    }
    footerBibliographicInformation.appendChild(slideFooterDate);

    //Add a |div| containing the document's classification directive.
    var slideFooterClassification=document.createElement("div");
    slideFooterClassification.id="slideFooterClassification";

    var documentClassification=document.getElementById("classification");
    if(documentClassification){

	var documentClassificationContent=documentClassification.childNodes;

	for(var m=0;m<documentClassificationContent.length;m++){
	    thisChildsClone=documentClassificationContent[m].cloneNode(true);
	    slideFooterClassification.appendChild(thisChildsClone);
	}

    } else {
    }
    slideFooter.appendChild(slideFooterClassification);

    //Initialize the show with its title slide.
    currentSlideNumber=0;
    insertSlideIntoFrame(currentSlideNumber);
}

function createSlideShow(aChapter){

    //Create a title slide for this chapter. The slide itself gets placed at the front of the chapter wrapped in a |titleSlide| span.
    createTitleSlide(aChapter);

    //Put all of the given chapter's slides into an array.
    arrayOfSlides=getSlides(aChapter);
    numberOfSlides=arrayOfSlides.length;
    createSlideIdentifiers();
    //Create the frame for the slide show.
    createSlideFrame(aChapter);

    //Initialize the slide show with the cover slide.
    currentSlideNumber=0;
    insertSlideIntoFrame(currentSlideNumber);
}

function destroySlideShow(aChapter){

    //Remove the title slide from the given chapter.
    destroyTitleSlide(aChapter);
    
    //Destroy the slide frame.
    destroySlideFrame(aChapter);
}


function getSlides(aChapter){
	var allDivs = aChapter.getElementsByTagName("div");
	var allSlides = new Array();
	for (var i = 0; i< allDivs.length; i++) {
	    if (allDivs[i].className.search('^slide$')>=0) {
		allSlides[allSlides.length] = allDivs[i];
	    }
	}
	return allSlides;
}


function createTitleSlide(aChapter){

    var excludefromtextDivision=document.createElement("div");
    excludefromtextDivision.className="excludefromtext";
    //Place the |excludefromtext| division at the start of the given chapter.
    var chapterChildren=aChapter.childNodes;
    aChapter.insertBefore(excludefromtextDivision,chapterChildren[0]);

    var titleSlideDivision=document.createElement("div");
    titleSlideDivision.className="titleSlide";
    excludefromtextDivision.appendChild(titleSlideDivision);

    var titleSlide=document.createElement("div");
    titleSlide.className="slide";
    titleSlideDivision.appendChild(titleSlide);

    //Put the chapter title, document title, cover art, and list of authors into the slide.
    var documentTitle=document.getElementById("documentTitle");
    var titleSlideTitle=documentTitle.cloneNode(true);
    titleSlideTitle.className="titleSlideTitle";
    titleSlide.appendChild(titleSlideTitle);

    var coverArt=document.getElementById("coverArt");
    var titleSlideCoverArt=coverArt.cloneNode(true);
    titleSlideCoverArt.className="titleSlideCoverArt";
    titleSlide.appendChild(titleSlideCoverArt);

    var authorList=document.getElementById("authorList");
    var titleSlideAuthorList=authorList.cloneNode(true);
    titleSlideAuthorList.className="titleSlideAuthorList";
    titleSlide.appendChild(titleSlideAuthorList);

    //Create a |span| containing the chapter's title.
    var titleSlideChapterTitle=document.createElement("span");
    titleSlideChapterTitle.id="titleSlideChapterTitle";
    titleSlide.appendChild(titleSlideChapterTitle);

    var chapterTitle=aChapter.getElementsByTagName("h2")[0];
    titleSlideChapterTitle.className=chapterTitle.className;
    if(chapterTitle){
	var chapterTitleContent=chapterTitle.childNodes;
	var thisChildsClone;
	for(var i=0;i<chapterTitleContent.length;i++){
	    thisChildsClone=chapterTitleContent[i].cloneNode(true);
	    titleSlideChapterTitle.appendChild(thisChildsClone);
	}
    }

}

function destroyTitleSlide(aChapter){
    var titleSlide=aChapter.getElementsByClassName("titleSlide");
    aChapter.removeChild(titleSlide[0].parentElement);
}

function createSlideFrame(aChapter){

    //An eponymous division encompasses the slide frame's elments.
    var slideFrame=document.createElement("div");
    slideFrame.id="slideFrame";
    
    //Place the slide frame at the start of the |body| tag.
    var documentBody=document.getElementsByTagName("body")[0];
    var documentBodyChildren=documentBody.childNodes;
    documentBody.insertBefore(slideFrame,documentBodyChildren[0]);
    
    //Divisions also contain the slide frame's header and footer.
    var slideHeader=document.createElement("div");
    var slideFooter=document.createElement("div");
    slideHeader.id="slideHeader";
    slideFooter.id="slideFooter";

    slideFrame.appendChild(slideHeader);
    slideFrame.appendChild(slideFooter);

    //The header contains (at this point) only the navigation bar.
    var slideNavigationBar = document.createElement("div");
    slideNavigationBar.id="slideNavigationBar";
    
    //The slide navigation bar contains three children: spans to anchor the left and right control buttons and a |<ul>| containing the table of contents.
    var slideNavigationLeftControlAnchor=document.createElement("span");
    var slideNavigationRightControlAnchor=document.createElement("span");
    slideNavigationLeftControlAnchor.id="slideNavigationLeftControlAnchor";
    slideNavigationRightControlAnchor.id="slideNavigationRightControlAnchor";

    var bodyPages=document.getElementById("bodyPages");    
    //Create the navigation list of the chapter's sections.
    var slideNavigationSectionList=createBranchList(aChapter,1);
    redirectSlideNavigationBarLinks(slideNavigationSectionList);

    slideNavigationBar.appendChild(slideNavigationLeftControlAnchor);
    slideNavigationBar.appendChild(slideNavigationSectionList);
    slideNavigationBar.appendChild(slideNavigationRightControlAnchor);
    slideHeader.appendChild(slideNavigationBar);
    /*
      To finish the navigation bar's construction, we define functions for |onmouseover| and |onmouseout| that given them the desired behavior of scrolling the navigation bar to the left and the right. The helper functions |scrollNavigationBarLeft| and |scrollNavigationBarRight| are defined below.
     */
    
        //Hovering over the right navigation control makes the navigation bar scroll to the left.
    slideNavigationRightControlAnchor.onmouseover=new Function("",'document.getElementById("slideNavigationRightControlAnchor").style.background="blue"; intScrolling=setInterval(scrollNavigationBarLeft,10);');
    slideNavigationRightControlAnchor.onmouseout=new Function("", 'document.getElementById("slideNavigationRightControlAnchor").style.background="white"; clearInterval(intScrolling);');

    //Hovering over the left navigation control makes the navigation bar scroll to the right.
    slideNavigationLeftControlAnchor.onmouseover=new Function("",'document.getElementById("slideNavigationLeftControlAnchor").style.background="blue"; intScrolling=setInterval(scrollNavigationBarRight,10);');
    slideNavigationLeftControlAnchor.onmouseout=new Function("", 'document.getElementById("slideNavigationLeftControlAnchor").style.background="white"; clearInterval(intScrolling);');


    //Next, we fill the slide footer. Start with a division to contain the slide counter.
    var slideCounter=document.createElement("div");
    slideCounter.id="slideCounter";
    slideFooter.appendChild(slideCounter);

    //Add a |div| containing the document's bibliographic information: document title, chapter title, authors, and date.
    var footerBibliographicInformation=document.createElement("div");
    footerBibliographicInformation.id="slideFooterBibliographicInformation";
    slideFooter.appendChild(footerBibliographicInformation);

    //Create a |span| containing the chapter's title and add it to the footer's bibliographic information.
    var footerChapterTitle=document.createElement("span");
    footerChapterTitle.id="slideFooterChapterTitle";
    footerBibliographicInformation.appendChild(footerChapterTitle);

    var chapterTitle=aChapter.getElementsByTagName("h2")[0];
    footerChapterTitle.className=chapterTitle.className;
    if(chapterTitle){
	var chapterTitleContent=chapterTitle.childNodes;
	var thisChildsClone;
	for(var i=0;i<chapterTitleContent.length;i++){
	    thisChildsClone=chapterTitleContent[i].cloneNode(true);
	    footerChapterTitle.appendChild(thisChildsClone);
	}
    }

    //Create a |span| containing the document's title and add it to the footer's bibliographic information.
    var footerTitle=document.createElement("span");
    footerTitle.id="slideFooterTitle";

    var documentTitle=document.getElementById("documentTitle");
    if(documentTitle){
	var documentTitleContent=documentTitle.childNodes;
	var thisChildsClone;

	for(var i=0;i<documentTitleContent.length;i++){

	    thisChildsClone=documentTitleContent[i].cloneNode(true);
	    footerTitle.appendChild(thisChildsClone);

	}
    } else {
    }

    footerBibliographicInformation.appendChild(footerTitle);

    //Add a span containing the document's authors.
    var footerAuthorList=document.createElement("span");
    footerAuthorList.id="slideFooterAuthorList";

    var authorList=document.getElementById("authorList");
    if(authorList){
	var authorListContent=authorList.childNodes;

	for(var j=0;j<authorListContent.length;j++){
	    thisChildsClone=authorListContent[j].cloneNode(true);
	    footerAuthorList.appendChild(thisChildsClone);
	}
    } else {
    }
    footerBibliographicInformation.appendChild(footerAuthorList);    

    //Add a div containing the document's union bugs.
    var footerUnionBugs=document.createElement("div");
    footerUnionBugs.id="slideFooterUnionBugs";

    var unionBugs=document.getElementById("unionBugs");
    if(unionBugs){
	var unionBugsContent=unionBugs.childNodes;

	for(var k=0;k<unionBugsContent.length;k++){
	    thisChildsClone=unionBugsContent[k].cloneNode(true);
	    footerUnionBugs.appendChild(thisChildsClone);
	}
    } else {
    }
    slideFooter.appendChild(footerUnionBugs);

    //Add a span containing the document's date.
    var slideFooterDate=document.createElement("span");
    slideFooterDate.id="slideFooterDate";

    var documentDate=document.getElementById("documentDate");
    if(documentDate){
	var documentDateContent=documentDate.childNodes;
    
	for(var l=0;l<documentDateContent.length;l++){
	    thisChildsClone=documentDateContent[l].cloneNode(true);
	    slideFooterDate.appendChild(thisChildsClone);
	}
    } else {
    }
    footerBibliographicInformation.appendChild(slideFooterDate);

    //Add a |div| containing the document's classification directive.
    var slideFooterClassification=document.createElement("div");
    slideFooterClassification.id="slideFooterClassification";

    var documentClassification=document.getElementById("classification");
    if(documentClassification){

	var documentClassificationContent=documentClassification.childNodes;

	for(var m=0;m<documentClassificationContent.length;m++){
	    thisChildsClone=documentClassificationContent[m].cloneNode(true);
	    slideFooterClassification.appendChild(thisChildsClone);
	}

    } else {
    }
    slideFooter.appendChild(slideFooterClassification);
    
}

function destroySlideFrame(aChapter){
    var slideFrame=document.getElementById("slideFrame");
    var body=document.getElementsByTagName("body")[0];
    body.removeChild(slideFrame);
}


function insertSlideIntoFrame(n){

    var slideFrame=document.getElementById("slideFrame");
    var slideFooter=document.getElementById("slideFooter");
    highlightSlideNavigationBarLink(arrayOfSlides[n]);
    currentSlideClone=arrayOfSlides[n].cloneNode(true);
    currentSlideClone.className="slide";
    removeInternalLinksOnSlide(currentSlideClone);
    slideFrame.insertBefore(currentSlideClone,slideFooter);
    slideCounter();

}


function removeSlideFromFrame(){

    var slideFrame=document.getElementById("slideFrame");
    slideFrame.removeChild(currentSlideClone);

}


/*
\function{|createSlideIdentifers()|}

Navigation between slides in the screen view requires each slide to be identified. This function does so by setting each slide's |id| property to |_comppSlide#|
*/
function createSlideIdentifiers() {
	for (var n = 0; n < numberOfSlides; n++) {
		var e = arrayOfSlides[n]; 
		var id = '_comppSlide' + n.toString();
		e.setAttribute('id',id);
	}
}


/* function{|redirectSlideNavigationBarLinks|}
*/

function redirectSlideNavigationBarLinks(aList){

    var arrayOfAnchors=aList.getElementsByTagName('a'); // Put all of the list's anchors into an array.


//Determine the browser's current target. We need this to classify links as internal and external.
    var thisPagesURL = window.location.href; //Current page browser is pointed to
    thisPagesURL = thisPagesURL.slice(0, thisPagesURL.length - window.location.hash.length); //Drop anything past a hash. What remains is the ``root'' URL.
    var bodyPages=document.getElementById("bodyPages");

    //All of the list's targets refer to sections within the current chapter. For each one, we determine that section's first slide. If the section has no slide, then we remove this element from the navigation bar.

    for (var i=0; i<arrayOfAnchors.length;i++) {
	var hrefContents=arrayOfAnchors[i].href;
	var targetURL = hrefContents.match('^'+thisPagesURL+'#[_a-zA-Z0-9]+');

	if(targetURL){

    	    //Get the target element's identifier from |hrefContents| and retrieve the target itself.
	    var hashLocation=hrefContents.search('#[_a-zA-Z0-9]+');
	    var targetId=hrefContents.slice(hashLocation+1,hrefContents.length);
	    var target=document.getElementById(targetId);
	    if((d=division(target)) && (targetSlide=nextSlideOrHighHeadingDecendingFromParent(target,d)) && !division(targetSlide)){
		var targetSlideNumber=targetSlide.id.match('[0-9]+');
		arrayOfAnchors[i].onclick = new Function("","if(isDisplayingSlideScreen){removeSlideFromFrame();currentSlideNumber="+targetSlideNumber+"; insertSlideIntoFrame("+targetSlideNumber+"); }");
	    } else {

		    var parentElement=arrayOfAnchors[i].parentNode;   //This should be a list item.
		    var grandParentElement=parentElement.parentNode;  //This should be an unordered list.
		    
		    grandParentElement.removeChild(parentElement);
		    //Removing this child reduces the size of |arrayOfAnchors| by one and slides the ``next'' anchor into the |i|'th position. 
		    //To ensure that we do not skip over that slide, decrement i.
		    i--;
	    }
	} 
	else {//This case should never happen. If it does. Pop up an alert.
	    alert("Internal kpp error.");
	}
    }
}


function removeInternalLinksOnSlide(aSlide){

   var arrayOfAnchors=aSlide.getElementsByTagName('a'); // Put all of the list's anchors into an array.


//Determine the browser's current target. We need this to classify links as internal and external.
    var thisPagesURL = window.location.href; //Current page browser is pointed to
    thisPagesURL = thisPagesURL.slice(0, thisPagesURL.length - window.location.hash.length); //Drop anything past a hash. What remains is the ``root'' URL.
    var bodyPages=document.getElementById("bodyPages");

    //All of the list's targets refer to sections within the current chapter. For each one, we determine that section's first slide. If the section has no slide, then we remove this element from the navigation bar.

    for (var i=0; i<arrayOfAnchors.length;i++) {
	var hrefContents=arrayOfAnchors[i].href;
	var targetURL = hrefContents.match('^'+thisPagesURL+'#[_a-zA-Z0-9]+');

	if(targetURL){
	    //Retrieve the anchor's contents, which should be in its single child node.
	    var anchorContents=arrayOfAnchors[i].childNodes[0];

	    //If the anchor in question has a |nextSibling|, place the contents immediately before it. Otherwise, append the contents to the end of the slide.
	    var nextSib;
	    if(nextSib=arrayOfAnchors[i].nextSibling){
		aSlide.insertBefore(anchorContents,nextSib);
	    } else {
		aSlide.appendChild(anchorContents);
	    }

	    //Remove the original anchor.
	    aSlide.removeChild(arrayOfAnchors[i]);
	    
	}
    }
}

function verticallyPositionCurrentElement(percentage){

    var windowHeight=window.innerHeight;
    window.scrollBy(0,-windowHeight*percentage/100);


}

//Function to find a named decendent.
function namedDecendent(object,name){

    //First, get the |object|'s children and search for the |name| among them. 

    var objectChildren=object.childNodes;
    var childIndex=-1;
    for (var i=0; i<objectChildren.length; i++){

	if(objectChildren[i].id && objectChildren[i].id.search('^'+name+'$')>=0){
	    childIndex=i;
	    break;
	}

    }

    //If this initial search was successful, then return the found child. Otherwise, apply this function to each of the children.
    if (childIndex>=0){

	return objectChildren[childIndex];

    } else {

	for (var i=0; i<objectChildren.length; i++){

	    var candidateChild=namedDecendent(objectChildren[i],name);
	    if(candidateChild){
		return candidateChild;
	    }

	}

	//If we have arrived here, then we have not found a candidate, return null.
	return null;

    }

}

</script>