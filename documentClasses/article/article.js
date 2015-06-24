<script type="text/javascript">
window.onload = startup;
document.onkeydown=processKeyInput;
window.onresize=processResizeWindow;

var intScrolling; //Interval Handler.
var currentSlideClone; //Will contain the clone of the |.slide| element currently being displayed.

/*
\subsection{Document Preparation}

The |startup()| function initializes the document preparation step. It can be broken into four sections, content selection, content creation, link redirection, and content styling. 
*/

function startup() {

    /*

\subsubsection{Content Selection}
A given Komments++ document can spread itself across several windows by spawning \emph{subdocuments}. The content selection task sets the display of one particular window based on the contents of the current page address as returned by |window.location|. In general, a location within a document can be selected by appending |\#{}\emph{id}| to the document's URL. If such a location is specified when calling a Komments++ article, we first check to see if it is the |\emph{id}| of a designated subdocument, either a |box| or |appendix|. If so, only the subdocument and its supporting material get displayed. If there is no such |\emph{id}| or if it refers to another object in the document, then the article's \emph{base} (everything but its designated subdocuments) is loaded. 

For this task, we retrieve the URL's |\emph{id}| suffix from |window.location.hash| and compare it to the names of boxes and appendices.
    */
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

    var chosenBox=-1;
    var chosenAppendix=-1;

//Search the document's boxes for the target object.
    var i=0;
    while(i<allBoxes.length){

	var thisTarget=namedDecendent(allBoxes[i],thisHash);
	if(thisTarget){
	    chosenBox=i;
	    break;
	}
	i++;

    }

    //If the target is not in a box, then look in the appendices. We distinguish the appendices from the ordinary body divisions by examining them for |h3| header tags in the |sectionAppendix| class. 

    allAppendices = new Array();
    for (var i=0; i<allDivs.length;i++){
	if(allDivs[i].className.search('^section$')>=0){
	    var h3Tags=allDivs[i].getElementsByTagName("h3");
	    for (var j=0; j<h3Tags.length;j++){
		if (h3Tags[j].className.search('^sectionAppendix$')>=0){
		    allAppendices[allAppendices.length]=allDivs[i];
		}
	    }
	}
    }

    if(chosenBox==-1){

	var i=0;
	while (i<allAppendices.length){

	    var thisTarget=namedDecendent(allAppendices[i],thisHash);
	    if(thisTarget){
		chosenAppendix=i;
		break;
	    }
	    i++;

	}
    }

    //Now, we have the information to determine which one of two cases holds good.
    //\begin{itemize}
    // \item The target object is in a subdocument.
    // \item The target object is either in the main document or does not exist.
    //\end{itemize}
    //In either case, we construct the document appropriately. 

    var body=document.getElementsByTagName("body")[0];
    var bodyPages=document.getElementById("bodyPages");

    if (chosenBox>=0 || chosenAppendix>=0){
	
//Begin by removing the |bodyPages| and |onlyCode| divisions.
	var onlyCode=document.getElementById("onlyCode");
	body.removeChild(bodyPages);
	body.removeChild(onlyCode);

	//Next, insert the chosen box or appendix and update the window's |title|.
	if (chosenBox>=0){
	    var thisBox=allBoxes[chosenBox];
	    body.appendChild(thisBox);
	    //Change the title tag to match the box window's caption.
	    var thisCaption=thisBox.getElementsByClassName("caption")[0].textContent;
	    var windowTitle=window.document.head.getElementsByTagName("title")[0];
	    windowTitle.textContent=thisCaption;
	} else {
	    var thisAppendix=allAppendices[chosenAppendix];
	    body.appendChild(thisAppendix);
	    var thisAppendixTitle=thisAppendix.getElementsByClassName("sectionName")[0].textContent;
	    var windowTitle=window.document.head.getElementsByTagName("title")[0];
	    windowTitle.textContent=thisAppendixTitle;
    
	}

    } else {

	//Remove all of the boxes and appendices.
	for (var i=0; i<allBoxes.length; i++){
	    var thisParent=allBoxes[i].parentNode;
	    thisParent.removeChild(allBoxes[i]);
	}

	for (var i=0; i<allAppendices.length;i++){
	    var thisParent=allAppendices[i].parentNode;
	    thisParent.removeChild(allAppendices[i]);
	}
	
    }


    /* 

\subsubsection{Content Creation}}

The content creation task enhances the screen view of prose mode with an immobile footer and (if the main document is being displayed) a table of contents. This task also handles the creation of the title slide, slide navigation bar, and slide footer for the document's slide mode. We begin with the article footer, which contains the document's title, authors, union bugs, date, and any classification directive. The |createArticleFooter| function handles this, and we append this to the document's |body| tag.
    */

    articleFooter=createArticleFooter();
    body.appendChild(articleFooter);

    /* If we are displaying the main document, then the table of contents is a nested list of \emph{all} the document's sections, subsections, subsubsections, including those in its appendices. If we are displaying an appendix, then the table of contents is limited to its contents. In either case, the |createTableOfContents| function makes it. For the main document, we place it after the |frontMatter| division within the |body| tag. For an appendix, we place it before the appendix's encompassing |div|. */
    if( chosenBox==-1 && chosenAppendix==-1){
	tableOfContents=createTableOfContents(bodyPages);
	
	//To create the table of contents entries for the appendices, we create a synthetic ``page'' to house them and feed that to |createTableOfContents|.
	var appendixPage=document.createElement("div");
	
	for (var i=0; i<allAppendices.length;i++){
	    appendixPage.appendChild(allAppendices[i]);
	}
	var appendixEntries=createTableOfContents(appendixPage);
	tableOfContents=concatinateTablesOfContents(tableOfContents,appendixEntries);
	tableOfContents.id="tableOfContents";
	var frontMatterSibling=document.getElementById("frontMatter").nextSibling;
	body.insertBefore(tableOfContents,frontMatterSibling);

	createTitleSlide();
    } else if (chosenAppendix>=0) {
	tableOfContents=createTableOfContents(body);
	tableOfContents.id="tableOfContents";

	//Insert the table of contents after the appendix's section header.
	var thisHeader=thisAppendix.getElementsByTagName("h3")[0];
	thisAppendix.insertBefore(tableOfContents,thisHeader.nextSibling);

	//Create the title slide
	createTitleSlide();
	// and append the Appendix's title to the title.
	titleSlideTitle=document.getElementById("titleSlideTitle");
	titleSlideTitle.textContent=titleSlideTitle.textContent+": "+thisAppendixTitle;
	
    } else { //Otherwise, we are displaying a box, which does not have a table of contents.

    }

    /* Create the array of slides and assign each one an identifier. */
    arrayOfSlides=getSlides();
    numberOfSlides=arrayOfSlides.length;
    createSlideIdentifiers();

    /* Initialize the global variables used by slide mode. */

    currentSlideNumber=0; //This records the slide currently being displayed. Its initial value refers to the title slide.

    leftNavigationScrollControlVisible=false; //Indicators of whether or not the navigation controls are visible.
    rightNavigationScrollControlVisible=false;

    scrollSpeed=3; //Index of scrolling speed applied to navigation bar.
    navigationBarLeftOffset=0; //Index of navigation menu's position relative to its initial position.

    /* 
       The screen view of slide mode displays only a slide frame with navigation tools in the header and bibliographic and progress information in its footer. The document management code places a clone of the slide currently being viewed within it. */

    if(chosenBox>=0){
	createSlideFrame(thisBox,0);//These arguments should leave the slide frame's header empty.
    } else if (chosenAppendix>=0){
	createSlideFrame(thisAppendix,1); //This should fill the slide's header with the appendix's subsections.
    } else {
	createSlideFrame(body,0); //This should fill the slide's header with the main document's sections.
    }

    /* The rearrangement of the document can make a link to another document location fail for one of two reasons. First, the link might point to a document location not currently being displayed. Second, the link might point to a location within the current document, but the document is in slide view and the link does not appear on any given slide. The function |redirectInternalLinks| examines all of the links in the document as it is currently displayed and adds custom functions to their |onclick| properties to handle these problems. We solve the first problem simply by opening a new window containing the document. (In a future version, we might redirect the reader back to the source window for links pointing to the main document.) For the second problem, we open a new window \emph{if the link is not sectional}. If it does point to a section, subsection, or subsubsection, then we point to the first slide from that section in the slide show. */

    redirectInternalLinks();

 
/*

The final task for the |startup| function is the styling of the document. To the greatest extent possible, we rely on CSS style sheets for this, which are in the document's header. The |common| sheet handles low-level style choices that do not vary (much) across the document's three modes and two views. The six other style sheets each implement one mode-view combination, and they are designed to be applied to the document \emph{one at a time}. To implement this, we assign each of these style sheets to a global variable and to remove all but one of them from the document itself. (Of course, the removed sheets are held in reserve ready to be applied when the mode-view combination changes.) We use |getStylesFromXHTML()| for the global variable assignment. Each of the mode-view specific style sheets has a corresponding function to remove the style from the document and another to apply the style. We use these to remove all of the variable style sheets but that for the screen view of article mode.
*/
    getStylesFromXHTML();
    removeProsePrintStyle();
    removeSlideScreenStyle();
    removeSlidePrintStyle();
    removeCodeScreenStyle();
    removeCodePrintStyle();
/*

The document management routines use several global variables to record the active mode and view. We intialize them with the prose mode and screen view.

 */
    isDisplayingProseScreen=true;
    isDisplayingProsePrint = false; 
    isDisplayingSlideScreen = false;
    isDisplayingSlidePrint=false;
    isDisplayingCodeScreen=false;
    isDisplayingCodePrint=false; 

 
/*
  The remainder of the styling for prose mode's screen view relies on Javascript. First, we slightly beautify the front matter if we are displaying the main document. If we are displaying a subdocument, we hide it instead. 
*/
    if(chosenBox==-1 && chosenAppendix==-1){
	beautifyFrontMatter();
    } else {
	var frontMatter=document.getElementById("frontMatter");
	frontMatter.style.display="none";
	if (chosenBox>=0){
	    thisBox.style.marginBottom="10em";
	} else {
	    thisAppendix.style.marginBottom="10em";
	}
    }

    /* If we are displaying an appendix, we replace its section numbers with the appropriate Latin letter. */
   if (chosenAppendix>=0){
       for(level=3;level<6;level++){
	   theseHeaders=thisAppendix.getElementsByTagName("h"+level.toString());
	   for(i=0; i<theseHeaders.length;i++){
	       var thisSectionNumber=theseHeaders[i].getElementsByClassName("sectionNumber")[0];
	       thisSectionNumber.textContent=String.fromCharCode(64+parseInt(thisSectionNumber.textContent));
	   }
       }
   }	       

    //Restyle section numbers within references to the appendices or objects they contain.
    var allAnchors=document.getElementsByTagName('a');

    for(var i=0; i<allAppendices.length;i++){
	for(var j=0;j<allAnchors.length;j++){
	    var thisHref=allAnchors[j].href;
	    l=thisHref.search('#');
	    if(l>=0){
		thisHash=thisHref.slice(l+1,thisHref.length);
		thisHash=thisHash.replace(/%20/g," ");
		var thisTarget=namedDecendent(allAppendices[i],thisHash);
		if(thisTarget){
		    thisAnchorsSectionNumber=allAnchors[j].getElementsByClassName("sectionNumber")[0];
		    if(thisAnchorsSectionNumber){
			thisAnchorsSectionNumber.textContent=String.fromCharCode(64+parseInt(thisAnchorsSectionNumber.textContent));
		    }
		}

	    }
	}
    }
 
/*
Next, we add the visual controls and functions for expanding and contracting trees' branches.
*/
    prepareTrees();

    /*
Add the same controls for hiding and showing hidden/folded code.
     */    
    prepareHiddenCode();
}

/*
\subsubsection{Style Sheet Management}

\function{|getStylesFromXHTML()|\label{getStylesFromXHTML}}

The |startup()| function's first call is to the style-sheet management function |getStylesFromXHTML()|, which assigns each of the document's style sheets to a variable. Keeping track of these style sheets presents a challenge, because the |style| tag does not support the |id| attribute. Therefore, it is difficult to mark each style sheet with its intended use.\footnote{Perhaps the |media| attribute could be used here, but its predefined allowable values do not precisely fit our uses and could lead to confusion.} Our solution to this problem uses XHTML comments to identify the style sheets. Consider for example the first two lines of |articleBrowse.css|:
\input[1..2]{proseScreen.css}

\begin{figure}
\centeredimage{commentNodesInHeader.png}
\caption{Comment Nodes in this Document's XHTML |head| Tag\label{commentNodesInHeader}}
\end{figure}
When the browser loads the page, its DOM parser assigns the comment to a node. Figure \ref{commentNodesInHeader} illustrates this. The seventh node of this document's header is the comment at the top of |articleBrowse.css|. Its |nodeType| attribute equals |8|, which identifies it as a comment node. By construction, the next element node (identified by its |nodeType| attribute equalling |1|) is the style sheet for the article mode's screen view. We use this fact to assign the style sheet to the global variable |browseStyle|. The function handles the other style sheets similarly.

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

		case "proseScreen":
		    proseScreenStyle=thisStyle;
		    break;

		case "prosePrint":
		    prosePrintStyle=thisStyle;
		    break;

		case "slideScreen":
		    slideScreenStyle=thisStyle;
		    break;

		case "slidePrint":
		    slidePrintStyle=thisStyle;
		    break;

		case "codeScreen":
		    codeScreenStyle=thisStyle;
		    break;

		case "codePrint":
		    codePrintStyle=thisStyle;
		    break;

		}
	    }

	}
	
    }
}
/* 
   Note that |getStyleSheetsFromXHTML()| has the (desired) side effect of defining |documentHeader| as a global variable. 

   The remaining style sheet management functions simply add and remove the mode-view specific style sheets. The order of style sheets matters, because rules appearing later  take precidence over earlier conflicting rules. By using the |appendChild| method, we guarantee that the mode-view specific style sheets always come after the common style sheet.\footnote{However, the division of labor between the common and mode-view specific style sheets makes this ordering relatively unimportant.} */

//\function{|removeProseScreenStyle()|}
function removeProseScreenStyle() {
    documentHeader.removeChild(proseScreenStyle);
}
//\function{|removeProsePrintStyle()|}
function removeProsePrintStyle() {
   documentHeader.removeChild(prosePrintStyle);												
}
//\function{|removeSlideScreenStyle()|}
function removeSlideScreenStyle() {
    documentHeader.removeChild(slideScreenStyle);
}
//\function{|removeSlidePrintStyle()|}
function removeSlidePrintStyle(){
    documentHeader.removeChild(slidePrintStyle);
}
//\function{|removeCodeScreenStyle()|}
function removeCodeScreenStyle() {
    documentHeader.removeChild(codeScreenStyle);
}
//\function{|removeCodePrintStyle()|}
function removeCodePrintStyle(){
    documentHeader.removeChild(codePrintStyle);
}
//\function{|addProseScreenStyle()|}
function addProseScreenStyle() {
    documentHeader.appendChild(proseScreenStyle);
}
//\function{|addProsePrintStyle()|}
function addProsePrintStyle() {
    documentHeader.appendChild(prosePrintStyle);
}
//\function{|addSlideScreenStyle()|}
function addSlideScreenStyle() {
    documentHeader.appendChild(slideScreenStyle);
}
//\function{|addSlidePrintStyle()|}
function addSlidePrintStyle() {
    documentHeader.appendChild(slidePrintStyle);
}
//\function{|addCodeScreenStyle()|}
function addCodeScreenStyle(){
    documentHeader.appendChild(codeScreenStyle);
}
//\function{|addCodePrintStyle()|}
function addCodePrintStyle(){
    documentHeader.appendChild(codePrintStyle);
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

function createTableOfContents(content){

    var hasSections=true;

    if(hasSections){

	//Create a division to contain the table of contents.
	var tableOfContents=document.createElement("div");
    
	//Create a paragraph to label the table of contents,
	//populate it, style it, and insert it into the document.
	var newParagraph=document.createElement("p");
	var newText=document.createTextNode("Contents");
	newParagraph.appendChild(newText);
	newParagraph.style.textAlign="center";
	tableOfContents.appendChild(newParagraph);

	//Finally, create and insert the actual table of contents list.
	var tableOfContentsList=createBranchList(content,0);
	tableOfContents.appendChild(tableOfContentsList);

	return tableOfContents;
    
    }
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
    case 0: levelName="section";       levelHeaderTag="h3"; break;
    case 1: levelName="subsection";    levelHeaderTag="h4"; break;
    case 2: levelName="subsubsection"; levelHeaderTag="h5"; break;
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


function concatinateTablesOfContents(topTable,bottomTable) {

    //Retrieve the bottom table's top-level |ul| tag.
    var bottomTableChildren =bottomTable.childNodes;
    var bottomTableList;
    for (var i=0; i<bottomTableChildren.length;i++){
	
	if(bottomTableChildren[i].tagName.search('^UL$')>=0){
	    bottomTableList=bottomTableChildren[i];
	    break;
	}

    }

    //Retrieve the immediate-decendents of the |bottomTableList|.
    bottomTableListChildren = bottomTableList.childNodes;
    
    //Clone the top table and retrieve the clone's top-level |ul| tag.
    var newTable=topTable.cloneNode(true);
    var newTableChildren=newTable.childNodes;
    var newTableList;
    for (var i=0; i<newTableChildren.length; i++){
	if(newTableChildren[i].tagName.search('^UL$')>=0){
	    newTableList=newTableChildren[i];
	    break;
	}
    }

    //Cycle through the botomTableListChildren, cloning them and appending the clones to |newTableList|.
    for(var i=0;i<bottomTableListChildren.length;i++){

	var newChild=bottomTableListChildren[i].cloneNode(true);
	newTableList.appendChild(newChild);

    }

    //Return the result of the concatination in |newTable|.
    return newTable;

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

    return articleFooter;


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
Trees
 */

function prepareTrees(){

    //Collect the trees into an array.
    var allUnorderedLists=document.getElementsByTagName("ul");
    var allTrees = new Array();
    for (var i=0; i< allUnorderedLists.length;i++) {
	if (allUnorderedLists[i].className.search('^tree$')>=0){
	    allTrees[allTrees.length]=allUnorderedLists[i];
	}
    }

    //Go through the trees, inspecting each of their direct decendants. If any of them contain a list item, we append [more] to its contents.
    for (var i=0; i< allTrees.length; i++) {
	var thisTreesChildren=allTrees[i].childNodes;
	if(thisTreesChildren){
	    for (var j=0; j<thisTreesChildren.length;j++) {
		var thisChild=thisTreesChildren[j];
		var appendMore=false;
		if (thisChild.nodeType==1){
		    if (thisChild.tagName.search('^LI$')>=0){
			var theseGrandChildren=thisChild.childNodes;
			for(var k=0;k<theseGrandChildren.length;k++){
			    var thisGrandChild=theseGrandChildren[k];
			    if(thisGrandChild.nodeType==1){
				if(thisGrandChild.tagName.search('^UL$')>=0){
				    appendMore=true;
				}
			    }
			}
			if(appendMore){
			    firstGrandchild=theseGrandChildren[0];
			    if(firstGrandchild.tagName.search('^SPAN$')>=0 && firstGrandchild.className.search('^listitemcontent$')>=0){

				var moreAnchor=document.createElement("span");
				moreAnchor.className="showTree";
				var moreImage=document.createElement("img");
				moreImage.src="data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9Im5vIj8+CjwhLS0gQ3JlYXRlZCB3aXRoIElua3NjYXBlIChodHRwOi8vd3d3Lmlua3NjYXBlLm9yZy8pIC0tPgoKPHN2ZwogICB4bWxuczpkYz0iaHR0cDovL3B1cmwub3JnL2RjL2VsZW1lbnRzLzEuMS8iCiAgIHhtbG5zOmNjPSJodHRwOi8vY3JlYXRpdmVjb21tb25zLm9yZy9ucyMiCiAgIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyIKICAgeG1sbnM6c3ZnPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIKICAgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIgogICB4bWxuczpzb2RpcG9kaT0iaHR0cDovL3NvZGlwb2RpLnNvdXJjZWZvcmdlLm5ldC9EVEQvc29kaXBvZGktMC5kdGQiCiAgIHhtbG5zOmlua3NjYXBlPSJodHRwOi8vd3d3Lmlua3NjYXBlLm9yZy9uYW1lc3BhY2VzL2lua3NjYXBlIgogICB3aWR0aD0iMjQiCiAgIGhlaWdodD0iMjQiCiAgIGlkPSJzdmc1MDg3IgogICB2ZXJzaW9uPSIxLjEiCiAgIGlua3NjYXBlOnZlcnNpb249IjAuNDguNCByOTkzOSIKICAgc29kaXBvZGk6ZG9jbmFtZT0ic2hvdy5zdmciPgogIDxkZWZzCiAgICAgaWQ9ImRlZnM1MDg5IiAvPgogIDxzb2RpcG9kaTpuYW1lZHZpZXcKICAgICBpZD0iYmFzZSIKICAgICBwYWdlY29sb3I9IiNmZmZmZmYiCiAgICAgYm9yZGVyY29sb3I9IiM2NjY2NjYiCiAgICAgYm9yZGVyb3BhY2l0eT0iMS4wIgogICAgIGlua3NjYXBlOnBhZ2VvcGFjaXR5PSIwLjAiCiAgICAgaW5rc2NhcGU6cGFnZXNoYWRvdz0iMiIKICAgICBpbmtzY2FwZTp6b29tPSIyOS4yOTE2NjciCiAgICAgaW5rc2NhcGU6Y3g9IjYuNzc2NjcxMyIKICAgICBpbmtzY2FwZTpjeT0iMTIuMDc1NzgyIgogICAgIGlua3NjYXBlOmRvY3VtZW50LXVuaXRzPSJweCIKICAgICBpbmtzY2FwZTpjdXJyZW50LWxheWVyPSJsYXllcjEiCiAgICAgc2hvd2dyaWQ9InRydWUiCiAgICAgaW5rc2NhcGU6d2luZG93LXdpZHRoPSIxNjgwIgogICAgIGlua3NjYXBlOndpbmRvdy1oZWlnaHQ9IjkxOCIKICAgICBpbmtzY2FwZTp3aW5kb3cteD0iMCIKICAgICBpbmtzY2FwZTp3aW5kb3cteT0iMCIKICAgICBpbmtzY2FwZTp3aW5kb3ctbWF4aW1pemVkPSIxIj4KICAgIDxpbmtzY2FwZTpncmlkCiAgICAgICB0eXBlPSJ4eWdyaWQiCiAgICAgICBpZD0iZ3JpZDUwOTUiCiAgICAgICBlbXBzcGFjaW5nPSI1IgogICAgICAgdmlzaWJsZT0idHJ1ZSIKICAgICAgIGVuYWJsZWQ9InRydWUiCiAgICAgICBzbmFwdmlzaWJsZWdyaWRsaW5lc29ubHk9InRydWUiIC8+CiAgPC9zb2RpcG9kaTpuYW1lZHZpZXc+CiAgPG1ldGFkYXRhCiAgICAgaWQ9Im1ldGFkYXRhNTA5MiI+CiAgICA8cmRmOlJERj4KICAgICAgPGNjOldvcmsKICAgICAgICAgcmRmOmFib3V0PSIiPgogICAgICAgIDxkYzpmb3JtYXQ+aW1hZ2Uvc3ZnK3htbDwvZGM6Zm9ybWF0PgogICAgICAgIDxkYzp0eXBlCiAgICAgICAgICAgcmRmOnJlc291cmNlPSJodHRwOi8vcHVybC5vcmcvZGMvZGNtaXR5cGUvU3RpbGxJbWFnZSIgLz4KICAgICAgICA8ZGM6dGl0bGU+PC9kYzp0aXRsZT4KICAgICAgPC9jYzpXb3JrPgogICAgPC9yZGY6UkRGPgogIDwvbWV0YWRhdGE+CiAgPGcKICAgICBpbmtzY2FwZTpsYWJlbD0iTGF5ZXIgMSIKICAgICBpbmtzY2FwZTpncm91cG1vZGU9ImxheWVyIgogICAgIGlkPSJsYXllcjEiCiAgICAgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCwtMTAyOC4zNjIyKSI+CiAgICA8cmVjdAogICAgICAgcnk9IjAuNzUiCiAgICAgICByeD0iMC4wMjU2MDQ1NTIiCiAgICAgICB0cmFuc2Zvcm09Im1hdHJpeCgwLDEsLTEsMCwwLDApIgogICAgICAgeT0iLTIwLjk2MTU5NCIKICAgICAgIHg9IjEwMzguNDg3MiIKICAgICAgIGhlaWdodD0iMTgiCiAgICAgICB3aWR0aD0iMy43NSIKICAgICAgIGlkPSJyZWN0NTYwNyIKICAgICAgIHN0eWxlPSJjb2xvcjojMDAwMDAwO2ZpbGw6Izg2YWE4NztmaWxsLW9wYWNpdHk6MTtmaWxsLXJ1bGU6bm9uemVybztzdHJva2U6bm9uZTtzdHJva2Utd2lkdGg6MC4yNTAwMDAwMDAwMDAwMDAwMDttYXJrZXI6bm9uZTt2aXNpYmlsaXR5OnZpc2libGU7ZGlzcGxheTppbmxpbmU7b3ZlcmZsb3c6dmlzaWJsZTtlbmFibGUtYmFja2dyb3VuZDphY2N1bXVsYXRlIiAvPgogICAgPHBhdGgKICAgICAgIHN0eWxlPSJmaWxsOm5vbmU7c3Ryb2tlOiM4NmFhODc7c3Ryb2tlLXdpZHRoOjFweDtzdHJva2UtbGluZWNhcDpidXR0O3N0cm9rZS1saW5lam9pbjptaXRlcjtzdHJva2Utb3BhY2l0eToxIgogICAgICAgZD0ibSA1LDEwMzEuODYyMiAtNCwwIDAsMTcgNCwwIgogICAgICAgaWQ9InBhdGg2MjM3IgogICAgICAgaW5rc2NhcGU6Y29ubmVjdG9yLWN1cnZhdHVyZT0iMCIgLz4KICAgIDxwYXRoCiAgICAgICBpbmtzY2FwZTpjb25uZWN0b3ItY3VydmF0dXJlPSIwIgogICAgICAgaWQ9InBhdGg2MjM5IgogICAgICAgZD0ibSAxOC45MjMxODYsMTAzMS44NjIyIDQsMCAwLDE3IC00LDAiCiAgICAgICBzdHlsZT0iZmlsbDpub25lO3N0cm9rZTojODZhYTg3O3N0cm9rZS13aWR0aDoxcHg7c3Ryb2tlLWxpbmVjYXA6YnV0dDtzdHJva2UtbGluZWpvaW46bWl0ZXI7c3Ryb2tlLW9wYWNpdHk6MSIgLz4KICAgIDxyZWN0CiAgICAgICBzdHlsZT0iY29sb3I6IzAwMDAwMDtmaWxsOiM4NmFhODc7ZmlsbC1vcGFjaXR5OjE7ZmlsbC1ydWxlOm5vbnplcm87c3Ryb2tlOm5vbmU7c3Ryb2tlLXdpZHRoOjAuMjUwMDAwMDAwMDAwMDAwMDA7bWFya2VyOm5vbmU7dmlzaWJpbGl0eTp2aXNpYmxlO2Rpc3BsYXk6aW5saW5lO292ZXJmbG93OnZpc2libGU7ZW5hYmxlLWJhY2tncm91bmQ6YWNjdW11bGF0ZSIKICAgICAgIGlkPSJyZWN0NjI2MCIKICAgICAgIHdpZHRoPSIzLjc1IgogICAgICAgaGVpZ2h0PSIxOCIKICAgICAgIHg9Ii0xMy44MzY1OTQiCiAgICAgICB5PSItMTA0OS4zNjIyIgogICAgICAgdHJhbnNmb3JtPSJzY2FsZSgtMSwtMSkiCiAgICAgICByeD0iMC4wMjU2MDQ1NTIiCiAgICAgICByeT0iMC43NSIgLz4KICA8L2c+Cjwvc3ZnPgo=";
				moreAnchor.appendChild(moreImage);
				moreAnchor.style.cursor="pointer";
				moreAnchor.style.marginLeft="1em";
				moreAnchor.onclick = showTree;

				var lessAnchor=document.createElement("span");
				lessAnchor.className="hideTree";
				var lessImage=document.createElement("img");
				lessImage.src="data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9Im5vIj8+CjwhLS0gQ3JlYXRlZCB3aXRoIElua3NjYXBlIChodHRwOi8vd3d3Lmlua3NjYXBlLm9yZy8pIC0tPgoKPHN2ZwogICB4bWxuczpkYz0iaHR0cDovL3B1cmwub3JnL2RjL2VsZW1lbnRzLzEuMS8iCiAgIHhtbG5zOmNjPSJodHRwOi8vY3JlYXRpdmVjb21tb25zLm9yZy9ucyMiCiAgIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyIKICAgeG1sbnM6c3ZnPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIKICAgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIgogICB4bWxuczpzb2RpcG9kaT0iaHR0cDovL3NvZGlwb2RpLnNvdXJjZWZvcmdlLm5ldC9EVEQvc29kaXBvZGktMC5kdGQiCiAgIHhtbG5zOmlua3NjYXBlPSJodHRwOi8vd3d3Lmlua3NjYXBlLm9yZy9uYW1lc3BhY2VzL2lua3NjYXBlIgogICB3aWR0aD0iMjQiCiAgIGhlaWdodD0iMjQiCiAgIGlkPSJzdmc1MDg3IgogICB2ZXJzaW9uPSIxLjEiCiAgIGlua3NjYXBlOnZlcnNpb249IjAuNDguNCByOTkzOSIKICAgc29kaXBvZGk6ZG9jbmFtZT0iaGlkZS5zdmciPgogIDxkZWZzCiAgICAgaWQ9ImRlZnM1MDg5IiAvPgogIDxzb2RpcG9kaTpuYW1lZHZpZXcKICAgICBpZD0iYmFzZSIKICAgICBwYWdlY29sb3I9IiNmZmZmZmYiCiAgICAgYm9yZGVyY29sb3I9IiM2NjY2NjYiCiAgICAgYm9yZGVyb3BhY2l0eT0iMS4wIgogICAgIGlua3NjYXBlOnBhZ2VvcGFjaXR5PSIwLjAiCiAgICAgaW5rc2NhcGU6cGFnZXNoYWRvdz0iMiIKICAgICBpbmtzY2FwZTp6b29tPSIyOS4yOTE2NjciCiAgICAgaW5rc2NhcGU6Y3g9IjYuNzc2NjcxMyIKICAgICBpbmtzY2FwZTpjeT0iMTIuMDc1NzgyIgogICAgIGlua3NjYXBlOmRvY3VtZW50LXVuaXRzPSJweCIKICAgICBpbmtzY2FwZTpjdXJyZW50LWxheWVyPSJsYXllcjEiCiAgICAgc2hvd2dyaWQ9InRydWUiCiAgICAgaW5rc2NhcGU6d2luZG93LXdpZHRoPSIxNjgwIgogICAgIGlua3NjYXBlOndpbmRvdy1oZWlnaHQ9IjkxOCIKICAgICBpbmtzY2FwZTp3aW5kb3cteD0iMCIKICAgICBpbmtzY2FwZTp3aW5kb3cteT0iMCIKICAgICBpbmtzY2FwZTp3aW5kb3ctbWF4aW1pemVkPSIxIj4KICAgIDxpbmtzY2FwZTpncmlkCiAgICAgICB0eXBlPSJ4eWdyaWQiCiAgICAgICBpZD0iZ3JpZDUwOTUiCiAgICAgICBlbXBzcGFjaW5nPSI1IgogICAgICAgdmlzaWJsZT0idHJ1ZSIKICAgICAgIGVuYWJsZWQ9InRydWUiCiAgICAgICBzbmFwdmlzaWJsZWdyaWRsaW5lc29ubHk9InRydWUiIC8+CiAgPC9zb2RpcG9kaTpuYW1lZHZpZXc+CiAgPG1ldGFkYXRhCiAgICAgaWQ9Im1ldGFkYXRhNTA5MiI+CiAgICA8cmRmOlJERj4KICAgICAgPGNjOldvcmsKICAgICAgICAgcmRmOmFib3V0PSIiPgogICAgICAgIDxkYzpmb3JtYXQ+aW1hZ2Uvc3ZnK3htbDwvZGM6Zm9ybWF0PgogICAgICAgIDxkYzp0eXBlCiAgICAgICAgICAgcmRmOnJlc291cmNlPSJodHRwOi8vcHVybC5vcmcvZGMvZGNtaXR5cGUvU3RpbGxJbWFnZSIgLz4KICAgICAgICA8ZGM6dGl0bGUgLz4KICAgICAgPC9jYzpXb3JrPgogICAgPC9yZGY6UkRGPgogIDwvbWV0YWRhdGE+CiAgPGcKICAgICBpbmtzY2FwZTpsYWJlbD0iTGF5ZXIgMSIKICAgICBpbmtzY2FwZTpncm91cG1vZGU9ImxheWVyIgogICAgIGlkPSJsYXllcjEiCiAgICAgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCwtMTAyOC4zNjIyKSI+CiAgICA8cmVjdAogICAgICAgcnk9IjAuNzUiCiAgICAgICByeD0iMC4wMjU2MDQ1NTIiCiAgICAgICB0cmFuc2Zvcm09Im1hdHJpeCgwLDEsLTEsMCwwLDApIgogICAgICAgeT0iLTIwLjk2MTU5NCIKICAgICAgIHg9IjEwMzguNDg3MiIKICAgICAgIGhlaWdodD0iMTgiCiAgICAgICB3aWR0aD0iMy43NSIKICAgICAgIGlkPSJyZWN0NTYwNyIKICAgICAgIHN0eWxlPSJjb2xvcjojMDAwMDAwO2ZpbGw6I2Q1NjA2MztmaWxsLW9wYWNpdHk6MTtmaWxsLXJ1bGU6bm9uemVybztzdHJva2U6bm9uZTtzdHJva2Utd2lkdGg6MC4yNTttYXJrZXI6bm9uZTt2aXNpYmlsaXR5OnZpc2libGU7ZGlzcGxheTppbmxpbmU7b3ZlcmZsb3c6dmlzaWJsZTtlbmFibGUtYmFja2dyb3VuZDphY2N1bXVsYXRlIiAvPgogICAgPHBhdGgKICAgICAgIHN0eWxlPSJmaWxsOm5vbmU7c3Ryb2tlOiNkNTYwNjM7c3Ryb2tlLXdpZHRoOjFweDtzdHJva2UtbGluZWNhcDpidXR0O3N0cm9rZS1saW5lam9pbjptaXRlcjtzdHJva2Utb3BhY2l0eToxIgogICAgICAgZD0ibSA1LDEwMzEuODYyMiAtNCwwIDAsMTcgNCwwIgogICAgICAgaWQ9InBhdGg2MjM3IgogICAgICAgaW5rc2NhcGU6Y29ubmVjdG9yLWN1cnZhdHVyZT0iMCIgLz4KICAgIDxwYXRoCiAgICAgICBpbmtzY2FwZTpjb25uZWN0b3ItY3VydmF0dXJlPSIwIgogICAgICAgaWQ9InBhdGg2MjM5IgogICAgICAgZD0ibSAxOC45MjMxODYsMTAzMS44NjIyIDQsMCAwLDE3IC00LDAiCiAgICAgICBzdHlsZT0iZmlsbDpub25lO3N0cm9rZTojZDU2MDYzO3N0cm9rZS13aWR0aDoxcHg7c3Ryb2tlLWxpbmVjYXA6YnV0dDtzdHJva2UtbGluZWpvaW46bWl0ZXI7c3Ryb2tlLW9wYWNpdHk6MSIgLz4KICA8L2c+Cjwvc3ZnPgo=";
				lessAnchor.appendChild(lessImage);
				lessAnchor.style.cursor="pointer";
				lessAnchor.style.marginLeft="1em";
				lessAnchor.onclick = hideTree;

				firstGrandchild.appendChild(moreAnchor);
				firstGrandchild.appendChild(lessAnchor);

				//Hide this list-item's decendant lists.
				lessAnchor.click();

			    }
			}
		    }
		}
	    }
	}
    }
}

//The following function gets called when the user clicks a minus sign.
function hideTree(){

    //First, establish familial relations.
    var parent=this.parentNode;
    var grandParent=parent.parentNode;
    var siblings=parent.childNodes;
    var piblings=grandParent.childNodes;

    //Second, hide the span that was pressed.
    this.style.display='none';

    //Find its sibling showTree anchor. display it.
    for(var i=0;i<siblings.length;i++){

	if (siblings[i].className && siblings[i].className.search('^showTree$')>=0){
	    siblings[i].style.display='inline';
	}
    }
    
    //Find any lists among its piblings and hide them.
    for (var i=0;i<piblings.length;i++){

	if (piblings[i].tagName && piblings[i].tagName.search('^(UL|OL|DL)$')>=0){
	    piblings[i].style.display='none';
	}

    }

}

function showTree(){

    //First, establish familial relations.
    var parent=this.parentNode;
    var grandParent=parent.parentNode;
    var siblings=parent.childNodes;
    var piblings=grandParent.childNodes;

    //Second, hide the span that was pressed.
    this.style.display='none';

    //Find its sibling hideTree anchor. display it.
    for(var i=0;i<siblings.length;i++){

	if (siblings[i].className && siblings[i].className.search('^hideTree$')>=0){
	    siblings[i].style.display='inline';
	}
    }
    
    //Find any lists among its piblings and display them.
    for (var i=0;i<piblings.length;i++){

	if (piblings[i].tagName && piblings[i].tagName.search('^(UL|OL|DL)$')>=0){
	    piblings[i].style.display='';
	}

    }

}

function prepareBoxes(){

    //Collect all of the document's boxes.
    var allDivs=document.getElementsByTagName("div");
    allBoxes = new Array();
    for (var i=0; i< allDivs.length; i++) {
	if (allDivs[i].className.search('^box$')>=0){
	    allBoxes[allBoxes.length]=allDivs[i];
	}
    }

    // Remove boxes from the document. 
    for (var i=0; i<allBoxes.length; i++){
	var thisParent=allBoxes[i].parentNode;
	thisParent.removeChild(allBoxes[i]);
    }

}

function createBoxWindow(){

    /* Create the window. */
    boxWindow=window.open("","boxWindow");
    
    /* Clone the main document's header and place the clone into the box window. Child-by-child placement seems to work best in Safari.*/
    boxWindowHeader=document.getElementsByTagName("head")[0].cloneNode(true);
    oldBoxWindowHeader=boxWindow.document.getElementsByTagName("head")[0];
    boxWindowBody = boxWindow.document.getElementsByTagName("body")[0];
    boxWindowRoot = boxWindow.document.getElementsByTagName("html")[0];

    boxWindowRoot.removeChild(oldBoxWindowHeader);
    boxWindowRoot.insertBefore(boxWindowHeader,boxWindowBody);

    /* Append a clone of the main document's footer to the box window's body. (This gets formatted correctly by Firefox but \emph{not} by Safari.)*/
    boxWindowFooter=document.getElementById("articleFooter").cloneNode(true);
    var footerImages=boxWindowFooter.getElementsByTagName("img");

    //Append a time ``request'' to each image source to force a reload. Without this, the browser mistakenly thinks that this window has a fresh copy of the image displayed.
    for (var i=0;i<footerImages.length;i++){
	footerImages[i].src += "?time="+new Date().getTime();
    }
    boxWindowBody.appendChild(boxWindowFooter);

}

/* The |displayBox| function takes as its input |window.location.hash|. It first checks to see if hash references a box. If so, it rearranges the current document to display the hash. */

function displayBox(hash){

    //The first character of |hash| is, appropriately enough, the hash symbol. We remove it here.
    hash=hash.slice(1);
    //URLs replace spaces with |%20|. Undo this replacement.
    hash=hash.replace(/%20/g," ");

    //Search the document's boxes for a match with the given hash.
    var chosenBox=-1;
    var i=0;
    while(i<allBoxes.length){

	var thisCaption=allBoxes[i].getElementsByClassName("caption")[0];
	var thisName=thisCaption.id;
	if(thisName.search('^'+hash+'$')>=0){
	    chosenBox=i;
	    break;
	}
	i++;

    }

    // If there is a match, rearrange the current document.
    if(chosenBox>=0){
	var thisBox=allBoxes[chosenBox];

	//Change the title tag to match the box window's caption.
	thisCaption=thisBox.getElementsByClassName("caption")[0].textContent;
	windowTitle=window.document.head.getElementsByTagName("title")[0];
	windowTitle.textContent=thisCaption;

	//Remove the unwanted children from the document.
	var thisFrontMatter=document.getElementById("frontMatter");
	document.body.removeChild(thisFrontMatter);
	var thisTableOfContents=document.getElementById("tableOfContents");
	document.body.removeChild(thisTableOfContents);
	var theseBodyPages=document.getElementById("bodyPages");
	document.body.removeChild(theseBodyPages);
	
	//Insert the requested box.
	document.body.appendChild(thisBox);

    }
}

/*
\subsubsection{Additions for Slide Mode}
For the article's slide mode we construct
\begin{itemize}
\item the title slide,
\item an array of slides,
\item the slide frame, and
\item a printable footer for each slide.
\end{itemize}

With these items in place, we then proceed to redirect all internal links so that they have the desired effect of moving the target slide into the slide frame.

\function{|createTitleSlide()|}
 
The title slide is a simple copy of information from |frontMatter| into |p|s with the |id| prefix |titleSlide|.
*/

function createTitleSlide(){

    //Find the document root.
    var root=document.documentElement;

    //The title slide division is itself encompassed in a child division of the |body| tag with the id |titleSlide|.
    var titleSlideDivision=document.createElement("div");
    titleSlideDivision.id="titleSlide";

    //Place the title slide division at the start of the |body| tag.
    var documentBody=document.getElementsByTagName("body")[0];
    var documentBodyChildren=documentBody.childNodes;
    documentBody.insertBefore(titleSlideDivision,documentBodyChildren[0]);

    var titleSlide=document.createElement("div");
    titleSlide.className="slide";
    titleSlideDivision.appendChild(titleSlide);

    //Get the title and place it into the |titleSlideTitle| paragraph.

    var titleSlideTitle=document.createElement("p");
    titleSlideTitle.id="titleSlideTitle";
    
    var documentTitle=document.getElementById("documentTitle");
    if(documentTitle){
	var documentTitleContent=documentTitle.childNodes;

	var thisChildsClone;

	for(var i=0;i<documentTitleContent.length;i++){

	    thisChildsClone=documentTitleContent[i].cloneNode(true);
	    titleSlideTitle.appendChild(thisChildsClone);

	}
    } else { 
    
    }

    titleSlide.appendChild(titleSlideTitle);

    //Get the authors and place it into the |titleSlideAuthorList| paragraph.
    var titleSlideAuthorList=document.createElement("p");
    titleSlideAuthorList.id="titleSlideAuthorList";

    var authorList=document.getElementById("authorList");
    if(authorList){
	var authorListContent=authorList.childNodes;

	for(var j=0;j<authorListContent.length;j++){
	    thisChildsClone=authorListContent[j].cloneNode(true);
	    titleSlideAuthorList.appendChild(thisChildsClone);
	}
    } else {

    }
    titleSlide.appendChild(titleSlideAuthorList);    


    //Get the union bugs and add them to the |titleSlideUnionBugs| division.

    var titleSlideUnionBugs=document.createElement("div");
    titleSlideUnionBugs.id="titleSlideUnionBugs";

    var unionBugs=document.getElementById("unionBugs");
    if(unionBugs){
	var unionBugsContent=unionBugs.childNodes;

	for(var k=0;k<unionBugsContent.length;k++){
	    thisChildsClone=unionBugsContent[k].cloneNode(true);
	    titleSlideUnionBugs.appendChild(thisChildsClone);
	}
	
    } else {
    }
    titleSlide.appendChild(titleSlideUnionBugs);

    //Get the date and place it into the |titleSlideDate| paragraph.
    var titleSlideDate=document.createElement("p");
    titleSlideDate.id="titleSlideDate";

    var documentDate=document.getElementById("documentDate");
    if(documentDate){
	var documentDateContent=documentDate.childNodes;
    
	for(var k=0;k<documentDateContent.length;k++){
	    thisChildsClone=documentDateContent[k].cloneNode(true);
	    titleSlideDate.appendChild(thisChildsClone);
	}
    } else {
    }
    titleSlide.appendChild(titleSlideDate);


}

/*
\function{|getSlides()|}

Each slide is embedded within a |div| tag with the class name |slide| or |slideonly|. The code that places these into an array is straightforward.
 */

function getSlides(){
	var allDivs = document.getElementsByTagName("div");
	var allSlides = new Array();
	for (var i = 0; i< allDivs.length; i++) {
	    if (allDivs[i].className.search('^slide$')>=0) {
		allSlides[allSlides.length] = allDivs[i];
		}
	    if (allDivs[i].className.search('^slideonly$')>=0) {
		allSlides[allSlides.length] = allDivs[i];
	    }
	}
	return allSlides;
}


/*
\function{|createSlideIdentifers()|}

Navigation between slides in the screen view requires each slide to be identified. This function does so by setting each slide's |id| property to |_kppSlide#|
*/
function createSlideIdentifiers() {
	for (var n = 0; n < numberOfSlides; n++) {
		var e = arrayOfSlides[n]; 
		var id = '_kppSlide' + n.toString();
		e.setAttribute('id',id);
	}
}

/*
\function{|createSlideFrame()|}

In the screen view of slide mode, the currently visible slide is placed within a \emph{frame}. This is a division containing a header (with navigation controls) and a footer with bibliographic information and a slide counter. 

 */

function createSlideFrame(content,level){

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
    slideHeader.appendChild(slideNavigationBar);
    
    //The slide navigation bar contains three children: spans to anchor the left and right control buttons and a |<ul>| containing the table of contents.
    var slideNavigationLeftControlAnchor=document.createElement("span");
    var slideNavigationRightControlAnchor=document.createElement("span");
    slideNavigationLeftControlAnchor.id="slideNavigationLeftControlAnchor";
    slideNavigationRightControlAnchor.id="slideNavigationRightControlAnchor";

    var slideNavigationSectionList=createBranchList(content,level);

    slideNavigationBar.appendChild(slideNavigationLeftControlAnchor);
    slideNavigationBar.appendChild(slideNavigationSectionList);
    slideNavigationBar.appendChild(slideNavigationRightControlAnchor);

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

    //The other footer elements contain information from the |frontMatter| division.
    //Add a |div| containing the document's bibliographic information: title, authors, and date.
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
    
}

/*
  \function{|scrollNavigationBarLeft()|}
 */
function scrollNavigationBarLeft() {
    var navigationBar=document.getElementById("slideNavigationBar");
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
    var navigationBar=document.getElementById("slideNavigationBar");
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

To implement the opening of boxes within an external window, we program each link to one to call |displayBox| when clicked.

The links that appear within slide mode are the same ones that appear in prose mode. \emph{External links} have targets not in the current document, and they require little special handling. \emph{Internal links} refer to another location within the document. In prose mode, the browser is typically displaying an internal link's target as part of the current page. Clicking the link then simply repositions the document in the window so that the target is within the viewport. In slide mode, the situation is completely different. If a link's target lies on another slide, then we want a click on it to swap the current slide for the target's encompassing slide. If the target is not on a slide, then we might wish to switch slides anyways, or we might instead open a popup in prose mode with the viewport containing the target. This function modifies the internal links so that their activiation induces the desired behavior. 
*/

function brokenLinkAlert(){

    alert("Link points to document location that does not exist.");

}

function redirectInternalLinks(){

    var arrayOfAnchors=document.getElementsByTagName('a'); //Put all of the anchors into an array.

//Determine the browser's current target. We need this to classify links as internal and external.
    var thisPagesURL = window.location.origin+window.location.pathname; //Current page browser is pointed to
    
//Cycle through the anchors. For each one, determine whether it is internal and (if so) make the appropriate changes.
    for (var i=0; i<arrayOfAnchors.length;i++) {
	var hrefContents=arrayOfAnchors[i].href;
	var targetURL = hrefContents.match('^'+thisPagesURL+'#[_a-zA-Z0-9]+'); //Internal anchors begin with a hash sign and may contain only letters, numbers, and the underscore.
	if(targetURL){ //The variable |targetURL| will evaluate to |false| unless there was a match above.

	    //Get the target element's identifier from |hrefContents| and retrieve the target itself.
	    var hashLocation=hrefContents.search('#[_a-zA-Z0-9]+');
	    var targetId=hrefContents.slice(hashLocation+1,hrefContents.length);
	    var target=document.getElementById(targetId);
	    
	    /*
	    There are four cases to consider.
	    \begin{enumerate}
	    \item The target is |null|. In this case, we modify |onclick| to open a new window with the target URL. The code above that uses the URL's hash to direct the document's styling then takes command.
	    \item The target lies within a slide. The helper function |encompassingSlide| identifies this case. For such a link, we modify |onclick| so that the encompassing slide is displayed if the document is in screen view of slide mode.
	    \item The target does not lie within a slide but it is a sectioning division that preceeds a slide before another sectioning division of the same level. The helper functions |division| and |nextSlideOrHighHeadInDivision| identify this case. For these, we modify |onclick| to display the first slide of the division if the document is in slide mode's screen view.
	    \item Neither of the two above conditions holds good. This has two subcases
	    \begin{enumerate} 
	    \item The anchor appears somewhere in the |slideFrame| division. This means that the link is part of the slide mode's navigation tools, but there is no slide to which it can meaningfully be linked. We delete these links.
	    \item The anchor appears elsewhere in the document. For these, we modify |onclick| to open a new window using the target URL if the document is in slide mode's screen view.
	    \end{enumerate}
	    \end{enumerate}
	    Before proceeding, we predeclare variables used in the |if-else| block below.
	    */
	    var targetSlide; //Holds the slide that encompasses the anchor's target, if one exists.
	    var d;           //Holds the header level (an integer between 1 and 6) of the target, if the target is a header. Holds |null| otherwise.
	    /*
	    In the first case, we assign a function that alerts the reader that the link is ``broken.'' Since this is useful in all circumstances, we do not require that the document is in slide mode.
	    */
	    if(target==null){
		arrayOfAnchors[i].onclick= new Function("","window.open('"+hrefContents+"');" );
	    }
	    /*
	    In the second case, we assign a function that swaps the current slide for the encompassing slide to the anchor's |onclick| method. In the second case, the assigned function points to the first slide following the sectioning division. In the third case, we assign a function to |onclick| that opens a popup containing the article text positioned at the target.
	    */
	    /*
	    If the target is on a slide, then add an event handler to |onclick| that swaps the current slide for the desired slide.
	    */ 
	    else if (targetSlide = encompassingSlide(target)) {
//Find the encompassing slide's number, which is embedded in its |id| by |createSlideIdentifiers|.
		var targetSlideNumber=targetSlide.id.match('[0-9]+');
//Create the event handler. This only swaps the slides if |isDisplayingSlideScreen| is true.						     
		arrayOfAnchors[i].onclick = new Function("","if(isDisplayingSlideScreen){removeSlideFromFrame();currentSlideNumber="+targetSlideNumber+"; insertSlideIntoFrame("+targetSlideNumber+"); }");
	    }
	    /*
	      To check for the third case, we first use |division|. If its input is a header, then it returns its header level (an integer from 1 through 6). If it is not a header, then it returns |false|. The function |nextSlideOrHighHeading DecendingFromParent(target,d)| looks for the first slide or heading of level |d| or less that follows |target| in the document. If no such object exists, then it returns |false|. The |if| statement's final condition requires that this following object be a slide and not a heading. 

The only real difference between the code for handling this case and that immediately above is the definition of |targetSlide|.
	     */
	    else if((d=division(target)) && (targetSlide=nextSlideOrHighHeadingDecendingFromParent(target,d)) && !division(targetSlide)){		 
		var targetSlideNumber=targetSlide.id.match('[0-9]+');
		arrayOfAnchors[i].onclick = new Function("","if(isDisplayingSlideScreen){removeSlideFromFrame();currentSlideNumber="+targetSlideNumber+"; insertSlideIntoFrame("+targetSlideNumber+"); }");
	    } else {

		/*
		If neither of the above three cases holds good, then it must be that the link points somewhere without an encompassing or appropriately following slide. If the link is in the |slideFrame|, then we remove its parent |<li>| tag. This removes sectioning units without slides from the navigation bar. If the link is outside of the slide frame, then we modify its |onclick| event handler to open a new window in prose view.
		*/
		if(isInSlideFrame(arrayOfAnchors[i])){
		    var parentElement=arrayOfAnchors[i].parentNode;   //This should be a list item.
		    var grandParentElement=parentElement.parentNode;  //This should be an unordered list.
		    
		    grandParentElement.removeChild(parentElement);
		    //Removing this child reduces the size of |arrayOfAnchors| by one and slides the ``next'' anchor into the |i|'th position. 
		    //To ensure that we do not skip over that slide, decrement i.
		    i--;

		} else {
		    arrayOfAnchors[i].onclick = new Function("","if (isDisplayingSlideScreen){var internalLinkTarget=window.open('"+targetURL+"','internalLinkView'); internalLinkTarget.focus(); return false;}");
		}
	    }

	} 
	else { //The link is not external. Redirect the user to an external window if it is clicked.
	    arrayOfAnchors[i].onclick = new Function(""," if (isDisplayingSlideScreen){ var externalLinkTarget=window.open('"+hrefContents+"','externalLinkView'); externalLinkTarget.focus(); return false;}");
	}
    }

}

/*
\function{|encompassingSlide(element)|}

The function to return an element's encompassing slide (if any) is recursive and straightforward.

 */

function encompassingSlide(element){

    if (element == null || element.nodeName=='BODY') return null;
    else if (element.className=="slide") return element;
    else return encompassingSlide(element.parentNode);

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

    var keyC=67;
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

    case keyC: //Toggles between code mode and prose mode. Does not function in slide mode.
	if (isDisplayingProseScreen){ 
	    removeProseScreenStyle();
	    addCodeScreenStyle();
	    isDisplayingProseScreen=false;
	    isDisplayingCodeScreen=true;
	} else if(isDisplayingCodeScreen) {
	    removeCodeScreenStyle();
	    addProseScreenStyle();
	    isDisplayingProseScreen=true;
	    isDisplayingCodeScreen=false;
	} else if(isDisplayingProsePrint){
	    removeProsePrintStyle();
	    addCodePrintStyle();
	    isDisplayingProsePrint=false;
	    isDisplayingCodePrint=true;
	} else if(isDisplayingCodePrint){
	    removeCodePrintStyle();
	    addProsePrintStyle();
	    isDisplayingCodePrint=false;
	    isDisplayingProsePrint=true;
	}
	break;


    case keyS: //Toggles between slide mode and prose mode. Does not function in code mode. 
	if (isDisplayingProseScreen){
	    //The user wishes to switch to slide mode. First, hide everything and apply the appropriate style sheets.
	    removeProseScreenStyle();
	    addSlideScreenStyle();

            //Run |processResizeWindow| so that the navigation controls appear on startup if needed.
	    processResizeWindow();

	    isDisplayingProseScreen=false;
	    isDisplayingSlideScreen=true;

	    //Next, put the title slide (if entering for the first time) or the most recently viewed slide into the frame.
	    insertSlideIntoFrame(currentSlideNumber);
	    
	} else if(isDisplayingSlideScreen){
	    removeSlideScreenStyle();
	    addProseScreenStyle();

	    isDisplayingProseScreen=true;
	    isDisplayingSlideScreen=false;

	    removeSlideFromFrame();

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
    var navigationBar=document.getElementById("slideNavigationBar");
    var leftNavigationScrollControl=document.getElementById("slideNavigationLeftControlAnchor");
    var rightNavigationScrollControl=document.getElementById("slideNavigationRightControlAnchor");

    var leftNavigationScrollControlContents;
    var rightNavigationScrollControlContents;

    var navigationBarWidth=navigationBar.scrollWidth;
    var windowWidth=window.innerWidth;
    
    if ((windowWidth<navigationBarWidth) && (!rightNavigationScrollControlVisible)){

	var leftControlText=document.createTextNode("\u21E6");
	leftNavigationScrollControl.appendChild(leftControlText);

	var rightControlText=document.createTextNode("\u21E8");
	rightNavigationScrollControl.appendChild(rightControlText);
	rightNavigationScrollControlVisible=true;

    } 

    //If the window has been resized, there is not enough room to display the navigation bar, and the scroll controls are visible, then move the navigation bar to the right so that as much of it as possible is showing.
    if ((windowWidth<navigationBarWidth) && rightNavigationScrollControlVisible){
	
	if (navigationBarLeftOffset>navigationBarWidth-windowWidth+30){
	    navigationBarLeftOffset=navigationBarWidth-windowWidth+30;
	    navigationBar.style.left=-navigationBarLeftOffset+"px";
	    navigationBar.style.width=navigationBarWidth+"px";
	}

    }

    //If the window has been resized and there is enough room to display the navigation bar, remove the scroll controls and any existing left offset.
    if ((windowWidth>=navigationBarWidth) && rightNavigationScrollControlVisible){
	
	var leftNavigationScrollControlContents=leftNavigationScrollControl.firstChild;
	leftNavigationScrollControl.removeChild(leftNavigationScrollControlContents);

	var rightNavigationScrollControlContents=rightNavigationScrollControl.firstChild;
	rightNavigationScrollControl.removeChild(rightNavigationScrollControlContents);

	rightNavigationScrollControlVisible=false;

	navigationBarLeftOffset=0;
	navigationBar.style.left=-navigationBarLeftOffset+"px";
	navigationBar.style.width=navigationBarWidth+"px";
	
    }
}


//The following function inserts a clone of a slide into the frame.
function insertSlideIntoFrame(n){

    var slideFrame=document.getElementById("slideFrame");
    var slideFooter=document.getElementById("slideFooter");
    highlightNavigationBarLink(arrayOfSlides[n]);
    currentSlideClone=arrayOfSlides[n].cloneNode(true);
    //The |.cloneNode| method fails to clone event handlers, so the next lines manually do so.
    var originalAnchors=arrayOfSlides[n].getElementsByTagName('a');
    var cloneAnchors=currentSlideClone.getElementsByTagName('a');
    for(var i=0; i<originalAnchors.length;i++){
	cloneAnchors[i].onclick=originalAnchors[i].onclick;
    }
    //Now the slide is prepared to be put into the slide frame. With that accomplished, the footer's slide counter gets incremented.
    slideFrame.insertBefore(currentSlideClone,slideFooter);
    slideCounter();

}


function removeSlideFromFrame(){

    var slideFrame=document.getElementById("slideFrame");
    slideFrame.removeChild(currentSlideClone);

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
function highlightNavigationBarLink(aSlide) {
    
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