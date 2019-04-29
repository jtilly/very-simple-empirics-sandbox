#\section{Overview}
#The Komments++ literate programming system processes LaTeX-like formatting commands embedded within computer programs' comments, turns them into XHTML files viewable on a standard web browser, and provides Javascript and css code for supporting the reader's viewing experience. This Perl program carries out the first step of this process, the transformation of program and its comments into XHTML code. We call this the \emph{processing} step. 
#
#The processing step begins with assembling the input files, which are taken from the \emph{root} file given at the command line and any \emph{branch} files included in the document with the |\backslash{}input| command. Of course, these branch files can themselves contain |\backslash{}input| commands, thereby creating a multi-level document tree.\footnote{To put a stop to any potential infinite loop where a file inputs itself, we limit the number of branch levels with a named constant, |MAX_FILE_DEPTH|, set below in Section \ref{globalVariables}.} Once assembled, the document's content is then split into \emph{code} and \emph{comments} arrays. The \emph{primary processor} weaves the two arrays back together with XHTML tags formatting the code and separating it from the comments and then processes Komments++ commands in the comments to complete the document's body. \emph{Secondary} processors create the document's XHTML header, front matter, tables of code stripped of all comments, and XHTML footer.
#
#\subsection{Preliminary Declarations}
#The program requires two compiler directives (pragmas) and one external package. We use the |strict| pragma to increase the probability of bug detection, and the |re 'eval'| pragma to allow using |??\{\emph{Perl code here}\}| to evaluate Perl code within regular expressions at runtime. The resulting dynamic regular expressions are at the core of our code for finding and processing the Komments++ formatting commands.
use strict;
use re 'eval';
#The required external package, |File::Spec::Functions|, provides basic file manipulation routines.
use File::Spec::Functions;
#\subsection{Road Map}
#
#The program continues in the next section with the processing of the command line arguments. This creates the key global variable |\${}filename|, which stores the path to the root file being processed. Section \ref{globalVariables} declares other global variables. These include
#\begin{itemize}
#\item Named constants that fine tune the program's behavior,
#\item Regular expressions that define the syntax of Komments++ commands and environments, and
#\item Hashes that link commands and environments with the subroutines that implement them.
#\end{itemize}
#Section \ref{documentCreation} gives the code that carries out document creation by assembling the input files, calling the primary and secondary processors, and assembling their output. The remaining sections contain the subroutines that implement these steps.
#
#\section{Command Line Arguments\label{commandLine}}
#The program begins with the processing of the command line arguments. Nothing terribly sophisticated occurs here. There are three valid invocations of |kpp|.
#\begin{itemize}
#    \item |kpp -help| prints a short version and help message and exits.
#    \item |kpp \emph{path/to/filename}| proceses the contents of |\emph{filename}| and places the resulting document in |\emph{path/to/}|. If |\emph{filename}| resides in the current directory, its path can be omitted.
#    \item |kpp \emph{path/to/filename} -zip| processes the contents of |\emph{filename}| and places the resulting xHTML file and any generated images into a zip file archive in |\emph{path/to/}|. Again, the path can be omitted for files in the current directory.
#\end{itemize}
#Unless the user has requested help, the program should retrieve the name of the file being processed and an indicator of whether to assemble a zip file after processing. We place this information in eponymous variables and set the default to create no zip file.
my $fileName;
my $zipFiles=0;
#Since correct syntax requires one or two command line arguments, we begin with killing the program in all other cases. Perl stores the arguments themselves in the preset array |@ARGV|. Using this in scalar context gives the number of arguments.
if    ( @ARGV == 0 ) { die "No files input -- dying ...\n"; }
elsif ( @ARGV >  3 ) { die "Too many arguments -- dying ...\n"; }
#The first argument is either a request for help or the name of the file to be processed. In the first case, the program prints the help message and exits.
if($ARGV[0] eq '-help'){

    print "Komments++ (Version 0.2 ADAMS)\n";
    print "by Jeffrey R. Campbell and Ryan Peters\n";
    print "Usage: kpp [FILENAME] [OPTIONS]\n";
    print "\t Apply Komments++ on FILENAME, to produce FILENAME.html\n";
    print "\t OPTIONS:\n";
    print "\t -zip\t\t Put resulting XHTML and local image files into  FILENAME.zip\n";
    print "\t -help\t\t Print this help and exit.\n";
    exit 0;

} else {
    $fileName=$ARGV[0];
}
#If there is a second argument, it must equal |-zip|.
if (@ARGV == 2){
    if($ARGV[1] eq '-zip'){
	$zipFiles=1;
    } else {
	die "kpp: Unknown option: ".$ARGV[1].".\n";
    }
}
#
#\section{Global Variables\label{globalVariables}}
# The two global variables |$fileName| and |$zipFiles| have already been declared, but many more await initialization. We begin with the regular expressions that determine the syntax of Komments++.
#
#\subsection{Syntax Definitions}
#
#Komments++ borrows its syntax from LaTeX. \emph{Commands} and \emph{Environments} structure the content. Commands begin with the backslash character. A bracketed \emph{option} can follow the command name, and then come one or more \emph{arguments}, each enclosed by braces. For example
#    || \backslash{}emph{This text will be emphasized with italics.} ||
#    || \backslash{}url{http://www.google.com}{This creates a hyperlink to Google.} ||
#    || \backslash{}input[3..5]{sin.c} ||
#    Each environment opens with a |\backslash{}begin| command with the environment name as its single argument, and it closes with a matching |\backslash{}end| command. The following example places two lines of \textsc{C} code into an environment used to create displayed non-working code.
#  ||\backslash{}begin{displaycode}
# int x; 
# x=sin(pi/4);
#\backslash{}end{displaycode}||
#  Its output is
#\begin{displaycode} int x;
# x=sin(pi/4); \end{displaycode}
#Another important example is the environment for including code inline. For example |\backslash{}begin{code} x=sin(pi/4)\backslash{}end{code}| produces \begin{code} x=sin(pi/4) \end{code}.
#
#    The processing of commands and environments begins with the application of regular expressions to identify them and extract their names, options, arguments, and contents. Each command and environment has as associated subroutine that processes its content and returns |xHTML| code. Two hashes declared in this section return the subroutine names for environments and commands, respectively. Many of the commands take no arguments and return symbols, such as |\backslash{}nis| for \nis{} (the New Israeli Shekel). In this section, we also creat a hash that gives these symbols' Unicode values. 
#
#\subsubsection{Regular Expressions\label{regularExpressions}}
#
#The two core regular expressions we require match and capture commands and environments. Since commands' arguments can contain other commands (e.g. |\backslash{}emph{Fran\backslash{}c\{c\}ois}|, which creates \emph{Fran\c{c}ois}) these require a regular expression to match \emph{matched pairs} of braces. For this, we use \emph{dynamic} regular expressions, as explained in Chapter 7 of \cite{friedl2006}. These are recursively defined regular expression objects created with Perl's |qr| operator. Because the object containing the regular expression is used in its own declaration, it must be predeclared.
#
my $matchingBraces;     
$matchingBraces = qr/\{(?:[^{}]|(??{$matchingBraces}))*\}/;
#Reading inwards from the outside clarifies this expression. At the outermost level, the regex requires a leading left brace (the ``|\backslash{}{|'') with a matching ending right brace (``|\backslash{}}|''). Immediately inside of that are a pair of non-capturing parentheses (starting with ``|(?:|'' and ending with ``)'') followed by the zero-or-more qualifier, ``|*|''. The regular expression within the parentheses matches either any character that is not a left or right brace, (``|[^{}]|'') or the matching braces regular expression.\footnote{Note that the braces within the character class are \emph{not} escaped because they are not metacharacters in that context.} We include the |\${}matchingBraces| regular expression within itself using the dynamic regular expression construct, ``|??\{\emph{Perl code here}\}|. When the regular expression engine reaches this, it executes the Perl code and places its contents at the construct's location. 
#
#The need for a regular expression to match \emph{matching} brackets is not so great, because command options typically do not contain bracketed expressions. Nevertheless, there is no harm in enforcing bracket matching. We do so by appropriately changing the braces in |$matchingBraces| to brackets.
my $matchingBrackets;
$matchingBrackets = qr/\[(?:[^\[\]]|(??{$matchingBrackets}))*\]/;
#We build the first principle regular expression, that for matching Komments++ commands from |\${}matchingBraces|. Its definition limits the characters that may appear in command names to letters (small and capital), |\$|, |\&|, |\#|, |\||, |\_|, |\%|, |`|, |^|,|"|,|~|,|=|, and the period.
my $kppCommand;
$kppCommand = qr/(?<!\\)\\([}{]|[a-zA-Z\$&#|_%`'^"~=.]+)(\[[^\\]*?\])?($matchingBraces+)?/;
#From left the right, the first grouped expression is a negative lookbehind which matches on anything but a backslash, and a backslash immediately follows this. Together, these require that a command starts with an unescaped backslash. What follows is a pair of capturing parentheses containing the character class listing the allowable characters within a command name followed by the one-or-more operator, ``|+|''.\footnote{Note that two of the allowable characters within a command name are |``\{{}''| and |''\}{}''|, which we require for the commands that create the left and right braces themselves.} The next pair of capturing parentheses matches any options associated with the commands, and the question mark following it is the operator that requires either zero or one matches to its predecessor. The class of characters allowed between the brackets omits the backslash, so commands may not appear in options. The regular expression ends with a requirement for either zero or one matches to a regular expression that allows one or more |$matchingBraces|, which give the command's arguments. Following a match, the command's name, its options, and its arguments are stored in |$1|, |$2|, and |$3| respectively.
#
#The regular expression for matching Komments++ environments builds on |\${}kppCommand|, and it accounts for the possible inclusion of one environment within the scope of another. As in LaTeX, an environment's scope starts with a starting delimiter, |\backslash{}begin\{\textit{environment name}\}[\textit{options}]|, and finishes with an ending delimiter, |\backslash{}end\{\textit{environment name}\}|. The regular expression begins with code very similar to that in |$kppCommand| to match a starting delimiter. We place its definition on multiple lines with relveant commentary between them to ease its interpretation.
my $kppEnvironment;
$kppEnvironment = qr/(?<!\\)\\begin($matchingBraces)(\[[^\\]*?\])?
#To capture all of the environment's content, we must account for the possibility that the first instance of the appropriate ending delimiter might not be that which matches the starting delimiter. This occurs when an environment's contents contain an instance of itself, as frequently happens in LaTeX with the |enumerate| and |itemize| environments. For this, we use a regular expression that matches either a string of non-backslash characters or an environment with all of its contents. If neither of these is is possible, it matches the next character. Appending the one-or-more operator to this matches all of the contents.						
			((?:[^\\]*|(??{$kppEnvironment})|.)+)
#We complete the regular expression with the pattern to detect the ending delimiter. Since the first capturing parentheses stores the environment's name in |\$1|, we use |\backslash{}1| to retrieve it.
			(?<!\\)\\end\1/sx;
#LaTeX provides very useful short forms for inline math (|\${}...\${}| and |\backslash{}(...\backslash{})|) and displayed math (|\backslash{}[...\backslash{}]|). We create the following three regular expressions so that we can implement these same short forms in Komments++. Since none of these environments may contain other instances of themselves, their definitions need not be recursive.
my $shortFormMath1=qr/(?<!\\)\$(.*?)(?<!\\)\$/s;
my $shortFormMath2=qr/(?<!\\)\\\((.*?)\\\)/s;		
my $shortFormDisplayMath=qr/(?<!\\)\\\[(.*?)\\]/s;     
#Unlike in LaTeX, code has equal status with mathematics in Komments++, so the environments for displaying also have short forms. That for the |code| environment is a matched pair of single pipes, as in  |\|{}int x\||. The |displaycode| environment uses matched pairs of double pipes. For example, |\|\| x++;\|\||. The following regular expressions match these shortforms and store their contents in |$1|.
my $shortFormCode=qr/(?<!\\)\|(?!\|)(.+?)(?<!\\)\|/s;
my $shortFormDisplayCode=qr/(?:(?<!\\)\|){2}(.+?)((?<!\\)\|){2}/s;
#When parsing the input, it is helpful to have a regular expression to detect the start of one of these environments' short forms. This only gets used once (far) below, but we place it here so that its consistency with the above regular expressions can be readilly assessed.
my $shortFormStarts=qr/((?<!\\)\$)|((?<!\\)\\\()|((?<!\\)\\\[)|((?<!\\)\|)/;
#\subsubsection{Lookup Tables}
# \paragraph{Environments and Commands} When the primary parser encounters an environment, it passes the environment's name, options, and contents to a subroutine retrieved from a lookup table stored in the |%environments| hash. 
my %environments = (
	"math"         => "math",
	"displaymath"  => "math",
	"equation"     => "math",
	"eqnarray"     => "matharray",
	"eqnarray*"    => "matharray",
	"code"         => "code",
	"displaycode"  => "code",
	"figure"       => "float",
	"table"        => "float",
        "box"          => "float",
	"tabular"      => "tabular",
	"bibliography" => "bibliography",
	"itemize"      => "list",
	"enumerate"    => "list",
	"dictionary"   => "list",
        "tree"         => "list",
	"abstract"     => "returnNothing",
        "preface"      => "returnNothing",
        "dedication"   => "returnNothing",
	"quote"        => "quote",
	"quotation"    => "quote",
        "hiddencode"   => "hiddencode",
	"slide"	       => "slide",
        "omitfromslide" => "omissions",
        "omitfromprose" => "omissions"
);
#One of the subroutines listed above, |returnNothing|, deserves some comment here. This simply returns an empty string, so primary parser effectively ignores the |abstract|, |preface|, and |dedication| environments. However, a secondary parser that assembles the document's front matter does \emph{not} ignore them.
#
#The primary parser handles commands similarly. The relevant lookup table is stored in |%commands|.
my %commands = (
	"documentclass" => "returnNothing",
	"title"         => "returnNothing",
	"head"		=> "returnNothing",
	"author"        => "returnNothing",
	"thanks"	=> "returnNothing",
	"date"          => "returnNothing",
        "copyrightnote" => "returnNothing",
        "doi"           => "returnNothing",
        "classification"=> "returnNothing",
        "unionbug"      => "returnNothing",
        "coverart"      => "returnNothing",
	"label"         => "returnNothing",
        "part"          => "sections",
        "chapter"       => "sections",
	"section"       => "sections",
	"subsection"    => "sections",
	"subsubsection" => "sections",
	"paragraph"     => "sections",
        "function"      => "sections",
        "method"        => "sections",
	"subroutine"    => "sections",
        "module"        => "sections",
        "shebang"       => "shebang",
	"`"             => "accents",
	"'"             => "accents",
	"^"             => "accents",
	"\""            => "accents",
	"~"             => "accents",
	"="             => "accents",
	"."             => "accents",
	"u"             => "accents",
	"v"             => "accents",
	"H"             => "accents",
	"b"             => "accents",
	"d"             => "accents",
	"r"             => "accents",
	"c"             => "accents",
	"t"             => "accents",
	"oe"            => "symbols",
	"OE"            => "symbols",
	"ae"            => "symbols",
	"AE"            => "symbols",
	"aa"            => "symbols",
	"AA"            => "symbols",
	"o"             => "symbols",
	"O"             => "symbols",
	"l"             => "symbols",
	"L"             => "symbols",
	"ss"            => "symbols",
	"dag"           => "symbols",
	"ddag"          => "symbols",
	"S"             => "symbols",
	"P"             => "symbols",
	"copyright"     => "symbols",
	"pounds"        => "symbols",
	"euro"          => "symbols",
	"nis"           => "symbols",
	"yen"           => "symbols",
	"cruzeiro"      => "symbols",
	"won"           => "symbols",
	"#"             => "symbols",
	"\$"            => "symbols",
	"%"             => "symbols",
	"&"             => "symbols",
	"_"             => "symbols",
	"{"             => "symbols",
	"}"             => "symbols",
	"|"             => "symbols",
        "commandkey"    => "symbols",
        "optionkey"     => "symbols",
        "shiftkey"      => "symbols",
        "escapekey"     => "symbols",
        "controlkey"    => "symbols",
        "returnkey"     => "symbols",
        "backslash"     => "symbols",
        "checkmark"     => "symbols",
        "leq"           => "symbols",
        "geq"           => "symbols",
        "neq"           => "symbols",
        "times"         => "symbols",
        "div"           => "symbols",
	"emph"          => "typestyle",
	"textup"        => "typestyle",
	"textit"        => "typestyle",
	"textsl"        => "typestyle",
	"textsc"        => "typestyle",
	"textmd"        => "typestyle",
	"textbf"        => "typestyle",
	"textrm"        => "typestyle",
	"textsf"        => "typestyle",
	"texttt"        => "typestyle",
        "info"          => "semantics",
	"image"         => "images",
	"caption"       => "caption",
	"url"           => "url",
	"footnote"      => "footnote",
	"cite"          => "cite",
	"ref"           => "ref",
	"appendix"	=> "appendix",
	"inlineComment" => "comments",
	"closeCommentBlock" => "comments",
	"openCommentBlock"  => "comments",
	"slidetitle"	=> "returnNothing"
);
#\paragraph{Helper Tables} Two of the subroutines listed above, |sections| and |symbols|, use lookup tables. The |sections| subroutine handles the various sectioning commands, most of which correspond to standard LaTeX commands. The primary parser creates an xHTML heading tag for each sectioning command. The following lookup table gives each sectioning command's corresponding heading tag.
my %sectionTags = (
        "part"          => "h1",
        "chapter"       => "h2",
	"section"       => "h3",
	"subsection"    => "h4",
	"subsubsection" => "h5",
	"function"      => "h5",
	"method"        => "h5",
        "subroutine"    => "h5",
	"paragraph"     => "h5",
        "subparagraph"  => "h6"
);
#The many commands calling the |symbols| subroutine implement the symbol creation commands listed in Table 3.2 of \cite{lamport1994}, the six special punctuation symbols mentioned immediately after that table, And several other useful symbols. These are created by simply inserting the corresponding Unicode character entity reference. The following hash contains these references.\footnote{The |accents| subroutine also uses unicode characters to implement the various accenting commands, but their implementation is complicated enough to require more than a simple lookup table.}
my %symbolTable = (
#Symbols from Table 3.2
	"oe"        => "&#x0153;",
	"OE"        => "&#x0152;",
	"ae"        => "&#x00E6;",
	"AE"        => "&#x00C6;",
	"aa"        => "&#x00E5;",
	"AA"        => "&#x00C5;",
	"o"         => "&#x00F8;",
	"O"         => "&#x00D8;",
	"l"         => "&#x0142;",
	"L"         => "&#x0141;",
	"ss"        => "&#x00DF;",
	"dag"       => "&#x2020;",    
#Special punctuation symbols
	"ddag"      => "&#x2021;",
	"S"         => "&#x00A7;",
	"P"         => "&#x00B6;",
	"copyright" => "&#x00A9;",
	"pounds"    => "&#x00A3;",
#Currency symbols
	"euro"      => "&#x20AC;",    #Euro currency symbol
	"nis"       => "&#x20AA;",    #New Israeli Shekel
	"yen"       => "&#x00A5;",    #Japanese Yen
	"cruzeiro"  => "&#x20A2;",    #Brazilian Cruzeiro (out of circulation).
	"won"       => "&#x20A9;",    #Korean Won
#LaTeX control tokens.
	"#"         => "&#x0023;",    #Pound/Hash sign
	"\$"        => "&#x0024;",    #Dollar Sign
	"%"         => "&#x0025;",    #Percentage Sign
	"&"         => "&#x0026;",    #Ampersand
	"_"         => "&#x005F;",    #Underscore
	"{"         => "&#x007B;",    #Left Brace
	"}"         => "&#x007D;",    #Right Brace
        "backslash" => "&#x5c;",      #Backslash
#The single additional Komments++ control token, the pipe.
	"|"         => "&#x007C;",    
#Keyboard and computer symbols
        "commandkey" => "&#x2318;",     #Apple command key
        "optionkey" =>  "&#x2325;",     #Option/alt key
        "shiftkey"   => "&#x21E7;",     #Shift key
        "escapekey" =>  "&#x238B;",     #Escape key
        "controlkey" => "&#x2303;",     #Control key
        "returnkey"  => "&#x21A9;",     #Return key
#An assortment of mathematical symbols.
        "geq"        => "&#x2265;",    #Greater-than-or-equal-to symbol.
        "leq"        => "&#x2264;",    #Less-than-or-equal-to symbol.
        "neq"        => "&#x2260;",    #Not equal to.
        "gt"         => "&#x003E;",    #Greater than
        "lt"         => "&#x003C;",    #Less than
        "times"      => "&#x00D7;",    #Times symbol
        "div"        => "&#xF7;",      #Division symbol.
#Miscellaneous symbols.
        "checkmark"  => "&#x2713;"     #Check mark.
);
#The frontmatter processor requires one more table. This simply lists the Unicode character references used as footnote symbols for the notes created after authors' names with the |\backslash{}thanks| command.
my @thanksSymbols = qw(&clubs; 
                       &diams; 
                       &hearts; 
                       &spades; 
                       &loz; 
                       &Dagger; 
                       &dagger; 
                       &#x00A7; 
                       &#x2736;);
#\subsection{Counters, Footnotes, and References}
#Komments++ mimics LaTeX's automatic generation of the numbers that label sectioning units, equations, and floating environments. The hash |%counters| keeps the relevant counters for this task. It contains one additional counter, |LaTeXimage|, which gets used for assigning names to the image files created by LaTeX.
my %counters = {
        part                    => 0,
	chapter                 => 0,
	section    		=> 0,
	subsection 		=> 0,
	subsubsection 		=> 0,
	figure     		=> 0,
	table      		=> 0,
        box                     => 0,
	footnote   		=> 0,
	equation   		=> 0,
	LaTeXimage 		=> 0
};
#This completes the declaration of the program's lookup tables. 
#
#The primary processor uses the next four global variables to implement automatic cross referencing. The |footnote| command inserts each footnote's contents into the array |@footnotes|. One of the secondary processors uses this to create the table of footnotes at the end of the document.
my @footnotes;             
#The |bibliography| environment in concert with the |bibitem| and |cite| commands handle the automatic insertion of bibliographic references similarly to the use of |thebibliography|, |bibitem| and |cite| in LaTeX. For this task, they use |%citelabels| to associate each bibliographic item's citation key with its label. 
my %citelabels;
#Komments++ also mimics the functionality of LaTeX's |label| and |ref| commands which allow the retrieval of numbered objects' numbers within the text. For this, |%reflabels| store's each labeled item's printable reference and |%refappstat| contains a dummy variable for each referenced object indicating whether or not it is in an appendix. 
my %reflabels;
my %refappstat;
#\subsection{Processor Control Variables\label{processorControlVariables}}
#The primary processor uses several gloabl variables. To understand the first of these, one must have some idea of how the primary processor works. Its main subroutine, |process|, scans its input looking for environments and commands. When it encounters one, it passes its input to the relevant subroutine from |%environments| or |%commands|. Many of these subroutines in turn call |process|, so this subroutine can call itself. The gloabl |$processLevel| keeps track of how deeply nested these calls become.
my $processLevel = 0;  
#When |$processLevel| equals zero, |process| encompasses its output in matching paragraph tags (|<p>...</p>|).
#Komments++ syntax does not allow environments to contain sectioning commands. To enforce this restriction, the parser uses |$environmentLevel| to keep track of how deeply nested the environments become. If a sectioning command occurs when this is positive, the program returns an error.
my $environmentLevel=0;
#\subsection{Miscellaneous Variables}
#The remaining global variables do not really fall into any of the above categories, so we label them as miscellaneous. We begin with two used by the |sections| subroutine. The sectioning commands give the |<span>| containing their output a different class if they follow an |\backslash{}appendix| command. The primary processor looks to |$isInAppendix| as an indicator for this task.
my $isInAppendix = 0;
#The sectioning commands also assign an |id| value to these spans if the user has not included a |\backslash{}label| command within their arguments. The primary processor uses |$defaultLabelCounter| to make each of these unique.
my $defaultLabelCounter = 0;
#The |\backslash{}caption| command places either ``Figure'' or ``Table'' at the start of its output. To determine which is appropriate, we store the current float type within a global variable. This is initialized to |"None"| so that the command can determine if it has been (inappropriately) called outside of a float.
my $floatType = "None"; 
#Under Unix, if the first line of a text file begins with ``|\#!|'', then the computer interprets the rest of the line as a Unix command to be run with the remainder of the file passed to the program's standard input. This \emph{shebang} is a common method of making scripts executable.\footnote{Indeed, the install script places a shebang at the top of |kpp.pl| to make it executable.} This use of a comment directly conflicts with Komments++. To handle this, each input file is examined to see if it begins with a shebang. If so, it is removed before further processing and its contents are stored in the global variable |$shebang|. The |\backslash{}shebang| command places the most recently read shebang into the document.
my $shebang;
#The processor needs to know the path used to retrieve the input file for three tasks:
#\begin{enumerate}
#\item The |\{}input| command is assumed to have a file name with a path that is relative to its containing file. To open it, we need to have a path that either absolute or relative to Perl's current working directory.
#\item The content of files included in the current document is assumed to include relative file paths -- in |\{}input| and image-inclusion commands -- relative to the containing files. So that the final document loads correctly, these should be made relative to the root document.
#\item The output file (or files, if the |-zip| option was used) should be written to the directory containing the root input file.
#\end{enumerate}
#For all of these purposes, we wish to separate |\${}fileName| into the path used to reach the file from the Perl executable and the name of the file in its containing directory. For this, we use |File::Spec|'s |splitpath| function. This also returns the file's drive letter in |volume| if this is being run on Windows.
(my $parentVolume,my $parentDirectory,$fileName)=File::Spec->splitpath($fileName);

#If the user has requested a zip file be created, then we require a list of the files it includes. The primary and secondary processors store this list in |@filesToBeZipped|.
my @filesToBeZipped;
#The only global variables remaining to be defined are both constants. The first sets the maximum number of times the |\backslash{}input| command for loading files can call itself, and the second sets the number of lines used for each bar line of the ``green bar'' display (meant to mimic the old-style green paper) used for presenting working code.
use constant MAX_FILE_DEPTH => 10;
use constant BARLINES	    =>  2;
#
#\section{Processing\label{documentCreation}}
#This final section describes document processing from a top-down perspective. We begin with the primary processor and then consider the secondary processors on which it relies.
#
#The primary processor follows the following recipe.
#\begin{enumerate}
#\item Read the input file(s) and divide its (their) lines into two groups, \emph{comments} and \emph{working code},
#\item Create the output document's |xHTML| header, which includes standard boilerplate as well as Javascript and |css| code,
#\item Weave the formatted comments and working code into the document's \emph{body},
#\item Assemble the document's \emph{front matter}. This is a |div| tag containing the document's title, author(s), abstract, and other bibliographic information,
#\item Create a |div| containing a formatted listing of the program's code. This allows the reader to see all of the program's code together without ``distracting'' commentary,
#\item Create the document's |xHTML| footer, which closes |div| tags opened in the header. 
#\end{enumerate}
#The first of these steps obviously must preceed the others. The only other requirement for their ordering is that the body should be created before the frontmatter, because the body's creation populates |\${}citeLabels| and |\${}reflabels| and these are used to property format citations and references in the front matter.
#
#The subroutine |infile| starts the reading of the input files. It also gets called whenever the |\backslash{}infile| command is encountered. Its first argument gives the file name to be input, its second argument gives the number of file levels traversed before encountering the particular |\backslash{}input| command at hand, and the third argument determines which lines of the file are to be input. We start it at file level zero and instruct it to read all of the input lines. The subroutine returns a hash consisting of four equal-sized arrays, |code|, |comments|, |fileNames|, and |lineNumbers|. Each array's element corresponds to one line in an input file; |code| and |comments| contain any code or comments on that line, |fileNames| contains the name of the source file, and |lineNumbers| contains the source file's line number. It uses the global variables |\${}parentVolume| and |\{}parentDirectory| to open the file, so it accepts only the containing directory's name. 
my %input = &infile( $fileName, 0 ,'all');
# The document's class (from the |\backslash{}documentclass| command) determines the Javascript and CSS code included within its header. The header also uses the standard |<title>| tag  to create a ``running header'' in the browser's information bar. By default, this contains |\${}fileName|. The user can override this with the |\backslash{}head| command. Since all commands are in the program's comments. The subroutine |xhtmlHeader| takes the array of these comments as its only input and returns an array containing lines of the xHTML header embedded within the standard |<head>| tag.
my @xhtmlHeader = &xhtmlHeader( @{ $input{comments} } );
# The document's corups is woven from the comments and code by |bodyPages|. The array it returns define a |<div>| with the id |bodyPages| and a second |<div>| with id |footnotes|.
my @bodyPages = &bodyPages(%input);
# The |frontMatter| subroutine also takes the input files' comments as its input and returns an array containing lines of xHTML code that define a |<div>| with the id |frontMatter|.
my @frontMatter = &frontMatter(@{$input{comments} });
# The |onlyCode| subroutine creates a |<div>| with id |onlyCode|. One might think that it should use no fields of |\%{}input| besides |code|, but it also uses |fileNames| and |lineNumbers| to label each file and line of code.
my @onlyCode = &onlyCode(%input);
# The document's footer simply closes tags opened in the header. Its contents do not depend on any of the input.
my @xhtmlFooter = &xhtmlFooter();
#All that remains is document assembly, output, and (possibly) the creation of the zip file. We assemble the document in the |@output| array and write it to a file with the |.html| extension appended to the original input file name. 
my @output;
push @output, @xhtmlHeader;
push @output, @frontMatter;
push @output, @bodyPages;
push @output, @onlyCode;
push @output, @xhtmlFooter;

my $tolocation = $parentVolume.$parentDirectory.$fileName.".html";
open HTML, ">$tolocation"; 
print HTML @output; 
close HTML; 

# The subroutines |frontMatter|, |images|, and |useLaTeX| have populated |@filesToBeZipped| with the image files either referenced locally or created to present the document's math. The final file to be added is the |XHTML| file itself. With this completed, we can create the zip file using the system's |zip| utlity if requested.
push @filesToBeZipped, $fileName.".html";

if($zipFiles){
    if ($parentDirectory=~/^\s*$/){ #|chdir| below hates empty arguments.
	$parentDirectory='.';
    }
    chdir "$parentDirectory";
    my $zipFile=$fileName.".html.zip";
    my $zipoutput=`zip $zipFile $fileName @filesToBeZipped`;
    print @filesToBeZipped;
    print "\n";
}
#This completes the primary processor. 
#
#\subsection{File Input\label{fileInput}}	    
#
#Input files come from two sources, the root file given by the user from the command line and any \emph{branch} files included with the |\backslash{}input| statement. The four subroutines of this section implement the inputting of these files and carry out their initial processing. Together, they implement the |\backslash{}input| command, which has the following syntax.
#|| \backslash{}input[\emph{lines to input},\emph{format}]\{\emph{file name}\} ||
#    Here, |\emph{file name}| gives the path to a file. This can be either absolute or relative to the document containing the |input| statement. The indicated file's contents will be inserted at this location of the document. Branch files can themselves contain |\backslash{}input| commands, and Komments++ automatically converts paths specified relative to the branch file to be relative to the root.\footnote{This relative path conversion also occurs for relative paths that are arguments of |\backslash{}image|.}  The option |\emph{lines to input}| determines which lines from the given file will be inserted. Its default value is |'all'|. To input only lines in a given range, the user can input the first and last lines separated by two periods. For example, |'3..15'| inputs lines 3 through 15 inclusive. A range starting from a given line and running through the file's end can be indicated with |end| replacing the final line number, as in |'3..end'|. Two other options for this argument select only the file's working code, |'onlyCode'|, and only its comments, |'onlyComments'|. The final option, |\emph{format}| can take on one of three values, The default value, |'separate'| directs the processor to format code and comments separately. To have the processor interpret all lines as working code, even those with comments, the user can set this to |'allCode'|. Alternatively, setting |\emph{format}| to |'allComments'| directs the processor to interpret all of the input lines as comments.\footnote{The program examines the entire file to find its comments and code, even if the user has requested only certain lines be used. Therefore, lines included from within a comment block are treated as comments, even if the lines opening and closing the comment block are omitted.}
#
#To illustrate the input process, consider the following example. The root file is
#\input[all code]{examples/C/hello.c}
#And its single branch file is
#\input[all code]{examples/C/howdy.c}
#With this, file input begins with |hello.c|. The program loads the file and uses its extension to determine that it is a file of \textsc{C} source code. Using its comments, it creates a hash with four fields, |code|, |comments|, |fileNames|, and |lineNumbers|. Each corresponds to an array with eleven elements, one for each source file line. The result is
#\begin{tabular}{lllll}
# |Element| & |code| & |comments| & |fileNames| & |lineNumbers| \\
#    |0| & & |\backslash{}documentclass\{none\}| & |hello.c| & |1| \\
#    |1| & & |The file begins with a preprocessor directive.| & |hello.c| & |2| \\
#    |2| & |#include\&{}lt;stdio.h\&{}gt;| & & |hello.c| & |3| \\
#    |3| & & |After this comes the main function.| & |hello.c| & |4| \\
#    |4| & |int main(void)\{| & |Takes no inputs and returns an integer.| & |hello.c| & |5| \\
#    |5| & |\_{}\_{}printf("Hello World!\backslash{}n");| & & |hello.c| & |6|\\
#    |6| & |\_{}\_{}return(0);| & & |hello.c| & |7| \\
#    |7| & |\}| & & |hello.c| & |8| \\
#    |8| & & |An alternative version of this program| & |hello.c| & |9| \\
#    |9| & & |that completes the same greeting task is below| & |hello.c| & |10| \\
#    |10| & & |\backslash{}input[4..7]\{alternatives/howdy.c\}| & |hello.c| & |11| \\
#\end{tabular}
#In elements 6 and 7, underscores indicate the indentation spaces preserved from the source file. The contents of each line's working code are in |code|, while each line's comments are in |comments|. Line 5 contains both working code and comments, so the fourth elements of both |code| and |comments| are non empty. The lines represented in this hash came from the same file, so all elements of |fileNames| equal |hello.c|. Finally, note that the inequality signs in |#include<stdio.h>| are changed to their Unicode character entities in element 2 of |code|. The program changes \emph{all} inequality signs in this way so that they cannot be mistaken as defining XHTML tags.
#
#With the root file loaded and its corresponding hash created, the program then examines the comments for an |\backslash{}input| command. If it finds one \emph{and it satisfies the syntactic restriction that nothing else appears on its line}, then it loads the file and creates its hash.\footnote{An |\backslash{}input| command that appears with other text on the same line causes the program to halt and return an error message.} For the example, the branch file's hash is
#\begin{tabular}{lllll}
# |Element| & |code| & |comments| & |fileNames| & |lineNumbers| \\
# |0| & & |Alternative greeting program| & |alternatives/howdy.c| & |1| \\
# |1| & |#include\&{}lt;stdio.h\&{}gt;| & & |alternatives/howdy.c| & |2| \\
# |2| & & & |examples/C/howdy.c| & |3|\\
# |3| & |int main(void)\{| & & |alternatives/howdy.c| & |4|\\
# |4| & |\_{}\_{}printf("Howdy!\backslash{}n");| & & |alternatives/howdy.c| & |5| \\
# |5| & |\_{}\_{}return 0;| & & |alternatives/howdy.c| & |6| \\
# |6| & |\}| & & |alternatives/howdy.c| & |7| \\
# |7| & & |The following line loads an image with my signature.| & |alternatives/howdy.c| & |8| \\
# |8| & & |\backslash{}image\{examples/C/signature.jpg\}| & |alternatives/howdy.c| & |9| \\
#\end{tabular}
#Note that the path to |signature.jpg| in the final line's |\backslash{}image| command has been converted so that it is relative to the trunk file's location.
#
#The child file contains no |\backslash{}input| commands, so the actual loading of files is complete. The final file input step inserts the requested lines (four through seven) into the root file's hash.
#\begin{tabular}{lllll}
# |Element| & |code| & |comments| & |fileNames| & |lineNumbers| \\
#    |0| & & |\backslash{}documentclass\{none\}| & |hello.c| & |1| \\
#    |1| & & |The file begins with a preprocessor directive.| & |hello.c| & |2| \\
#    |2| & |#include\&{}lt;stdio.h\&{}gt;| & & |hello.c| & |3| \\
#    |3| & & |After this comes the main function.| & |hello.c| & |4| \\
#    |4| & |int main(void)\{| & |Takes no inputs and returns an integer.| & |hello.c| & |5| \\
#    |5| & |\_{}\_{}printf("Hello World!\backslash{}n");| & & |hello.c| & |6|\\
#    |6| & |\_{}\_{}return(0);| & & |hello.c| & |7| \\
#    |7| & |\}| & & |hello.c| & |8| \\
#    |8| & & |An alternative version of this program| & |hello.c| & |9| \\
#    |9| & & |that completes the same greeting task is below| & |hello.c| & |10| \\
# |10| & |int main void\{| & & |alternatives/howdy.c| & |4|\\
# |11| & |\_{}\_{}printf("Howdy!\backslash{}n");| & & |alternatives/howdy.c| & |5| \\
# |12| & |\_{}\_{}return 0;| & & |alternatives/howdy.c| & |6| \\
# |13| & |\}| & & |alternatives/howdy.c| & |7| \\
#\end{tabular}
#
#The remainder of the code uses this hash to create the Komments++ document.
#
#Four subroutines implement this procedure: (XXX ARE THESE IN THE RIGHT ORDER? XXX)
#\begin{dictionary}
# \item{|infile|} This is the top-level subroutine. It searches for |\backslash{}input| commands, calls itself when one is found, and inserts the requested lines from the child file's hash into its parent file's hash.
# \item{|readfile|} This subroutine handles the actual file input and the line selection and formatting options.
# \item{|break|} This handles the hashing of the files into comments and code.
# \item{|modifyPaths|} This modifies any file paths encountered in command arguments so that they are relative to the root file's location.
#\end{dictionary}
#
# \function{The |infile| subroutine}
#
# The |infile| subroutine takes three arguments, a file name, the depth of the file tree, and a specification for which lines to read and the format to apply. It returns the hash described above composed from the given root file and any branch files included in the document with |\backslash{}input|. To carry this out, the routine first ensures that this call of |infile| does not violate the limitation that the file tree may be no deeper than |MAX_FILE_DEPTH|. Then it calls |readfile| to produce the first version of the file's hash. After checking to ensure that any |\backslash{}input| commands satisfy the syntactic restrciction that they occupy a line without other code or comments, the remainder of the procedure scans the comments of those |\backslash{}input| commands, calls itself to create the specified descendant file's hash, and inserts the results within the hash created from its argument file.
#
sub infile {
#
#The preliminary steps decompose the input array into its constituent parts, check to see whether this call violates the maximum file depth (defined above in Section \ref{processorControlVariables}), and calls |readfile| to construct the first version of the given source file's hash. So that a document can use the root files of other documents as descendants, we also strip any |\backslash{}documentclass| commands from the comments if |\${}depth| exceeds zero.
#
	my $lines    = pop @_;
	my $depth    = pop @_;
	my $filename = pop @_;
	
	if ( $depth > MAX_FILE_DEPTH ) {
		die "Maximum file depth exceeded.";
	}
	
	my %input = &readfile($filename,$lines);

	my $i;
	my $inputLength = @{ $input{comments} };
	if ($depth>0){
	    for ($i = 0; $i < $inputLength; $i++ ){
		$input{comments}[$i] =~ s/\\documentclass(\[[^\\]*?\])?($matchingBraces+)?//g;
	    }
	}
#This subroutine's remaining code accounts for the presence of |\backslash{}input| commands in the source file's comments. First, we check each line of the comments to ensure that it does \emph{not} contain an |\backslash{}input| command  preceeded or followed by non-whitespace text - denoted by |\backslash{S}| in the first regular expression below. If a line passes this test and its comments contain a valid |\backslash{}input| command, then we check to ensure that the line has no code.
	for ( $i = 0 ; $i < $inputLength ; $i++ ) {

	    #Check for the |\backslash{}input| command and some non-whitespace text either preceeding or following it in the comments.
	    if ( $input{comments}[$i] =~ m/(\S\s*(?<!\\)\\input(\[[^\\]*?\])?(??{$matchingBraces})| #Non white space possibly followed by whitespace followed by an unescaped |backslash{}input| command, or
					     (?<!\\)\\input(\[[^\\]*?\])?(??{$matchingBraces})\s*\S)/x #An unescaped input command possibly followed by whitespace followed by non white space.
	       ) {
		die "kpp error on line $input{lineNumbers}[$i] of file $filename\n\\input{} must appear on a line alone.\n";
	    }
	    #The comments are clean, but the line might contain code and an unescaped |\backslash{}input| command in the comments. Check for this possibility.	
	    elsif ($input{comments}[$i] =~ m/(^\s*(?<!\\)\\input(\[[^\\]*?\])?(??{$matchingBraces})\s*$)/ ) {
		if($input{code}[$i] =~m/\S/){
		    die "kpp error on line $input{lineNumbers}[$i] of file $filename\n\\input{} must appear on a line alone.\n";
		}
	    }
	}
#Now that we are sure the user has not misused |\backslash{}input|, we proceed through the file's comments one line at a time looking for it. If we do not find it on a given line, then we copy that line's code, comments, file name, and line numbers to the arrays |@newCode|, |@newComments|, |@newFileNames|, and |@newLineNumbers|. If we do find it, then we call |input| to populate |\%{}childHash| and append its contents to these arrays. 
	my @newComments; my @newCode; my @newFileNames; my @newLineNumbers;
	my %childHash;
#Other variables this loop requires store the information for the current line being examined and the options and arguments for the most recent |\backslash{}input| command encountered. With these declared the loop can proceed.
	my $thisComment; my $thisCode; my $thisFileName; my $thisLineNumber;
	my $inputArgument; my $inputOptions; 

	for ( $i = 0 ; $i < $inputLength ; $i++ ) {
	    $thisComment = $input{comments}[$i];
	    $thisCode    = $input{code}[$i];
	    $thisFileName = $input{fileNames}[$i];
	    $thisLineNumber = $input{lineNumbers}[$i];
#The following regular expression detects a |\backslash{}input| command surrounded by nothing but whitespace and captures its options and argument . If we find one, we modify its options and argument so that they can be passed to |input|, do so, and append the results to the |@new| arrays.
	    if ( $thisComment =~ m/^\s*(?<!\\)\\input(\[[^\\]*?\])?((??{$matchingBraces}))\s*$/ ) {
		$inputOptions = $1;
		$inputArgument = $2;
#If there are input options, we strip their enclosing brackets. Otherwise, we set the options to the default ``all''.
		if($inputOptions){
		    $inputOptions=~s/^\[//;
		    $inputOptions=~s/]$//;
		} else {
		    $inputOptions="all";
		}
#The regular expression above captures the argument's opening and closing braces. We strip these off using the simple utility subroutine |stripBraces| defined in Box \ref{stripBracesBox}.
		$inputArgument = &stripBraces($inputArgument);
		push @filesToBeZipped, $inputArgument;
#The call to |infile| uses the current |\${}depth| increased by one.
		%childHash = &infile($inputArgument, $depth + 1,$inputOptions);
#The |push| command appends the results in |\%{}childHash| to the |@new| arrays.
		push @newCode,        @{ $childHash{code}};
		push @newComments,    @{ $childHash{comments}};
		push @newFileNames,   @{ $childHash{fileNames}};
		push @newLineNumbers, @{ $childHash{lineNumbers}};
		}
#In the case without a |\backslash{}input| command on the current line, we simply copy its contents into the |@new| arrays.
	    else {
	    	if(!(length($thisCode)==1 && length($thisComment)==0)) {
				push @newCode,        $thisCode;
				push @newComments,    $thisComment;
				push @newFileNames,   $thisFileName;
				push @newLineNumbers, $thisLineNumber;
			}
	    }
	}
#This completes the loop over the input file's lines and the assembly of the |@new| arrays. Assembling the output hash from these and returning it to the calling routine complete this subroutine's tasks.
	my %output = (
	    code        => [@newCode],
	    comments    => [@newComments],
	    fileNames   => [@newFileNames],
	    lineNumbers => [@newLineNumbers]
	    );
	return %output;
}
#
#\begin{box}
#\caption{The |stripBraces| and |stripBrackets| subroutines\label{stripBracesBox}}
sub stripBraces{
    my $input=$_[0];
    $input=~s/^\{//;
    $input=~s/\}$//;
    return $input;
}

sub stripBrackets{
    my $input=$_[0];
    $input=~s/^\[//;
    $input=~s/]$//;
    return $input;
}

#\end{box}
#\function{The |readfile| subroutine}
#
# The subroutine that handles the actual reading of input files starts by loading the file indicated by its first argument into an array and moving any shebang it contains into the global variable |\${}shebang|. It then calls |break| to hash the file and |modifyFilePaths| to make any file paths in referenced in the input file's Komments++ commands relative to the location of the root file. Finally, it uses the contents of its second argument to determine the lines and content retained in its output.  It then replaces the XHTML control characters ``|\&|'', ``|<|'' and ``|>|'' in the code with their Unicode character entities. In the comments, only ``|<|'' and ``|>|'' get analogously replaced. (Just as in LaTeX, the ampersand is a Komments++ control character, so we leave it intact. Later processing removes it from the final output.) Windows carriage returns get cleaned from both comments and code. Finally, the output is assembled and returned. 
sub readfile {

    my $filename = $_[0];
    my $options = $_[1];
    my $absoluteFilename=File::Spec->catpath($parentVolume,$parentDirectory,$filename);
    open( DATA, $absoluteFilename ) or die "Failure to open file $absoluteFilename.\n";
    my @input = <DATA>;

    if($input[0]=~s/(^#!.*)//){
	$shebang=$1;
    }

    (my $volume, my $location, my $shortFilename)=File::Spec->splitpath($absoluteFilename);
    my %input = &break( @input, $shortFilename );
    my @modifiedComments = &modifyFilePaths( @{ $input{comments} }, $location );

    my @codeOutput=@{$input{code}};
    my @commentsOutput = @modifiedComments;
    my @fileNamesOutput = @{$input{fileNames}};
    my @lineNumbersOutput = @{$input{lineNumbers}};

    #If the given options select all comments, all code, only comments, or only code, modify the output accordingly.
    if ($options=~m/all comments/){
	@codeOutput="";
	@commentsOutput=@input;
    } elsif($options=~m/all code/){
	@codeOutput=@input;
	@commentsOutput="";
    }

    if ($options=~m/only comments/){
	@codeOutput="";
    } elsif ($options=~m/only code/){
	@commentsOutput="";
    }
    
    #Retrieve any line selection choices in the options and implement them.
    my $firstline;
    my $lastline;

    if ($options=~m/(\d+|(?:start))\.\.(\d+|(?:end))/){

	$firstline=$1;
	$lastline=$2;
    
	$firstline=~s/start/1/; 
	$firstline=$firstline-1; 

	my $endline=@input;
	$lastline=~s/end/$endline/;
	$lastline=$lastline-1;

    } else {

	$firstline = 0;
	$lastline = @input-1;

    }

    @codeOutput		=@codeOutput[$firstline..$lastline];
    @commentsOutput	=@commentsOutput[$firstline..$lastline];
    @fileNamesOutput    =@fileNamesOutput[$firstline..$lastline];
    @lineNumbersOutput  =@lineNumbersOutput[$firstline..$lastline];

    #Clean the comments and code as described above.
    foreach (@commentsOutput) {
	s/\r$//g;         #Windows carriage returns
	s/</\&lt;/g;      #Less than sign
	s/>/\&gt;/g;      #Greater than sign
    }

    foreach (@codeOutput) {
	s/\r$//g;        #Windows carriage returns
	s/&/\&amp;/g;    #Ampersand
	s/</\&lt;/g;     #Less than sign
	s/>/\&gt;/g;     #Greater than sign
	s/\\/&#x5c;/g;    #Backslashes. (This ensures that further processing cannot confuse backslashes in the code with actual Komments++ commands.)
    }

    #Assemble the output hash and return.
    my %output = (
	code        => [@codeOutput],
	comments    => [@commentsOutput],
	fileNames   => [@fileNamesOutput],
	lineNumbers => [@lineNumbersOutput]
    );

    return %output;

}
#\function{The |break| subroutine}
#The |break| subroutine handles the separation of the input files into comments and code. For this, we separate the possible syntaxes for comments into two classes:
#\begin{dictionary}
#\item{\emph{block comments}} These are comments that can extend across lines. These are constructed with an \emph{open comment token sequence} and a matching \emph{close comment token sequence}. For example, \textsc{C} opens block comments with ``|/*|'' and closes them with ``|*/|''. Some languages, such as Perl, have no block comment synax.\footnote{However, some programmers attempt to mimic the functionality of comment blocks in Perl with POD directives. Komments++ makes no attempt to account for this practice.}
#\item{\emph{inline comments}} These comments reside on a single line. An \emph{inline comment token sequence} opens one, and the newline character closes it. In \textsc{C}, the inline comment token sequence equals ``|//|''. Some languages have two inline comment token sequences, where one must follow a complete language statement and the other indicates that the current line's statement continues on the next line. In Matlab, these correspond to ``|\%{}|'' and ``|...|''.
#\end{dictionary}
#Although separating code from comments for a given language might seem straightforward, the code that does so must account for (at least) three difficulties.
#\begin{itemize}
#\item The |\backslash{}esc| command within a comment instructs Komments++ to treat the entire contents of its containing comment as working code.
#\item In many languages, the token sequence that begins a comment can appear within working code without denoting a comment. For example, a string in Matlab can contain `|\%|' and ``|...|''. Indeed Matlab employs ``|\%{}|'' within \textsc{C}-style format strings. The code must distinguish between such implicitly escaped token sequences and those that actually begin comments.
#\item A comment can contain a token sequence that starts a comment. For example, suppose that an inline comment in Matlab contains an elipsis, like, |\%{} Here, we list the cases for x, 1,2,...,N|. It would not be hard to mistake everything before the elipsis for code. Generally, we wish to break at the leftmost inline comment token sequence.
#\end{itemize}
# The algorithm we employ proceeds line-by-line through the source file. If the line is not part of an open block comment, then it tests its contents for inline comment and open comment token sequences. These tests employ language-specific regular expressions, which deal with the last two difficulties noted above. A line containing an inline comment gets split and the algorithm proceeds to the next line. A line without an inline comment gets tested for an open comment token sequence. If it contains one, the line is split at it and an indicator of an open comment block gets from |0| to |1|. Each line within a comment block has its entire contents assigned to comments and gets tested for close comment token sequences. When one is found the comment block gets closed. If at any point the ``|\backslash{}esc|'' command is encountered within a comment, its entire contents are placed into the code.\footnote{Matlab comments raise a problem for this general strategy: Their open and close comment sequences can be \emph{nested}. Since \textsc{C} comments cannot be nested, no language-independent algorithm can account for both languages. The curent code defers to \textsc{C}. Perhaps future versions of this program will have more flexibility in this dimension. This means that Matlab comments following the innermost nesting will be (incorrectly) interpreted as code.}
#
#The subroutine begins with identifying the source file's language from its extension. Each language has three regular expressions associated with it. Eponymous variables (created with the |qr/ /| operator) contain them.
#\begin{dictionary}
#\item{|\${}inlineComment|} This regex matches the language's inline comment token sequences, and it captures the line's code and comments (without the sequence) into |\${}1| and |\${}2|.
#\item{|\${}openComment|} This regex matches code followed by the language's open comment token sequence, and it captures the code and comments (without the sequence) into |\${}1| and |\${}2|. 
#\item{|\${}closeComment|} This regex matches the language's close comment token sequence. It captures nothing. The Komments++ syntactic restriction that nothing but white space can come between a close comment token sequence and the next new line means that nothing after the sequence needs to be captured.
#\end{dictionary}
#With the language determined and its regular expressions assigned, the algorithm described above proceeds to break the code line-by-line. Arrays listing each line number and the file name are also created, and the subroutine returns all four arrays in the |\%{}output| hash. 
sub break {

	my $fileName = pop @_;
	my @input     = @_;

	$fileName=~m/.*\.(.*)$/;
	my $extension=$1;

# The language-specific regular expressions account for the difficulty of comment token sequences within strings with two dynamic regular expressions that match paired unescaped quotation marks and apostrophes.
	my $matchingQuotationMarks = qr/(?<!\\)"(?:[^"]|\\")*(?<!\\)"/; #Recall that |(?: )| represents non-capturing parentheses.
	my $matchingApostrophes=qr/(?<!\\)'(?:[^']|\\')*(?<!\\)'/;

	my $inlineComment;
	my $openComment;
	my $closeComment;
#\paragraph{\textsc{C}}
	if ( $extension eq 'c' ) {    
#In \textsc{C}, |\${}openComment| matches any line containing  ``|/*|'' \emph{unless} it is in a string or the inline comment token sequence preceeds. An expression that matches any character but a slash either preceeded by another slash or followed by a star and and that matches \emph{all} characters between two matching right apostrophes and between two matching quotation marks implements this.
	    $openComment = qr/^( (?:(?:[^"'\/] | (?<!\/)\/(?!\*)?)|$matchingApostrophes|$matchingQuotationMarks)*) \/\* (.*\n)/x;
#The matching |\${}closeComment| simply matches the close comment token sequence.
	    $closeComment = '\*\/';
#\textsc{C}'s |\${}inlineComment| mimics its |\${}openComment|, with a regex that matches the inline comment token sequence (|\backslash{/}\backslash{/}|) replacing the analgous regex for open comment token sequence (|\backslash{/}\backslash{*}|).
	    $inlineComment = qr/^( (?:(?:[^"'\/] | (?<!\/)\/(?!\*)?)|$matchingApostrophes|$matchingQuotationMarks)*) \/\/ (.*\n)/x;
	}
#\paragraph{Matlab}
#The Matlab version of |inlineComment| allows for a ``|\%{}|'' in a string, which is of obvious importance given its use in formatted input and output. This regex is particularly complicated, because it must account for the two uses of the right apostrophe, as a string delimiter and as the transpose operator.
	elsif ( $extension eq 'm' ) {
#The first pair of capturing parentheses gets anchored to the string's start. It begins with a zero-width assertion that matches apostrophes used as transposition (they follow a standard right delimiter, a word, or the period), a sequence of up to two periods (three would start a line continuation comment) and any character but the apostrophe, the percentage sign, or the period.
	    $inlineComment = qr/^((?:   
			    (?:[])}\w.]'+|\.{1,2}(?!\.)|[^'%.])+
#To move past a string, we match everthing between two right apostrophes using |\${}matchingApostrophes|.\footnote{Matlab uses two apostrophes within strings to represent the apostrophe character itself. When faced with such a string, the instance of |\${}matchingApostrophes| within |\${}inlineComment| will simply match twice, once for each (apparently) matching pair.} This closes the regex's opening passive group. We append the zero-or-more qualifier to it, and then close the first pair of capturing parentheses.
					|$matchingApostrophes)*)
#The remainder of the regex is straightforward. We match the comment marker (either ``|\%{}|'' or ``|...|'') and then capture the comment's content including its terminal line feed.
				    (?:\.{3,}|%+) (.*\n)/x;
#The expressions for |openComment| and |closeComment| both allow arbitrary white space (but nothing else) on the line with the opening and closing tokens.
	    $openComment   = qr/^\s*%\{\s*$/;  
	    $closeComment  = qr/^\s*%\}\s*$/;
	}
#\paragraph{Stata}
#Stata program files have either the |do| or |ado| extensions. Stata uses \textsc{C}'s syntax for block comments. Inline comments can start with a * (on a line by itself) or with // or with ///. The last two options must be preceeded by one or more spaces. Strings can be enclosed in either single or standard quotation marks.
	elsif ( $extension =~m/^a?do$/ ) {
#The |$inlineComment| regular expression starts with capturing parentheses that contain a non-capturing group. This matches one or more of
#\begin{itemize}
# \item Any character that is not an apostrophe, quotation mark, or slash,
# \item A slash that neither preceeds nor follows another slash,
# \item Matching apostrophes or matching quotation marks.
#\end{itemize}
#Next comes a non-capturing group that matches the inline comment sequence, either a star separated from the string's beginning only by white space or a sequence of two or three slashes. Finally, capturing parentheses store the contents of any comment.
        	$inlineComment = qr/^( (?:(?:[^"'\/] | (?<!\/)\/(?!\*)?)|(?:$matchingApostrophes)|(?:$matchingQuotationMarks))*) (?:(?<=^)\s*\*|\s*\/{2,3}) (.*\n)/x;
#The |$openComment| regex is virtually identical to |$inlineComment| with the portion matching the comment sequence changed appropriately, and |$closeComment| is trivial.
		$openComment = qr/^( (?:(?:[^"'\/] | (?<!\/)\/(?!\*)?)|(?:$matchingApostrophes)|(?:$matchingQuotationMarks))*) \/\* (.*\n)/x;
		$closeComment = '\*\/';
	}
#\paragraph{TeX and LaTeX}
# The comment syntax for TeX and LaTeX presents no real challenges. All inline comments start with an unescaped ``|\%{}|''. There are no comment blocks, so we set |\${}openComment| and |\${}closeComment| to a regular expression that matches nothing.
	elsif ( $extension eq 'tex' ) {
		$inlineComment = qr/(.*?)(?:(?!=\\)%)(.*\n)/;
		$openComment  = qr/\/(?=a)(?!a)/;
		$closeComment = qr/\/(?=a)(?!a)/;
	}
#\paragraph{Fortran}
#Komments++ supports the free form input of the modern Fortran dialects, Fortran 90, 95, 2003, and 2008. These formats encompass the older fixed-form comment syntax in which either  ``|c|'' or ``|C|'' in the first position starts a comment line, so |\${}inlineComment| matches this syntax. It also accounts for the possible presence of the standard inline comment delimiter, ``|!|'', in quotes. Accounting for the exclamation point in strings continued across lines with the  ``|\&{}|'' is on our agenda. Fortran has no comment block syntax.
	elsif ( $extension =~ /[fF]{1}(90|95|03|08)/ ) {
		#$inlineComment = qr/((?:[^!"']|$matchingApostrophes|$matchingQuotationMarks)?)(?:!|(?<=^)[Cc]{1})(.*\n)/;
		$inlineComment = qr/((?:[^!"']|$matchingApostrophes|$matchingQuotationMarks)?)(?:!)(.*\n)/;
		$openComment  = qr/\/(?=a)(?!a)/; 
		$closeComment = qr/\/(?=a)(?!a)/; 
	}
#\paragraph{Perl}
#Perl has no comment block syntax, and the hash character, ``|\#{}|'', starts its inline comments. The hash character can also appear within a string (for example, as Unicode character reference) or within a regular expression. Since the permissible syntax for enclosing regular expressions is so flexible, writing a regular expression to detect a hash within a regular expression is challenging. We defer a complete solution for future work. Here, we simply allow the hash to be contained within the |qr| operator (delimited by the conventional but not required forward slash) \emph{on a single line.} This allows this program itself to be compiled with Komments++.
	elsif ( $extension =~ /pl(?:x)?/) { 
	    my $qrOperator = qr,(?:qr/[^/]*/),;
	    $inlineComment = qr/^($qrOperator|(?:(?<!qr\/)[^#"']|$matchingApostrophes|$matchingQuotationMarks)*)(?:#)(.*\n)/;
	    $openComment  = qr/\/(?=a)(?!a)/;
	    $closeComment =  qr/\/(?=a)(?!a)/;
	}
#\paragraph{Javascript}
# Comment syntax for Javascript is identical to that for \textsc{C}.
	elsif ($extension eq 'js') {#Javascript
	    $openComment = qr/^( (?:(?:[^"'\/] | (?<!\/)\/(?!\*)?)|$matchingApostrophes|$matchingQuotationMarks)*) \/\* (.*\n)/x;
	    $closeComment = '\*\/';
	    $inlineComment = qr/^( (?:(?:[^"'\/] | (?<!\/)\/(?!\*)?)|$matchingApostrophes|:$matchingQuotationMarks)*) \/\/ (.*\n)/x;
	}
#\paragraph{CSS}
# Since cascading style sheets do not include arbitrary string variables, we write |\${}openComment| and |\${}closeComment| to grab the line's first instances of the relevant token sequences. CSS has no inline comment syntax.
	elsif ($extension eq 'css' ){
	    $inlineComment = qr/\/(?=a)(?!a)/;
 	    $openComment   = '^(.*)\/\*(.*)';
	    $closeComment  = '\*\/';
	}
#\paragraph{Komments++}
#The Komments++ specific file format contains ``all comments'' by default. To implement this, we make the |$inlineComment| match any character anchored to the start of a line.
	elsif ($extension eq 'kpp' ){
	    $inlineComment=qr/(\A)(.*)/s;
	    $openComment=qr/\/(?=a)(?!a)/;
	    $closeComment=qr/\/(?=a)(?!a)/;
	}
#\paragraph{Everything else}
#All other file types are treated as all code, so the three regular expressions match nothing.
	else {
	    $inlineComment=qr/\/(?=a)(?!a)/;
	    $openComment=qr/\/(?=a)(?!a)/;
	    $closeComment=qr/\/(?=a)(?!a)/;
	}

#This completes the specification of |break|'s regular expressions. Before proceeding with the actual parsing, we ensure that nothing follows closing comment blocks on any of the input lines.
	my $inputLength = @input;
	my $i;
	for ( $i = 0 ; $i < $inputLength ; $i++ ) {
		if ( $input[$i] =~ /$closeComment\s*?\S/ ) {    
			die "kpp syntax error: Nothing but white space may follow the end of a block comment on the same line.\n";
		}
	}
#With the syntax rule satisfied, we move on to the actual breaking. The variable |\${}thisLine| stores the line under consideration, and |\${}thisCode| and |\${}thisComment| store its code and comments. The comment block indicator discussed above is |\${}inCommentBlock|, while |\${}escapeThisCommentBlock| stores an indicator for the current comment block being escaped. This gets used to properly implement escaping multi-line comments. The results of the parsing get stored in |@code|, |@comments|, |@fileNames|, and |@fileNumbers| before being assembled into |\%{}output|.
	my $inCommentBlock         = 0;
	my $escapeThisCommentBlock = 0;
	my $thisLine; my $thisCode; my $thisComment;
	my @code; my @comments;	my @fileNames;my @lineNumbers;

	for ( $i = 0 ; $i < $inputLength ; $i++ ) {

		$thisLine = $input[$i];

		if ( $inCommentBlock == 0 ) {
#If |\${}thisLine| does not continue an open comment block, then it can fall into one of three cases:
#\begin{itemize}
#\item The line contains an inline comment.
#\item The line opens a comment block.
#\item The line contains no comments.
#\end{itemize}

			if ( $thisLine =~ /$openComment/ ) {
# We treat a line with an open comment block sequence identically to a line with an inline comment sequence if the comment block gets closed on the same line. Otherwise, we  increment |\${}inCommentBlock| and look ahead to determine whether or not the comment block should be escaped. If not, we separate this line into comments and code, and proceed to the next line. If so, we note the fact in |\${}escapeThisCommentBlock| and put all of this line into |@code|.
				$thisCode       = $1;
				$thisComment    = $2;
				if ( $thisComment =~ /$closeComment/ ) {
					if ( $thisComment =~ m/(?<!\\)\\esc/ ) {
					        # \esc Remove the escape command so long as it is not escaped itself, as in \\esc.
						$thisLine =~ s/(?<!\\)\\esc// ; 
						$code[$i]     = $thisLine;
						$comments[$i] = "";
					}
					else {                           
						$thisComment =~ s/$closeComment//;
						$code[$i]     = $thisCode;
						$comments[$i] = $thisComment;
					}
				}
				else {
				    $inCommentBlock = 1;
					
				        #Check this line for the |\backslash{}esc| command.
					if ( $thisComment =~ s/(?<!\\)\\esc//g ) {
						$escapeThisCommentBlock = 1;
					}

					#Check the remaining lines in this comment block, stripping out |\backslash{}esc| commands as we go along.
					my $j = $i + 1;
					until ( $input[$j] =~ /$closeComment/ ) {
						if ( $input[$j] =~ s/(?<!\\)\\esc//g ) {
							$escapeThisCommentBlock = 1;
						}
						$j++;
					}
				        #We have found the close comment token sequence. Check this final line as well.
					if ( $input[$j] =~ s/(?<!\\)\\esc//g ) {
						$escapeThisCommentBlock = 1;
					}

					#Split this line as required by |\${}escapeThisCommentBlock|.
					if ( $escapeThisCommentBlock == 1 ) {
						$code[$i]     = $thisLine;
						$comments[$i] = "";
					}
					else {
						$code[$i]     = $thisCode;
						$comments[$i] = $thisComment;
					}
				}
			}
			elsif ( $thisLine =~ /$inlineComment/) {
#In the first case, the line gets split between comments and code unless the comment contains an unescaped |\backslash{}esc| command, in which case the command itself is ripped from the line and the result is assigned to the code.\footnote{The regular expression that does this operates directly on |\${}thisLine|, so there might be some danger of ripping the command sequence from the code. Addressing this shortcoming is on our agenda.}

				$thisCode    = $1;
				$thisComment = $2;
								
				if ( $thisComment =~ m/(?<!\\)\\esc/ ) {               
					$thisLine=~s/(?<!\\)\\esc//;
					$code[$i]     = $thisLine;
					$comments[$i] = "";
				}
				else {
					$code[$i]     = $thisCode;
					$comments[$i] = $thisComment;
				}
			}
			else {
#In the case where the line has no comments, we assign everything to code.
			    $code[$i] = $thisLine;
			    $comments[$i] = "";
			}
		}
		else {
#That covers all three cases for lines that do not continue an open comment block. Lines that are part of a current comment block but are escaped get assigned to code.  Those that are not escaped get assigned to comments. Either way, we check to see if the line contains the close comment block sequence and reset |\${}inCommentBlock| appropriately.
			if ( $escapeThisCommentBlock == 1 ) {
				$code[$i]     = $thisLine;
				$comments[$i] = "";
				#Since this comment block is escaped, we need to reset |\${}escapeThisCommentBlock| if this is block's final line.
				if ( $thisLine =~ /$closeComment/ ) {   
					$inCommentBlock         = 0;
					$escapeThisCommentBlock = 0;
				}
			}
			else {                                      
			        #We wish to remove the close comment block sequence, so we use the |s///| operator 
			        #to test for its presence and to remove it from |$thisLine| simultaneously.
				if ( $thisLine =~ s/$closeComment// ) {
					$inCommentBlock = 0;           
				}

				# Replace line breaks in comments by a [whitespace][linebreak], because otherwise HTML
				# will concatenate words across the line break (at least within a itemize environment)
				$thisLine =~ s/\n/\ \n/g;
				
				$comments[$i] = $thisLine;
				$code[$i]     = "";
			}
		}
#The processing of line |\${}i| is complete. Before proceeding to the loop's next iteration, we write the current file name and line number to |@fileNames| and |@lineNumbers|.
		$fileNames[$i]=$fileName;
		$lineNumbers[$i]=$i+1;

	}
#The loop over the file's lines is complete. The subroutine's final commands assemble  |@code|, |@comments|, |@fileNames|, and |@lineNumbers| into |\%{}output| and return it.	
	my %output = (
		code     => [@code],
		comments => [@comments],
		fileNames => [@fileNames],
		lineNumbers => [@lineNumbers]
	);
	return %output;
}
#\function{The |modifyFilePaths| subroutine}
#File paths can arise in the arguments of |\backslash{}input| or |\backslash{}image|. If a path is absolute, we wish to leave it alone. Otherwise, we use the |rel2abs| function from |File::Spec| to make the path relative to the root input file's location.
sub modifyFilePaths {
	my $location = pop @_;
 	my @comments = @_;
#This subroutine uses two regular expression variables. The first simply lists the commands that can contain potentially problematic relative file paths in their arguments.
	my $fileCommands=qr/(image)/;
#The second variable matches the start of absolute paths. This allows for standard Windows syntax, three common url syntaxes, and the top of the standard Unix directory tree.
	my $absolutePathStart = qr/^([A-Z]:\\ | http:\/\/ | ftp:\/\/ | file:\/\/ | \/)/xi;
#The subroutine loops over each line in |@comments| searching for file commands. When it finds one, it examines its argument to see if its path is relative. If so, it invokes |rel2abs| and replaces the original relative path with its absolute counterpart. In the search for file commands, we use |\${}thisCommentTail| to store the portion of the line not yet examined, while |\${}thisCommentTrunk| stores the procesed portion of the line. (Imagine that the line is an elephant facing left.)
	my $length = @comments;
	my $i;
	my $thisCommentTail;
	my $thisCommentTrunk;
	my $fileCommand;
	my $fileCommandOptions;
	my $fileCommandArgument;
	my $absolutepath;
	my $relativepath;

	for ( $i = 0 ; $i < $length ; $i++ ) {

		$thisCommentTail  = $comments[$i];
		$thisCommentTrunk = "";
		#The next regex captures a file command, its options, and its argument.
		while ( $thisCommentTail =~ /((?<!\\)\\(??{$fileCommands}))((??{$matchingBrackets}))?((??{$matchingBraces}))/ ) {
			$fileCommand         = $1;
			$fileCommandOptions  = $2;
			$fileCommandArgument = $3;
			$thisCommentTail     = $'; 
			$thisCommentTrunk    = $thisCommentTrunk . $`; #'\esc{}
			
			$fileCommandArgument =~ m/\{(.*)\}/;
			my $fileName = $1;
			if ($fileName =~ /$absolutePathStart/){
			    $absolutepath = $fileName;
			}
			else {
			    $absolutepath = File::Spec->rel2abs( $fileName , $location ) ; #Put the given file name into an absolute path.
                            $relativepath = File::Spec->abs2rel( $absolutepath, $parentDirectory); #Make this relative to the root file's parent directory.
			}
			$thisCommentTrunk = $thisCommentTrunk . $fileCommand . $fileCommandOptions . "{" . $relativepath . "}";
		}
                #The loop ends when file-command matching regex does not match |$thisCommentTail|. In this case, assemble the comment string and move on to the next line.
		$comments[$i] = $thisCommentTrunk . $thisCommentTail;
	}
#The processing of |@comments| is complete, so we are ready to return it as output.
	return @comments;
}
#\subsection{The Document's Header}
#With the input files loaded, the primary processor proceeds to create the document's xHTML header. This contains
#\begin{itemize}
#\item Boilerplate \textsc{HTML} with the |DOCTYPE|, XML information, and the document's character encoding,
#\item The document's |<title>| tag, which places the document's name in the browser's title bar.
#\item Cascading Style Sheet rules for formatting the document, and
#\item Javascript code which provides additional document formatting as well as document interactivity features.
#\end{itemize}
#Two commands in the input files determine the header's contents, |\backslash{}head| and |\backslash{}documentclass|. The |\backslash{}head| command takes a single text string as its only input, and Komments++ fills the |<title>| tag with its contents. Since this undergoes no processing, its contents should be simple Unicode text. 
#
#The |\backslash{}documentclass| command determines the header's included CSS and Javascript code. Its argument determines the document's \emph{class}. Each class has a collection of CSS and Javascript files contained in an eponymous subdirectory of the |documentClasses| directory of the Komments++ installation. The commands' options select which portions of the CSS files to include.\footnote{We plan to expand the use of options to selectively include Javascript.} 
#
#The |xhtmlHeader| subroutine takes the array of comments created by |inflile| as input and returns an array containing the header's lines, |@xhtmlHeader|.
sub xhtmlHeader {

#We start with the boilerplate.
	my @xhtmlHeader;
	push @xhtmlHeader, '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"';
	push @xhtmlHeader, "\n";
	push @xhtmlHeader, '"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">';
	push @xhtmlHeader, "\n";
	push @xhtmlHeader, "\n<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">\n";
	push @xhtmlHeader, "<head>\n\t";
	push @xhtmlHeader, '<meta http-equiv="Content-Type" content="text/html;charset=utf-8" />';
	push @xhtmlHeader, "\n";
	push @xhtmlHeader, '<script type="text/x-mathjax-config">';
	push @xhtmlHeader, "\n";
	push @xhtmlHeader, "MathJax.Hub.Config({ tex2jax: {inlineMath: [['(StartMathJax)','(StopMathJax)']]}});";
	push @xhtmlHeader, "\n";
	push @xhtmlHeader, "MathJax.Hub.Config({ tex2jax: {displayMath:[['(MathJaxStart)','(MathJaxStop)']]}});";
	push @xhtmlHeader, "\n";
	push @xhtmlHeader, "MathJax.Hub.Config({ tex2jax: {processEnvironments: false}});";
	push @xhtmlHeader, "\n";
	push @xhtmlHeader, 'MathJax.Hub.Config({ tex2jax: {ignoreClass: "workingCodeLine|displaycode|code"}});';
	push @xhtmlHeader, "\n";
	push @xhtmlHeader, 'MathJax.Hub.Config({ tex2jax: {processClass: "inlineComment"}});';
	push @xhtmlHeader, "\n";
        push @xhtmlHeader, "</script>";
	push @xhtmlHeader,'<script type="text/javascript" src="https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML"></script>';
	push @xhtmlHeader, "\n";

#Finding the |\backslash{}head| command and placing its contents in the |<title>| tag is the next task at hand. For this, we cycle through the lines of |@input|. Upon finding ``|\backslash{}head|,'' the program uses the |last| command to exit the loop. If the input contains no |\backslash{}head| command, then the program places the filename into the |<title>| tag.
	my @input       = @_;
	my $inputLength = @input;
	my $thisLine; my $runningHead;
	for ( my $i = 0 ; $i < $inputLength ; $i++ ) {
	    $thisLine = $input[$i];
 	    if ( $thisLine =~ /(?<!\\)\\head((??{$matchingBraces}))/ ) {
		$runningHead = &stripBraces($1);
		last;
	    }
	}
	if($runningHead){
		push @xhtmlHeader, "\t<title>" . $runningHead . "</title>\n";
	} else {
		push @xhtmlHeader, "\t<title>".$fileName."</title>\n";
	}
#The search for the |\backslash{}documentclass| command proceeds similarly. Each line is checked for the command with options and then without options. If the command has options, they should come as a comma-separated list. We use the |csl2array| subroutine defined below to turn these into an array. If no |\backslash{}documentclass| command is encountered, the program halts with an error. If the file contains multiple |\backslash{}documentclass| commands, then the first one encountered is used. This allows stand-alone documents to serve double duty as subdocuments of larger projects.
	my $documentclass; my @documentclassOptions;
	for ( my $i = 0 ; $i < $inputLength ; $i++ ) {
	    $thisLine = $input[$i];
            #The next line's regex matches an unescaped |\backslash{}documentclass| command with options.
	    if ( $thisLine =~ /(?<!\\)\\documentclass\[([0-9a-zA-Z ,]+?)\]\{([a-zA-Z]+?)\}/ ) {
		@documentclassOptions = &csl2array($1);
		$documentclass        = $2;
		last;
	    }
	    #The next line's regex matches an unescaped |\backslash{}documentclass| command without options.
	    elsif ( $thisLine =~ /(?<!\\)\\documentclass\{([0-9a-zA-Z]+?)\}/ ) {
		$documentclass = $1;
		last;
	    }
	}
	unless ($documentclass) {
		die "No \\documentclass command.";
	}
#With the document's class determined, we retrieve its CSS and Javascript files. As noted above, these can be found within the |documentClasses/\emph{document class name}| directory below the location of the Komments++ executable file. To retrieve this, we use the __FILE__ token and the |rel2abs| Perl stores the full path of the file being executed in |\${}0|, and we take everything before the final directory separator as the executable file's location. We use |opendir| and |readdir| to create an array of the file names in the class's directory. 

	my $kppLocation=File::Spec->rel2abs(__FILE__);
	$kppLocation =~ m/^(.*)[\/\\]/ || die "Could not parse location of kpp executable.";
	my $documentClassDirectory=$1 . "/documentClasses/" . $documentclass;
	opendir(my $documentClassDirectoryPointer, $documentClassDirectory) || die "Cannot open document class directory $documentClassDirectory.";
	my @documentClassDirectoryListing=readdir($documentClassDirectoryPointer);
#Each file with the |.css| extension gets read by |getCSS|, processed as dictated by the options in |@documentclassOptions|, and appended to |@xhtmlHeader|. For Javascript files, |getJS| handles the reading and processing. The document class's options have no impact on the Javascript files. This is not a necessary part of the program design and might be changed in a future release.	
	my @css; my @js;
	foreach (@documentClassDirectoryListing){
	    if ($_=~/\.css$/){
		@css=&getCSS(@documentclassOptions,$documentClassDirectory."/".$_);
		push @xhtmlHeader, @css;
	    } elsif ($_=~/\.js$/){
		@js=&getJS($documentClassDirectory."/".$_);
		push @xhtmlHeader, @js;
	    }
	}
#The final task for the creation of the header is the closing of the |<head>| tag.
	push @xhtmlHeader, "\n</head>\n";
	return @xhtmlHeader;
}
#\function{The |csl2array| subroutine}
#The subroutine used in |xhtmlHeader| to break the comma-separated list of options into an array uses the simplest regular expression imaginable and the standard match variables to break the contents of its input string.
sub csl2array {
	my $input = $_[0];
	my @output;
	while ( $input =~ /,/ ) {
	    push @output, $`;
	    $input = $';
	}
	push @output, $input;
	return @output;
}
#\function{The |getJS| subroutine}
# Retrieval of a Javascript file merely requires the program to open the file, read it into an array, and return it.
sub getJS {
    my $javascriptFileName = $_[0];
    open( DATA, "$javascriptFileName" )
	  or die "Can't open document class file: $javascriptFileName!\n";
    my @input = <DATA>;
    return @input;
}
#\function{The |getCSS| subroutine}
#The subroutine that handles retrieving CSS files is somewhat more complicated, because it uses the document class's options to selectively include parts of the CSS files. These optional portions of the CSS files are delimited with |START OPTION:\textit{option name}| and |STOP OPTION| on comment lines by themselves. For example, consider the CSS style rules that implement the |hiddencode| environment in the |article| document class.
#\input[85..89]{documentClasses/article/common.css}
#The first rule removes all rows in a |workingCode| table from the display. The second and third rules turn back on the first and last rows. The third rule says that the rows in a |workingCode| table over which the reader has hovered the mouse pointer should inherit its |display| property from its previous sibling. It is this rule that makes the code appear when desired. The final rule places a vertical elipsis between the first and last lines of code to indicate that code is being hidden. 
#
#The option |showhiddencode| overrides this behavior by adding the following rule to the CSS style sheet.
#\input[184..188,all code]{documentClasses/article/common.css}
#If this rule were always applied to the document, then it would override the fourth rule above and ``hidden code'' would never be hidden.  By default, |getCSS| removes all lines between option delimiters from its output \emph{unless the document options specify its inclusion.} That way, hidden code remains hidden unless the user specifies the |showhiddencode| option.
#
#The actual process of selectively retaining options is straightforward. After importing the file, the subroutine examines it line-by-line for option delimiters. If it finds an opening option delimiter, it checks the given name against the list of options to be retained. Unless the name is on the list, it discards the contents of all lines preceeding the next closing option delimiter. The code also incorporates a check for nested option delimiters, which are illegal.
sub getCSS {
    my $documentclassFile = pop @_;
    my @specifiedOptions  = @_;
    my @css;

    #A match with |\${}STARTOPTION| retains the option name in |$1|.
    my $STARTOPTION = '\/\*\s+?START OPTION:\s+?([0-9a-zA-Z]+?)\s+?\*\/';
    my $STOPOPTION  = '\/\*\s+?STOP OPTION\s+?\*\/';

    my @input;
    open( DATA, "$documentclassFile" )
	or die "Cannot open document class file: $documentclassFile!\n";
    @input = <DATA>;
    my $length = @input;

    my $processingOption=0; 
    my $keepThisOption=0;
    for (my $i = 0 ; $i < $length ; $i++ ) {
	my $thisLine = $input[$i];
	if ( $thisLine =~ /$STARTOPTION/ ) {
	    if($processingOption){
		die "Nested documentclass option specifications in $documentclassFile!\n";
	    } else {
		$processingOption=1;
	        my $thisOption=$1;
		foreach(@specifiedOptions) {
		    if($_ eq $thisOption){
			$keepThisOption=1;
		    }
		}
	    }
	}
	if($thisLine =~/$STOPOPTION/){
	    if($processingOption){
		$processingOption=0;
		$keepThisOption=0;
	    } else {
		die "Option declaration syntax violation in $documentclassFile!\n";
	    }
	}
	#Unless we are processing an unspecified option, we push the line into the output.
	unless ($processingOption==1 && $keepThisOption==0) {
	    push @css, $thisLine;
	}
    }
    return @css;
}
#\subsection{The Document Body}
#
# The top-level subroutine for creating the document's body is |bodyPages|. Recall from the start of this section that this takes the hash generated by the |infile| subroutine as its input. The processing of this into its output, an array containing the xHTML code for the document's main content, proceeds in three primary steps.
#\begin{itemize}
#\item \emph{Weaving} combines the code and comments into a single array. Within this, the code is placed into xHTML tables along with its source file names and line numbers. Comments are placed within paragraph tags.
#\item \emph{Processing} replaces the Komments++ environments and commands within the woven input's paragraph tags with the appropriate xHTML code. 
#\item The processing step detects cross references to bibliographic information and internal document elements and generates anchors linking to them. However, these anchors do not contain the correct descriptive text. \emph{Cross Reference Completion} creats this text using cross referencing information generated during the processing step.
#\end{itemize}
#Weaving and processing are both sufficiently involved to merit their own subroutines. Cross reference completion is handled within |bodyPages| itself.
#\function{The |bodyPages| subroutine}
sub bodyPages {

    my %input = @_;
    my @output;

#The output begins with the opening |<body>| tag (which contains \emph{all} of the document's content) and the opening tag of the |div| that will encompass the document body. We then weave and process the input and append the result to |@output|.
	push @output, "<body>\n<div id=\"bodyPages\">\n";
        my @cloth=&weave(%input);
        push @output, &process(@cloth);
#Within |process| each sectioning command opens a |div| tag, and subsequent sectioning commands close any open |div|'s created by previous lower-level sectioning commands. This leaves at least one and possibly more |div| tags open in the output of |process|. The subroutine |resetCounters| uses the global variables in |%counters| to determine the number of open tags and close them. As its name suggests, it also resets the values in |%counters| to zero. (Perhaps this should be put into |process|.)
        push @output, &resetCounters;
#A closing |div| tag completes the first draft of the |bodyPages| subdivision. Cross reference completion is required before we have the final copy.
	push @output, "</div>\n"; 
#Completion of bibliographic citations is the next step. The |process| subroutine leaves citations as anchors with the class |"unfinished cite"| and with the target itself as the anchor's content. We use each such citation's target to retrieve its matching label text from the |%citelabels| hash. 
	my $outputLength = @output;
	my $i;
	for ( $i = 0 ; $i < $outputLength ; $i++ ) {    
		while ( $output[$i] =~ m/\<a href="#([^"]*)" class="unfinished cite"\>\1/ ) {    
			my $label = $1;
                        if(exists $citelabels{$label}){
			     $output[$i] =~ s/class="unfinished cite"\>$label/class="cite"\>$citelabels{$label}/g; 
                        } else {
                             $output[$i] =~ s/class="unfinished cite"\>$label/class="cite"\>$label(\?)/g;
                        }
		}
	}
#The final step is the completion of references to document elements. The code parallels that which handles bibliographic citations. The single difference is that it replaces |"unfinished ref"| with one of reference classes, |"ref"| and |"appendixref"|, which allow document class code to style references to content of an appendix differently. To detect whether or not a reference's target is in an appendix, it uses the appropriate element of |%refappstat|.
	for ( $i = 0 ; $i < $outputLength ; $i++ ) {                           
	    while ( $output[$i] =~ m/\<a href="#([^"]*)" class="unfinished ref"\>\1/ ) {     
		my $label = $1;
		my $temp = $&;
		if ($refappstat{$label} == 0 & exists $reflabels{$label}) {
		    $output[$i] =~ s/\<a href="#$label" class="unfinished ref"\>$label/\<a href="#$label" class="ref"\>$reflabels{$label}/g;
		} elsif ($refappstat{$label} == 1 & exists $reflabels{$label}) {
		    $output[$i] =~ s/\<a href="#$label" class="unfinished ref"\>$label/\<a href="#$label" class="appendixref"\>$reflabels{$label}/g;
                } elsif ($refappstat{$label} == 0 ) {
		    $output[$i] =~ s/\<a href="#$label" class="unfinished ref"\>$label/\<a href="#$label" class="ref"\>$label(\?)/g;
                } else {
                    $output[$i] =~ s/\<a href="#$label" class="unfinished ref"\>$label/\<a href="#$label" class="appendixref"\>$label(\?)/g;
                }
            }
	}
#This completes the creation of the |bodyPages| division.
	return @output;
}
#\function{The |weave| subroutine}
#
#To illustrate the operation of |weave|, consider the example of |hello.c| and |howdy.c| introducted in Section \ref{fileInput}. Taking the hash produced by |infile| as its input, |weave| returns the following array
#\begin{tabular}{rl}
#Element & Content \\
#0 & |\backslash{}documentclass\{none\}|\\
#1 & |The file begins with a preprocessor directive.|\\
#2 & |<table class="workingCode">|\\
#3 & |<tr class="shaded"><td class="fileName">hello.c</td><td class="lineNumber">3</td><td class="workingCodeLine">#include\&{}lt;stdio.h\&{}gt;</td></tr>|\\
#4 & |</table>|\\
#5 & |After this comes the main function.|\\
#6 & |<table class="workingCode">|\\
#7 & |<tr class="unshaded"><td class="fileName">hello.c</td><td class="lineNumber">5</td><td class="workingCodeLine">int main void\{ <span class=unprocessedInlineComment>Takes no inputs and returns an integer.</span></td></tr>|\\
#8 & |<tr class="shaded"><td class="fileName">hello.c</td><td class="lineNumber">6</td><td class="workingCodeLine">\_\_{}printf("Hello World!\backslash{}n");</td></tr>|\\
#9 & |<tr class="shaded"><td class="fileName">hello.c></td><td class="lineNumber">7</td><td class="workingCodeLine>\_\_{}return(0);</td></tr>|\\
#10 & |<tr class="unshaded"><td class="fileName">hello.c</td><td class="lineNumber">8</td><td class="workingCodeLine>\}</td></tr>|\\
#11 & |</table>|\\
#12 & |An alternative version of this program|\\
#13 & |that completes the same greeting task is below.|\\
#14 & |<table class="workingCode">|\\
#15 & |<tr class="unshaded"><td class="fileName">alternatives/howdy.c</td><td class="lineNumber">4</td><td class="workingCodeLine">int main void\{</td></tr>|\\
#16 & |<tr class="unshaded"><td class="fileName">alternatives/howdy.c</td><td class="lineNumber">5</td><td class="workingCodeLine">\_\_{}printf("Howdy!\backslash{}n");</td></tr>|\\
#17 & |<tr class="shaded"><td class="fileName">alternatives/howdy.c</td><td class="lineNumber">6</td><td class="workingCodeLine">\_\_{}return 0;</td></tr>|\\
#18 & |<tr class="shaded"><td class="fileName">alternatives/howdy.c</td><td class="lineNumber">7</td><td class="workingCodeLine">\}</td></tr>|\\
#19 & |</table>| \\
#\end{tabular}
#This example illustrates several principles. First, |weave| passes lines containing only comments into its output unchanged. Second, each line containing code gets placed into a table of the class |"workingCode"|. Each line has the class |"shaded"| or |"unshaded"|. This assignment depends only on the line number in the source file. Each row contains three columns, with classes |"fileName"|, |"lineNumber"| and |"workingCodeLine"|. Finally, any inline comment gets placed within a |span| following the actual code with class |"unprocessedInlineComment"|. The |process| subroutine will replace this ``dummy class'' reference after operating on the span's contents.
#
#The weaving algorithm proceeds line-by-line through the input. It relies on one key variable, |\${}currentCommentBlock|, which gets initialized to contain a trivial white space character. If the current line contains only comments, then its contents get appended to |\${}currentCommentBlock|. If instead the current line contains working code and |\${}currentCommentBlock| is non-empty, then the algorithm closes any open table of working code, appends |\${}currentCommentBlock| to the output, resets |\${}currentCommentBlock| to white space, opens a new table of working code, and creates a row for this line's code. Finally, if the current line contains code and |\${}currentCommentBlock| is empty, then the algorithm produces a table row containing the line's code and any inline comment.
#
#The subroutine itself begins with input processing and error checking.
sub weave {
    
    my %input = @_;
    my @output;

    my @comments = @{ $input{comments} };
    my @code     = @{ $input{code} };
    my @fileNames = @{ $input{fileNames}};
    my @lineNumbers = @{ $input{lineNumbers}};

    my $commentsLength = @{ $input{comments} }; 
    my $codeLength     = @{ $input{code} };

    unless ( $commentsLength == $codeLength ) {    #If this error arises, it is not the user's fault!
	die "Internal kpp error in weave subroutine: Arrays for comments and code must have the same number of lines.\n";
    }

#To determine whether or not we need to close a table of working code when appending |\${}currentCommentBlock| to the output, we use |\${}encounteredWorkingCode| to indicate whether or not the algorithm has yet encountered code. The variable |\${}barClass| contains the current line's bar-paper class, |"shaded"| or |"unshaded"|.
    my $encounteredWorkingCode = 0;
    my $currentCommmentBlock = "\n";
    my $barClass;

    for ( my $i = 0 ; $i < $commentsLength ; $i++ ) {         # Loop over the input lines.
#If the original source file were printed line-by-line, the shading on the paper would change every |BARLINES| lines. We wish to format the working code as if this hypothetical printed copy had been cut and pasted into the document. To determine whether an original line should be shaded or not, we divide its zero offset line number by |BARLINES| and round it down. If the resulting number has a remainder after being divided by 2, then we make it shaded. Otherwise we leave it unshaded.    
    	if(int(($lineNumbers[$i]-1)/BARLINES) % 2){
    		$barClass="shaded";
    	} else {
    		$barClass="unshaded";
    	}
#The first test of the line determines whether or not the algorithm appends |\${}currentCommentBlock| to the output. If so, |$encounteredWorkingCode| is examined to see whether or not there is a table of working code to be closed. In either case, a new table of working code gets opened and |\${}currentCommentBlock| gets set to an empty string.
	    if ( $code[$i] && $currentCommmentBlock ) {
		    if ( !$encounteredWorkingCode) {
			    push @output, "$currentCommmentBlock\n<table class=\"workingCode\">\n";
			    $encounteredWorkingCode= 1;
		    }
		    else {
			    push @output, "</table>\n$currentCommmentBlock\n<table class=\"workingCode\">\n";
		    }
		    $currentCommmentBlock = "";
	    }
#The remainder of this line's processing depends on whether the line contains only comments, only code, or both comments and code. In the last case, we use the |chomp| operator to eliminate newline characters from the comments and code so that later processing can count on an inline comment's span residing on the same physical line as its working code.
	    if ( $comments[$i] && !$code[$i]) {
		    $currentCommmentBlock = "$currentCommmentBlock" . "$comments[$i]";
	    }
	    elsif ( $code[$i] && !$comments[$i]) {
		    push @output, "<tr class=\"$barClass\"><td class=\"fileName\">$fileNames[$i]</td><td class=\"lineNumber\">$lineNumbers[$i]</td><td class=\"workingCodeLine\">$code[$i]</td></tr>\n";
	    }
	    elsif ( $comments[$i] && $code[$i] ) {
		    chomp( $code[$i] );
		    chomp( $comments[$i] );
		    push @output, "<tr class=\"$barClass\"><td class=\"fileName\">$fileNames[$i]</td><td class=\"lineNumber\">$lineNumbers[$i]</td><td class=\"workingCodeLine\">$code[$i]<span class=\"unprocessedInlineComment\">$comments[$i]</span></td></tr>\n";    
	    }
	    else { #If both comments and code are empty, there is nothing to be done.
	    }
    }
#This completes the loop over the input lines. If the final line contributes to a current comment block and has no code, then the loop finished with |$currentCommmentBlock| nonempty. In this case, we close the final table of working code (if there was one) and push it out to the HTML file. Otherwise, we just close any open table of working code. The output is then ready to be returned.
    if ($encounteredWorkingCode){
	push @output, "</table>\n";
    }
    if ($currentCommmentBlock) {
	push @output, "$currentCommmentBlock\n";
    } 

    return @output;

}
#\function{The |process| subroutine}
# The |process| subroutine is so named because it stands at the heart of the Komments++ processor. It takes as its input the output of |weave| and immediately concatinates into one long string variable. It then builds its output by repeatedly matching this variable against a set of regular expressions. These all use the |g| modifier to retain the position of the last match internally, the |c| modifier to stop this position from being reset if a match fails, and the |\backslash{G}| anchor to reference the location after the last match within the regular expressions. These regular expression tests look for either one of the working code tables created by |weave|, a math or code environment's shortcut, a Komments++ environment, or a Komments++ command. A working code table gets examined for inline comments. If there are any, they are put through the |process| function. Shortcuts, environments, and commands trigger calls to the approprate subroutines.
#
#To distinguish working code from its surrounding text, the xHTML output of that text gets placed within paragraph (|<p>...</p>|) tags. The |process| subroutine handles this task. Since this subroutine can call itself directly and can be recursively called indirectly by one of its child subroutines, we need a way to tell the subroutine to only place its output within tags ``at the top level.'' For this, we use |\${}processLevel|, which was initialized in Section \ref{processorControlVariables} to zero. The subroutine only encapsulates its output within paragraph tags when this equals zero. Therefore, we can call |process| without triggering  the inclusion of paragraph tags by incrementing |\${}processLevel| and then decrementing it after retrieving the output. The subroutine also uses |\${}environmentLevel| to ensure that the user has not placed sectioning commands within environments.
#
#As noted above, the subroutine first concatinates its input array into a single long string with the |join| command. This command's uses its first argument to separate the distinct elements of its second element. We leave this empty.\footnote{Note that the |join| command does \emph{not} remove carriage returns from its input, so the concept of a ``line'' within |$input| is still well defined as a sequence of tokens ending with a carriage return.}
sub process { 
	my $input = join("", @_);
#The local variable |\${}chunk| gets used to hold the contents of a match.
	my $chunk;
#The next local variables requiring declaration handle the processing of inline comments within a working code table. 
	my $before;
	my $unprocessedComment;
	my $after;
	my $processedComment;
#Environment matches store the environment name, any accompanying options, and the environment's contents in the next global variables.
	my $environment;
	my $options;
	my $contents;
#Command matches reuse |\${}options| and store the command itself and any arguments in the next two global variables.
	my $command;
	my $argument;
#The subroutine used to implement any given environment or command gets stored in |\${}subroutine|.
	my $subroutine;
#Finally, the subroutine's |\${}output| goes into its eponymous variable.
	my $output;
#With all local variables declared, we are ready to begin. If the global variable |\${}processLevel| equals zero, then this call to |process| should encapsulate its output within matching paragraph tags.	
	if($processLevel==0){$output="<p>";}
#Now, we are ready to process the input. This is done with a loop that continues unless the last match reached the end of the |\${}input| string.
	while ( not $input =~ m/\G\z/gc ) {
#Given that the loop has not yet reached the input's end, the first test determines if the most recent match terminated at the beginning of a table of working code. If so, then we close the most recently created open paragraph tag and proceed to investigate the working code's contents. The contents of any unprocessed inline comment (clearly identified by its encompassing |span|'s class) get sent through |process| and placed within a new span with class |"inlineComment"|. After this processing, a new paragraph tag gets opened if appropriate.
		if ( $input =~m|\G\<table class="workingCode"\>.*?\</table\>|gcs){ #The |s| modifier instructs the engine to match |.| with |\backslash{}n|.
		    if($processLevel==0){$output=$output."</p>";}
		    $processLevel++;
		    $chunk=$&;
#The portion of |\${}chunk| coming before and after any match with an unprocessed inline comment get placed into |\${}before| and |\${}after|. The comment's content gets processed, and then |\${}chunk| gets reassembled.
		    while($chunk =~m/(\<span class=\"unprocessedInlineComment\"\>)(.*?)(\<\/span\>)/){
				$before=$`;
				$unprocessedComment=$2;
				$after=$'; 
				
				$processedComment=&process($unprocessedComment);
				$chunk=$before."<span class=\"inlineComment\">".$processedComment."</span>".$after;
		    }
#With all of the inline comments in |\${}chunk| processed, we append it to |\${}output| and open a paragraph tag if necessary.
		    $output=$output . $chunk;
                    $processLevel--;
                    if($processLevel==0){$output=$output."<p>";}
		}
#If instead the last match ended with two carriage returns potentially preceeded and/or separated by white space, then the user wishes to end the current paragraph and start another. We honor this if |\${}processLevel| equals zero.
		elsif ($input =~m/\G\s*\n\s*\n/gcs){ 
		    if($processLevel==0){$output = $output."</p>\n<p>";}
		}
#The next three tests determine if the last match left off with one of the short forms for a math environment. If so, they simply pass the match's contents to the |math| subroutine and append the returned contents to |$output|.
		elsif ($input =~m/\G$shortFormMath1/gcs){ #Matches |\$\textit{mathematical expression}\$|
			$contents=$1;
			$chunk=&math("math","",$contents);
			$output=$output.$chunk;
		}
		elsif($input=~m/\G$shortFormMath2/gcs){ #Matches |\backslash{}(\textit{mathematical expression}\backslash{})|
			$contents=$1;
			$chunk=&math("math","",$contents);
			$output=$output.$chunk;
		}
		elsif($input=~m/\G$shortFormDisplayMath/gcs){#Matches |\backslash{}[\textit{mathematical expression}\backslash{}[|
			$contents=$1;
			$chunk=&math("displaymath","",$contents);
			$output=$output.$chunk;
		}
#Similarly, there are two short forms for code environments. The next two tests handle these. For both of them, we increment and decrement |\${}environmentLevel| so that any sectioning commands within the environment trigger an error.
		elsif($input=~m/\G$shortFormCode/gcs){#Matches |\|\textit{non functional code}\||
		    $environmentLevel++;
		    $contents=$1;
		    $chunk=&code("code","",$contents);
		    $output=$output.$chunk;
		    $environmentLevel--;
		}
		elsif($input=~m/\G$shortFormDisplayCode/gcs){#Matches |\|{}\|\textit{non functional code}\|{}\||
		    $environmentLevel++;
		    $contents=$1;
		    $chunk=&code("displaycode","",$contents);
		    $output=$output.$chunk;
		    $environmentLevel--;
		}
#The next test matches any valid use of Komments++ environment syntax, whether or not it represents a valid environment. The regular expression in |\${}kppEnvironment| places the environment's name, any accompanying options, and the environment's contents into the three automatic match variables |\${}1|, |\${}2| and |\${}3|. The |\%{}environments| hash contains the name of the subroutine that implements the given environment. If this retrieval returns an empty string, then the requested environment is not valid and an error occurs. Otherwise, the subroutine gets called with the given options and contents and its output gets appended to |\${}output|. 
		elsif ( $input =~ m/\G$kppEnvironment/gcs ) {
		    $environmentLevel++;
		    $environment = $1;
		    $options     = $2;
		    $contents    = $3;
		    $environment=&stripBraces($environment);
			
		    $subroutine = $environments{$environment};

		    if($subroutine eq ""){print "Undefined environment: ".$environment."\n"; die;}
            
		    $chunk = &{ \&{$subroutine} }( $environment, $options, $contents );
		    $output = $output . $chunk;
		    $environmentLevel--;
		}
#We process a match with a valid use of Komments++ command syntax similarly.
		elsif ( $input =~ m/\G$kppCommand/gcs ) {
			$command  = $1;
			$options  = $2;
			$argument = $3;

			$subroutine = $commands{$command};

			if($subroutine eq ""){ print $output;    print "Undefined command: ".$command."\n"; die;}

			$chunk = &{ \&{$subroutine} }( $command, $options, $argument );
			$output = $output . $chunk;
		}
#The only Komments++ command that does not conform to the syntax defined by |\${}kppCommand| is the escaped backslash character. The next test handles this possibility.
		elsif ($input =~m/\G\\\\/gcs){
			$chunk="&#x5c;";
			$output=$output.$chunk;
		}
#In the final logical case to consider, the last match ended with some text that does not match any of the above regular expressions. That is, the text does not begin with a working code table, a valid use of environment or command syntax, one of the short forms for the math and code environments, two carriage returns, an escaped backslash character, or the end of the input. In this case, we capture everything from the last match until one of these conditions within the match variable. The required zero-width assertion uses the global variabel |\${}shortFormStarts| defined in Section \ref{regularExpressions} to match the short forms. Since environments always start with a valid use of command \emph{synatax} (|\backslash{}begin\{..\}|), the zero width assertion uses only |\${}kppCommand| to find both commands and environments. We replace double left and right quotes in the match variable with the appropriate Unicode character entities. Otherwise, the input is left unchanged. 
		elsif ( $input =~ m/\G.+?(?=$kppCommand|\<table class="workingCode"\>|$shortFormStarts|\s*\n\s*\n|\\\\|\z)/gcs ) {
			$chunk = $&;
			$chunk =~ s/``/&ldquo;/g;
			$chunk =~ s/''/&rdquo;/g;
			$output = $output . $chunk;
		}	
#The above regular expressions should cover all possible logical cases. To allow for the possibility that the code has an error, the subroutine returns an error if none of them match.
		else {
			die "Internal kpp error in sub process."
		}
	}
#This ends the loop through the contents of |\${}input|. If this call to |process| opened a paragraph tag, we need to close it before returning the output.	
        if($processLevel==0){
	    $output=$output."</p>";
	}
	return $output;
}
#\subsubsection{Code and Math Environments}
#Since |process| directly calls the |code| and |math| subroutines to implement their corresponding environments, we begin the development of environment-implementing subroutines with these. 
#\function{The |code| subroutine}
#The subroutine that implements the |code| and |displaycode| environments actually exemplifies most of the other environment-implementing subroutines. It begins by putting its contents through |process| and then embeds them either within a |span| (for the |code| environment) or a |div| (for the |displaycode| environment). The |displaycode| environment also closes the open paragraph and starts another one afterwards. 
sub code {

	my $contents    = pop @_;
	my $options     = pop @_;
	my $environment = pop @_;
	my $output;

#Check to see if the options contain a horizontal alignment directive.
	my $alignment="";
	if($options=~s/^\[(left|center|right)\]$//){
	    $alignment=$1;
	} 
#Check to see if another (illegal) option has been passed.
	if($options=~m/\S/){
	    die "displaycode environment called with unrecognized option. Options:\n$options\n Contents:\n$contents\n"
	}
#Remove any newline character that either starts or ends the |\${}contents|.
	$contents=~s/^\n//;
	$contents=~s/\n$//;
#Process the contents.
	$processLevel++;
	$contents = &process($contents);
	$processLevel--;

	
	if ( $environment eq "code" ) {
		$output = "<span class=\"code\">" . $contents . "</span>";
	}
	elsif ( $environment eq "displaycode" ) {
	    if($processLevel==0){
		$output = "</p>\n<div class=\"$alignment"."displaycode\">" . $contents . "</div>\n<p>";
	    }
	    else {
		die "displaycode environment improperly nested within another environment."
	    }
	}
	else {
		die "Internal kpp error. Incorrect subroutine called.";
	}

	return $output;
}
#\function{The |math| subroutine}
#The subroutine that implements the |math|, |displaymath|, and |equation| environments superficially resembles that for code. The contents get processed and then put within a |span| or |div| with the appropriate class. However, there are three key differences. First, the environment's contents get passed to |useMathJax| instead of |process|. Second, the |equation| environment has an accompanying equation number which must be created. Third, the |equation| environment might require the creation of a textual label to identify its equation number in references elsewhere in the document. The |label| subroutine extracts a user-assigned label from the contents if one exists.
sub math {

	my $contents    = pop @_;
	my $options     = pop @_;
	my $environment = pop @_;

	my $output;
	$output = useMathJax($contents);
	
	if ($environment eq "math"){
		$output = "<span class=\"inlineMath\">".$output."</span>";
	}
#Althought |displaymath| environments have no equation number, we place a dummy equation number within them. The document class CSS style sheets can set the |visibility| property of this paragraph class to |hidden| so that they take up space, thereby aligning the leftmost mathematics of the |displaymath| and |equation| environments.	
	elsif ( $environment eq "displaymath" ) {
		$output = "</p>\n  <div class=\"displayedMath\"><p class=\"filler\">(0)</p>".$output."</div> \n<p>";
	}
	elsif ( $environment eq "equation" ) {

		my $label = &label($contents);
#The equation counter in |\${}counters\{equation\}| provides the displayed equation number. We increment this before using it.
		$counters{equation}++;               

#The equation itself gets placed within a |div| tag. Within this, the equation number gets placed within a paragraph and is followed by the output from |useMathJax|. If |\${}label| is nonempty, we use this as the |div|'s |id|. We also associate this label with the given equation number with an entry in the |%reflabels| hash. 
		my $sectioningNumbers=&sectionNumberText("chapter"); #Equations are numbered within chapters. 
		if ($label) {      
			$reflabels{$label} = $sectioningNumbers.$counters{equation};
			$refappstat{$label} = $isInAppendix;
			$output = "</p>\n  <div class=\"displayedMath\" id=\"$label\"><p> (".$sectioningNumbers.$counters{equation}.") </p>".$output."</div> \n<p> ";
		}
		else {
			$output = "</p>\n  <div class=\"displayedMath\"><p> (".$sectioningNumbers.$counters{equation}.") </p>".$output."</div> \n<p> ";
		}
	}
	else {
		die "Internal kpp error: Incorrect subroutine called.";
	}
	return $output;
}

#\function{The |label| subroutine}
#The user attaches a cross-referencing label to a document object with the |\backslash{}label| command. The |label| subroutine simply searches its input for the first such command are returns its contents.
sub label {

	my $input = $_[0];
	my $output;

	if ( $input =~ m/\\label($matchingBraces)/){
		$output = &stripBraces($1);
	}

	return $output;
}
#\function{The |useMathJax| subroutine}
sub useMathJax {
#Input preprocessing removes newline characters from the input and replaces the unicode character entities for |<| and |>| inserted by |readfile| with their LaTeX command counterparts, |\backslash{}lt| and |\backslash{}gt|. 
	my $input = $_[0];
	$input =~ s/\n//g;
	$input =~ s/&lt;/ \\lt /g;
	$input =~ s/&gt;/ \\gt /g;

#The output is merely the input so altered enclosed within a mathjax environment delimiter. This cannot look like an xHTML tag, which is a shame. It also seems like a good idea to avoid setting this to the standard LaTeX/TeX math delimiters. Since it doesn't have to be convenient to type, we use |(StartMathJax)| and |(StopMathJax)|
	my $output="(StartMathJax)".$input."(StopMathJax)";

}


#\subsubsection{Other Environments}
# The |%environments| hash lists the subroutines that implement all other environment commands. We proceed through them in the order of their appearance in its declaration. 
#\function{The |matharray| subroutine}
#This subroutine implements the two environments for arrays of equations, |eqnarray| and |eqnarray*|. These have identical Komments++ syntax to their LaTeX counterparts. Each array has three columns, for the expression's left-hand side, its relational operator, and its right-hand side. Ampersands separate these, and two back slashes move to the next line. Each line in the |eqnarray| environment receives an equation number. A |\backslash{}label| command on the line creates a cross-reference key for the equation number, and a |\backslash{}nonumber| command suppresses the number entirely. The lines of the |eqnarray*| environment get no equation numbers.

#The xHTML code that implements these arrays uses the |table| tag and gives it the |"eqnarray"| class. Each row has three columns. The first contains any equation number, the second contains a LaTeX image of the row's left-hand side concatinated with its relational operator, and the third contains a LaTeX image of its right-hand side. Of course, the subroutine generates these with |useMathJax|. 
sub matharray {

    my $contents    = pop @_;
    my $options     = pop @_;
    my $environment = pop @_;
#The output gets placed into the usual eponymous variable.
    my $output;
#The following three variables store one row being examined and the relation's left-hand side (including the relational operator) and right-hand side.
    my $thisrow;
    my $lefthand;
    my $righthand;
#The image tags that import a given relationship's left-hand and right-hand sides get placed into |\${}leftOutput| and |\${}rightOutput|.
    my $leftOutput;
    my $rightOutput;
#The final local variable stores any label found by |label|.
    my $label;

#The output gets initialized by closing the open paragraph and opening the |table| to be built. 
    $output = "</p><table class=\"eqnarray\">\n";
#We work through the contents one row at a time. Each of these ends with either a double backslash or the end of the string.    
    while ( $contents =~ m/\G(.*?)(\\\\|\Z)/cgs ) {

		$thisrow   = $1;
#We require each non-empty row to contain exactly two unescaped ampersands that do not start Unicode character entities for the greater than or less than signs. &
		unless ($thisrow =~ m/\A\Z/) { # |\\A| matches the string's start, while |\\Z| matches its end.
		    if ($thisrow =~ m/(.*?)(?<!\\)&(?!(?:gt|lt);)(.*?)(?<!\\)&(?!(?:gt|lt);)((?:[^&]|(\\&)|(&(gt|lt);))*)\z/) {
				$lefthand  = $1 . $2;
				$righthand = $3;
						    
#We clear |\\label| and |\\nonumber| commands from |$lefthand| and |$righthand| so that they do not corrupt the LaTeX processing inadvertantly.
				$lefthand  =~ s/\\label($matchingBraces)//;
				$righthand =~ s/\\label($matchingBraces)//;
				$lefthand  =~ s/\\nonumber//;
				$righthand =~ s/\\nonumber//;
		    } else {
				die "Improperly specified equation array row. Each should have exactly two unescaped ampersands.\n"
		    }
#If either the left-hand or right-hand sides have only white space, then we set the corresponding output to an empty string.	  
		    if ($lefthand=~m/^\s*$/) {
			$leftOutput = "";
		    }
		    else {
			$leftOutput = &useMathJax($lefthand);
		    }
		    
		    if ($righthand=~m/^\s*$/) {
			$rightOutput = "";
		    }
		    else {
			$rightOutput = &useMathJax($righthand);
		    }

		    $label = &label($thisrow);
	    
#The row begins with an empty cell if either the row contains a |\backslash{}nonumber| command or we are operating on an |eqnarray*| environment. Otherwise, the first cell contains the equation number in parentheses. (We should probably let the document class code put the parentheses there, but that is a battle for another day.) The equation number cell also gets any label text as its |id| atribute.
		    if ( ( $thisrow =~ m/\\nonumber/ ) | ( $environment eq "eqnarray*" ) ) {
				$output = $output . "<tr><td class=\"eqnumber\"></td>";
		    }
		    else {                                                                     
				$counters{equation}++;                                         
				my $sectioningNumbers=&sectionNumberText("chapter");
				if ($label) {                                                  
			    	$reflabels{$label} = $sectioningNumbers.$counters{equation};
				$refappstat{$label} = $isInAppendix;
			    	$output = $output . "<tr><td class=\"eqnumber\" id=\"$label\">(".$sectioningNumbers.$counters{equation}.")</td>";
				} else {                                                       
			    	$output = $output . "<tr><td class=\"eqnumber\">(".$sectioningNumbers.$counters{equation}.")</td>";
				}
		    }
#The cell's for the equation's left-hand and right-hand sides get their class attrributes set to |"left"| and |"right"|.
		    $output = $output . "<td class=\"left\">".$leftOutput."</td>";
		    $output = $output . "<td class=\"right\">".$rightOutput."</td></tr>\n";
		}
    }
#With the loop over the array's rows completed, we can close the |table| tag, open a new paragraph, and return the xHTML string.
    $output = $output . "</table>\n<p>";
    return $output;
}
#\function{The |float| subroutine}
#The |float| subroutine implements the |box|, |figure|, and |table| environments. Recall from Section \ref{globalVariables} that the global variable |\${}floatType| is initialized to |"None"|. If this global has this initial value, the subroutine sets |\${}floatType| to a different string (used by the |caption| command), puts the environment's contents through |process|, encapsulates the results in an appropriately classed |div| tag, and resets |\${}floatType| to |"None"|. If instead |\${}floatType| does not equal |"None"|, the program throws an error to prevent the user from nesting floats.
sub float {

	my $contents    = pop @_;
	my $options     = pop @_;
	my $environment = pop @_;
	my $output;

	unless ( $floatType eq "None" ) {
		die "Fatal error: Floats cannot be nested.";
	}

	if ( $environment eq "figure" ) {
		$floatType = "Figure";
		$counters{figure}++;
		
	}
	elsif ( $environment eq "table" ) {
		$floatType = "Table";
		$counters{table}++;
	}
	elsif ( $environment eq "box" ) {
	        $floatType = "Box";
		$counters{box}++;
	}
	else {
		die "Internal kpp error. Incorrect subroutine called.";
	}

	$contents = &process($contents);
	$output = '</p><div class="' . $environment . '">' . $contents . '</div><p>';
	$floatType = "None";

	return $output;
}
#\function{The |tabular| subroutine}
#The most involved subroutine in the Komments++ processor is |tabular|, which mimics the LaTeX tabular environment. The correct syntax for the Komments++ tabular environment is nearly identical to that for the corresponding LaTeX environment. The environment's options dictate the number of columns and the horizontal alignment of their contents, and the presence of any separating bars between them. The |\backslash{}hline| command can be used to draw a line beneath all columns of the current row, and |\backslash{}cline\{\textit{i}-\textit{j}| draws such a line only across columns |\textit{i}| through |\textit{j}|. Finally, the |\backslash{}multicolumn| command can be used to join two or more cells in a given row together. One potentially important difference between the two syntaxes is that the |@\{\}| constuction cannot be used to place content between rows. Some other unimportant (in our opinion unimportant) differences between the two are;
#\begin{itemize}
#\item In LaTeX, multiple pipes between column alignment specifiers produce multiple horizontal lines between the corresponding columns. Komments++ treats multiple pipes as a single pipe and puts a single line between the columns.
#\item Multiple |\backslash{}hline| commands on a row produce multiple horizontal lines beneath it in LaTeX. Komments++ inserts a single horizontal row following multiple |\backslash{}hline| commands.
#\item If a Komments++ |\backslash{}cline| command specifies that a line goes above the rows covered by a |\backslash{}multiline| command on the next line, it will only be rendered over any of those rows if it its specification places it over all of them.
#\end{itemize}
#
# To implement horizontal alignment and column spanning, we use the |td| tag's |align| and |colspan| attributes, and we use each |td| tag's class name to indicate the presence of vertical and horizontal lines around the corresponding table cell. The document class's CSS code is responsible for using this information to render the appropriate vertical and horizontal lines.
#
#The subroutine itself begins with input checking and the determination of the tabular's column structure from its options. Thereafter, it proceeds through the table's rows and writes their implementing xHTML code.
sub tabular{

	my $contents    = pop @_;
	my $options     = pop @_;
	my $environment = pop @_;

	unless ( $environment eq "tabular" ) {
		die "Internal kpp error: Incorrect subroutine called."
	}
#The |$contents| must begin with a column specification. Retrieve it.
	my $columnspec;
	if ($contents=~ s/^\{([lcr\|]*)}//) {
	    $columnspec=$1;
	} else {
	    die "Fatal error: Invalid column specification for tabular environment. Contents of tabular environment: \n$contents \n"
	}
	
#The options should either be empty or contain an alignment directive for the environment as a whole, |left|, |center|, or |right|.
	my $alignment;
	if ($options =~ s/^\[(left|center|right)\]//) {
	    $alignment=$1;
	} 
	if ($options =~/\S/) {
	    die "Fatal error: Invalid options given to tabular environment. Options of tabular environment: \n$options \n\n Contents of tabular environment: \n$contents\n ";
	}

#The options may contain only pipes and the three valid horizontal alignment specifier, ``|l|'', ``|c|'', and ``|r|''.
	if ( $options =~ /^[lcr\|]/ ) {
		die "Fatal error: Invalid column specification for tabular environment.";
	}

#Next, we read the options to determine the table's column specification. Each column has a horizontal alignment specifier preceeded and followed by one or more pipes. The following loop sequentially strips one of these pipe-alignment combinations out and places them into the elements of an array. The number of columns can be read from this array in scalar context.
	my @columnspec;
	while ( $columnspec =~ s/\|*[lcr]\|*// )
	{ 
		push @columnspec, $&;
	}
	my $columns = @columnspec;	
#Before proceeding to process the table's contents, we declare several local variables used, initialize the subroutine's output with the opening |table| tag, and strip newlines from |\${}contents|.
	my ( $thiscolumn, $thiscolumnspec, $thiscolumnspan, $thisrow, $thiscell, $thisalignment, $thisverticalbars );
	my ( $i, $j );
	my $clines;
	my @clinelow;
	my @clinehigh;
	my $thistopline;
	my $output = "</p>\n<table class=\"$alignment"."tabular\">\n<tbody>\n";
	$contents =~ s/\n//g;
#Processing the contents proceeds with two loops. The outer loop proceeds down across the tabular environment's rows. The inner loop proceeds from left to right through each row's cells. Each row ends either with a double backslash or the end of the environment. The regular expression controlling the outer loop finds the first row in |\${}contents| and removes it. The loop's first line then places the found row into |\${}thisrow|.
	while ( $contents =~ s/(.*?\\\\|.+?$)//s ) {
		$thisrow = $&;
#The first task is to search the row for |\backslash{}hline| commands and remove them. If one exists, the row's |tr| tag gets the class |"hline"|. Responsibility for drawing the line itself over these rows falls to the document classes' CSS code. Without an |\\hline| command, the |tr| tag gets no class. 
		if ( $thisrow =~ s/\\hline//g ) {
			$output = $output . "<tr class=\"hline\">";
		}
		else {
			$output = $output . "<tr>";
		}
#Next, we search the row for |\backslash{}cline| commands. For each one, we record the specified starting and ending columns in |@clinelow| and |@clinehigh|.
		$clines = 0;
		while ( $thisrow =~ s/\\cline\{([0-9]+)-([0-9]+)\}// ) {
			$clines++;
			$clinelow[$clines]  = $1;
			$clinehigh[$clines] = $2;
		}
#We are now prepared to proceed through the row's cells. To do so, we repeatedly search through |\${}thiscolumn| for text that ends with either
#\begin{itemize}
#\item an ampersand that is unescaped and does not start the Unicode character entity for either the greater than or less than signs,
#\item a double backslash (indicating the end of the row), or
#\item the end of the string.
#\end{itemize}
#The regular expression's matching text gets removed from |\${}thisrow| and placed into |\${}thiscell| for further processing.
		$thiscolumn = 0;                                           
		while ( $thiscolumn < $columns ) {
			$thisrow =~ s/(.*?)((?<!\\)&(?!(gt|lt);)|\\\\|\Z)//s;
			$thiscell = $1;
#A given cell either contains a |\backslash{}multicolumn| or it does not. If it does, then we set |\${}thiscolumnspec| to equal its options and |\${}thiscolumnspan| to equal the indicated number of columns it spans. If not, then we read |\${}thiscolumnspec| from the appropriate element of |@columnspec| and set |\${}thiscolumnspan| to one. In either case, we feed the cell's other contents to |process|.
			if ( $thiscell =~ /\\multicolumn\{([0-9]+)\}\{(\|*[lcr]+\|*)\}\{(.*?)\}/ ) {
			    $processLevel++;
			    $thiscell       = &process($3);
			    $processLevel--;
			    $thiscolumnspec = $2;
			    $thiscolumnspan = $1;
			    if ($thiscolumnspan<1 || $thiscolumnspan % 1){ die "Column span in \\multicolumn command must be positive integer";}
			}
			else {    #There is no valid \backslash{m}ulticolumn command. Proceed using the column specification from the environment's options.
			    $processLevel++;
			    $thiscell       = &process($1);
			    $processLevel--;
			    $thiscolumnspec = $columnspec[$thiscolumn];
			    $thiscolumnspan = 1;
			}

#Next, we read this cell's horizontal alignment from |\${}thiscolumnspec| and assign the appropriate value for the |td| tag's |align| atribute to |\${}thisalignment|.
			if ( $thiscolumnspec =~ /l/ ) {
				$thisalignment = "left";
			}
			elsif ( $thiscolumnspec =~ /c/ ) {
				$thisalignment = "center";
			}
			elsif ( $thiscolumnspec =~ /r/ ) {
				$thisalignment = "right";
			}
			else { #This case should never be reached.
			    
				die "Internal kpp error.";
			}
#The information in |\${}thiscolumnspec| also determines the presence or absence of vertical lines on either side of the cell. There are four possibilities, and we store a string describing the applicable one in |\${}thisverticalbars|.
			if ( $thiscolumnspec =~ /\|[lcr]\|/ ) {
				$thisverticalbars = "bothvertical";
			}
			elsif ( $thiscolumnspec =~ /\|[lcr]/ ) {
				$thisverticalbars = "leftvertical";
			}
			elsif ( $thiscolumnspec =~ /[lcr]\|/ ) {
				$thisverticalbars = "rightvertical";
			}
			else {
				$thisverticalbars = "novertical";
			}
#Any horizontal lines required by the row's |\backslash{}hline| commands have already been incorporated into the class of this cell's encompassing |tr| tag. However, the row's |\backslash{}cline| commands might require us to place a horizontal line over this individual cell. For this, we search to see if all of the columns spanned by this cell fall within any of |\backslash{}cline| command's indicated span. If so, we set |\${}thistopline| to ``|top|''. 
			$thistopline = "";
			for ( $i = 1 ; $i <= $clines ; $i++ ) {
				if (   ( $thiscolumn + 1 >= $clinelow[$i] )
					&& ( $thiscolumn + $thiscolumnspan <= $clinehigh[$i] ) )
				{
					$thistopline = "top";
				}
			}
#The information about this cell's surrounding vertical and horizontal lines is now in hand, so we are ready to create this cell's |td| tag. We embed the information on its surrounding lines into its class name.
			$output     = $output . "<td class=\"$thisverticalbars$thistopline\" align=\"$thisalignment\" colspan=\"$thiscolumnspan\">$thiscell</td>";
#This finishes the construction of this cell. Before proceeding to the next column, we increment |\${}thiscolumn| by |\${}thiscolumnspan|.
			$thiscolumn = $thiscolumn + $thiscolumnspan;
		}
#With loop over this row's cells completed, we need only close the row's opening |<tr>| tag before proceeding to the next row.
		$output = $output . "</tr>\n";
	}
#The last remaining task before returning the output is closes  the opening |<table>| and |<tbody>| tags and opens a new paragraph.
	$output = $output . "</tbody>\n</table>\n<p>";
	return $output;
}
#\function{The |bibliography| subroutine}
# The |bibliography| environment contains bibliographic references. It should contain a sequence of bibliography entries, each started with the |\\bibitem| command. The contents of this command's bracketed options give the label for the reference inserted in the text by a |\\cite| command, and the command's argument gives the key with which the |\\cite| command can refer to it. The procedure itself goes through the bibliography contents looking for (and removing) |\\bibitem| commands and their following contents. The xHTML code for the bibliography is an unordered list (|<ul>|). The text that either preceeds the next |\\bibitem| command or the content's end is the bibliography entry's content, and this gets set within a list item (|<li>|) tag. 

sub bibliography {

	my $contents    = pop @_;
	my $options     = pop @_;
	my $environment = pop @_;

	unless ( $environment eq "bibliography" ) {
		die "Internal kpp error: Incorrect subroutine called.";
	}

#As noted above, the bibliography itself gets placed within |<ul>| tags. We preceed this with a division containing a single empty span. This gives the document class files someplace to hook a label for the bibliography.
	my $output = "\n" . '</p><hr/><div class="bibliographyLabel"><span class="bibliographyLabelAnchor"></span></div>'."\n".'<ul class="bibliography">' . "\n";

#The following local variables store the citation key, label, and citation content for a single bibliographic enry.
	my $key;
	my $label;
	my $citeContent;

#Before processing the bibliographic entries, we ensure that the first non-white space in |\${}contents| is a |\backslash{}bibitem| command.
	unless ($contents=~m/^\s*\\bibitem($matchingBrackets)?($matchingBraces)/s){
	    die "bibliography environment must begin with a \\bibitem command."
	}
#The actual processing of bibliographic entries proceeds in the following loop, which continues until the regular expression in its condition fails to find a valid |\backslash{}bibitem| command. If it does find one, it stores the label and key in their eponymous variables. We strip the enclosing braces from the key, and we strip the brackets and process any label. If there is no label, we use the (unprocessed) key in its stead. Finally, we store the key/label combination in the |%citelabels| hash for later use.
	while ( $contents =~ s/\\bibitem($matchingBrackets)?($matchingBraces)//s ) {
		$label = $1;
		$key   = &stripBraces($2);

		if ($label) {
			$label =~s/^\[//;
			$label =~s/]$//;

			$processLevel++;
			$label = &process($label);   
			$processLevel--;
		}
		else {
			$label = $key;
		}
		$citelabels{$key} = $label;
#With the |\backslash{}bibitem| command removed, the bibliography entry's data run from the beginning of |\${}contents| until either the next |\backslash{} bibitem| command or the end of the string. In either case, we process the bibliography entry's data and remove it from |\${}contents|.
		if ( $contents =~ s/^(.*?)(?=\\bibitem)//s ) {
		    $processLevel++;
		    $citeContent = &process($1);
		    $processLevel--;
	
		}
		else {
		    $processLevel++;
		    $citeContent = &process($contents);
		    $processLevel--;
		    $contents    = "";
		}
#The final step in the processing of this bibliography entry is the generation of its associated list entry.		
		$output = $output . '<li id="' . $key . '">' . $citeContent . '</li>';
	}

#This completes the loop over the bibliography's entries. Close the list, open the following paragraph, and return the output.
	$output = $output . '</ul>' . "\n" . '<p>';
	return $output;
}
#\function{The |list| subroutine}
#Komments++ supports four list-making environments, |tree|, |itemize|, |enumerate|, and |dictionary|. The first two use the xHTML |<ul>| tag, while the other two use |<ol>| and |<dl>|. Each |\backslash{}item| command in a list-making environment creates one list entry. These lists can themselves contain other environments, including listing environments. Therefore, we do \emph{not} simply assign all text between two instances of |\backslash{}item| to a list entry. Instead, the regular expressions we use to parse the environment's contents always capture any Komments++ environment whole.
sub list {

	my $contents    = pop @_;
	my $options     = pop @_;
	my $environment = pop @_;
	my $output;

#The listmaking environments require slightly different processing from each other, so we write three loops and use the contents of |\${}envronment| to select the correct one. We begin with |tree| and |itemize|, which both create an unordered lists. The only difference between their outputs is the class name, which allows the document class to style them differently.
	if ( $environment eq "itemize" | $environment eq "tree" ) {
		$output = "<ul class=\"".$environment."\">\n";
#The regular expression governing the loop through the contents uses the now familiar |\backslash{G}| anchor with the |g| and |c| modifiers to detect when the search has reached the end of the string.
		while ( not $contents =~ m/\G\z/gc ) {
#The next regular expression employed is the heart of this subroutine. It looks for a |\backslash{}item| command and then captures everything between it and the next item command \emph{that does not appear within an environment opened after the initial |\backslash{}item| command} or the end of the string. Ignoring |\\item| commands within environments subseqently opened allows lists to be nested. If the regular expression test fails, then we are out of item commands, so we exit the loop with the |last| command. (Perhaps the user forgot to include them!) Appending a closing |</ul>| tag finishes the list.
		    if ($contents =~ m/\G\s*?\\item($matchingBrackets)?((?:(??{$kppEnvironment})|.)*?)(?=(\\item|\z))/gcsix){
			my $itemtype="generic";
			if ($1){
			    $itemtype=$1;
			}
			my $item = $2;
		        $itemtype=&stripBrackets($itemtype);
			$processLevel++;
			$item   = &process($item);
			$processLevel--;
#If the item has an optional type, ensure that it is valid.
			unless ($itemtype =~ /^\s*(?:alert|note|definition|source|size|length|use|warning|private|input|output|incomplete|complete|time|function|class|danger|bug|folder|link|document|file|character|numerical|date|data|computer|storage|generic)\s*$/) {
			    die "Invalid item option (type) in tree or enumerate environment.\n Option: $itemtype\n\n Item Contents: $item \n "
			}

#Strip newline characters out of |\${}item| so that they can be used to format trees.
			$item =~s/[\n\r\t\v\f]//g;
#Break the |\${}item| into the entry text and any following lists. Only the entry itself goes into the |listitemcontent| span.
			my $listitemcontent;
			my $sublists;
			if ($item =~m/\<\s*(?:ul|ol|dictionary)/){
			   $listitemcontent="$`";
			   $sublists="$&$'";
			} else {
			   $listitemcontent=$item;
			   $sublists="";
			}
			#Trim leading and lagging white space from the list item content.
			$listitemcontent=~s/^\s+//;
			$listitemcontent=~s/\s+$//;
			$output = $output . "<li class = \"$itemtype\"><span class=\"listitemcontent\">$listitemcontent</span>$sublists</li>";
		    }
		    else {
			last;
		    }
		}
		$output = $output . '</ul>';
	}
#The processing of the |enumerate| environment parallels that for the |itemize| environment with |<ol>...</ol>| replacing |<ul>...</ul>|.
	elsif ( $environment eq "enumerate" ) {
		$output = '<ol class="enumerate">';
		while ( not $contents =~ m/\G\z/gc ) {
		    if ( $contents =~ m/\G\s*?\\item(((??{$kppEnvironment})|.)*?)(?=(\\item|\z))/gcsi ) {
			$processLevel++;
			my $item   = &process($1);
			$item =~ s/[\n\r\t\v\f]//g;
			$processLevel--;
			if($item =~m/\<\s*(?:ul|ol|dictionary)/){
			    $output = $output . "<li><span class=\"listitemcontent\">$`</span>$&$'</li>";
			} else {
			    $output = $output. "<li><span class=\"listitemcontent\">$item</span></li>";
			}
		    }
		    else {
			last;
		    }
		}
		$output = $output . '</ol>';
	}
#In a dictionary list, each |\backslash{}item| command should have an argument (in braces) giving the term to be defined. The term is placed within |<dt>...</dt>| tags, its following definition gets placed within |<dd>...</dd>|. The regular expression within the loop is nearly identical to that from above, but it captures the term as well as its definition.
	elsif ( $environment eq "dictionary" ) {
		$output = '<dl class="dictionary">' . "\n";
		while ( not $contents =~ m/\G\z/gc ) {
		    if ( $contents =~ m/\G\s*?\\item($matchingBrackets)(((??{$kppEnvironment})|.)*?)(?=(\\item|\z))/gcsi ) {
			#Strip the brackets from the option.
			my $term   = &stripBrackets($1);
			$processLevel++;
			$term      = &process($term);
			my $item   = &process($2);
			$item =~ s/[\n\r\t\v\f]//g;
			$term =~ s/[\n\r\t\v\f]//g;
			$processLevel--;
			if($item =~m/\<\s*(?:ul|ol|dictionary)/){
			    $output = $output . "<dt><span class=\"listitemcontent\">$term</span></dt><dd><span class=\"listitemcontent\">$`</span>$&$'</dd>";
			} else {
			    $output = $output . "<dt><span class=\"listitemcontent\">$term</span></dt><dd><span class=\"listitemcontent\">$item</span></dd>";
			}
		    } 
#If the author has ommitted the term to be defined, we simply capture the definition and place it within |<dd>...</dd>|.
		    elsif ($contents =~m/\G\s*?\\item(((??{$kppEnvironment})|.)*?)(?=(\\item|\z))/gcsi ) {
			$processLevel++;
			my $item = &process($1);
			$processLevel--;
			if($item =~m/\<\s*(?:ul|ol|dictionary)/){
			    $output = $output . "<dt></dt><dd><span class=\"listitemcontent\">$`</span>$&$'</dd>";
			} else {
			    $output = $output . "<dt></dt><dd><span class=\"listitemcontent\">$item</span></dd>";
			}
		    }
		    else {
			last;
		    }
		}
		$output = $output . '</dl>';
	}
#The final case catches any internal Komments++ errors that call this subroutine with an inappropriate environment.
	else {
		die "Internal kpp error.";
	}
#The output should start with a close paragraph tag and end with an open paragraph tag if we are at the top-most process level.	
	if ($processLevel == 0) {$output = "</p>\n".$output . "<p>\n";}
	return $output;
}
#\function{The |quote| subroutine}
# LaTeX has two environments for quotations, |quote| for shorter quotations (or a sequence of such quotations) and |quotation| for multiple-paragraph quotations. The only practical difference between them is that the latter indents paragraphs. The document class files are responsible for such indentation. Here, we simply process the environments' contents and place them within |<blockquote>...</blockquote>| tags with the |class| attribute set to the environment name.
sub quote {

    my $contents = pop @_;
    my $options = pop @_;
    my $environment = pop @_;
    my $output;
    $processLevel++;
    $contents = &process($contents);
    $processLevel--;

    if ($environment eq "quote"){
	$output = "<blockquote class=\"quote\">".$contents."</blockquote>";
    } elsif($environment eq "quotation"){
	$output = "<blockquote class=\"quotation\">".$contents."</blockquote>";
    } else {
	die "Internal kpp error. Incorrect subroutine called.";
    }
    if($processLevel==0){
	$output="</p>\n".$output."\n<p>";
    }
    return $output;
}
#\function{The |hiddencode| subroutine}
#The |hiddencode| environment provides a means for the user to hide code selectively. Exactly how the code gets displayed depends on the document class code. The only job for the processor is to place this within a span with class set to |"hiddencode"|.
sub hiddencode {

   my $contents = pop @_;
   my $options = pop @_;
   my $environment = pop @_;
   my $output;

   $processLevel++;
   $contents = &process($contents);
   $processLevel--;
   
   $output=$output."<span class=\"hiddencode\">".$contents."</span>";
   if ($processLevel==0){
       $output="</p>\n".$output."\n<p>";
   }

   return $output;

}
#\function{The |slide| subroutine}
#Komments++ provides the |slide| environment for defining slides that can be used in a slide show. It also supports an optional |\backslash{}slidetitle| command to specify the slide's heading. The document class files handle the actual creation of slides. Here, we simply put these environments' contents into |<div>...</div>| tags. This subroutine also implement here the supporting environment |slideonly|. The document class should accordingly exclude its contents from the document's basic ``prose'' view.
sub slide {
    
    my $contents = pop @_;
    my $options = pop @_;
    my $environment = pop @_;
    my $output;
    my $title;
    if ($contents =~ /\\slidetitle($matchingBraces)/) {
	    $title = &stripBraces($1);
	    $processLevel++;
	    $title = &process($title);
	    $processLevel--;
	    $title = "\n<div class=\"slideTitle\">" . $title . "</div>";
    }
#Unlike with many other environments, we do \emph{not} increment |\${}processLevel| before processing the contents. This allows the slide to contain material set in an environment.
    $contents = &process($contents);
    
    if ($environment =~ m/slide/) {
	$output="<div class=\"slide\">$title".$contents."</div>";
    } elsif ($environment =~ m/slideonly/) {
	$output="<div class=\"slideonly\">".$contents."</div>";
    }
    if ($processLevel==0){
	$output="</p>\n".$output."\n<p>";
    }

    return $output;
}

sub omissions {

   my $contents = pop @_;
    my $options = pop @_;
    my $environment = pop @_;
    my $output;
 
#Just as with the slide environment, we do not increment or decrement |\${}processLevel| before processing the omission environment's contents.
   $contents=&process($contents);

   if ($environment =~m/omitfromslide/) {
       $output = "<div class=\"omitfromslide\">".$contents."</div>";
   } elsif ($environment =~ m/omitfromprose/) {
       $output = "<div class=\"omitfromprose\">".$contents."</div>";
   } else {
       die "Internal kpp error.";
   }

   return $output;
       

}
#\function{The |returnNothing| subroutine}
#The final subroutine we need to handle environments is |returnNothing|. We direct the processor to this when it encounters an environment handled by a secondary processor.
sub returnNothing {
	return "";
}
#\subsubsection{Sectioning Commands}
#The content of all but the most trivial of documents can be partitioned into a tree-like structure. For example, the Bible has \emph{books}, which are then divided into \emph{chapters}. The chapters themselves are composed of \emph{verses}. LaTeX uses \emph{sectioning commands} to create document trees. At the top level is |\backslash{}part|, and beneath this is |\backslash{}chapter|. The |\backslash{}section|, |\backslash{}subsection|, and |\backslash{}subsubsection| commands form the document tree within chapters of book-length documents and form the complete document tree for shorter documents, like articles. LaTeX also supports |\backslash{}paragraph| and |\backslash{}subparagraph| commands for even finer partitioning. All of these accept a single argument giving the sectioning unit's title. 
#
#Komments++ borrows extensively from LaTeX's scheme for specifying a document's sectioning tree. In particular, it supports all of the sectioning commands but |\backslash{}subparagraph|. As in LaTeX, sectioning commands must be nested, so |\backslash{}subsubsection| cannot follow |backslash{}section| unless there is an intervening |\backslash{}subsection|. However, |\backslash{}part| and |\backslash{}chapter| are optional. Komments++ also differs from LaTeX by supporting several synonyms for |\backslash{}paragraph|, such as |\backslash{}function| and |\backslash{}subroutine|. The final important difference with LaTeX concerns the extent of the document tree.  Only the five ``top-level'' sectioning commands contribute to the document tree in Komments++: |\backslash{}paragraph| and its synonyms only provide a nice header. 
#
#Since document trees formed with nested xHTML tags are fundamental to Javascript, we wish our implementation of the LaTeX sectioning commands to encompass all of the content of one sectioning unit within |<div>...</div>| tags. Our construction of the document tree relies heavily the global hash |%counters|. It contains an element named for each of the top five sectioning commands. When we encounter any sectioning command but |\backslash{}part|, we increment its counter by one \emph{and reset the counters of all lower sectioning commands to zero.} This allows us to quickly detect an improperly nested sectioning command with a comparison of the counter for the next higher sectioning command to zero. We can also use |%counters| to determine how many |<div>| tags require closure by tabulating the number of weakly lower sectioning commands with nonzero counters.  The subroutine |incrementCounters| handles these tasks, and |resetCounters| closes all open tags when document processing is complete. The top-level subroutine for processing sectioning commands is |sections|, and this relies on |sectionNumberText| and its helper functions to create xHTML code for each sectioning unit's numbers. Finally, the |appendix| command ends the sectioning scheme for the document's body and begins a new one for its appendices.
#
#\function{The |sections| subroutine} 
#All of the Komments++ sectioning commands trigger a call to |sections|. It begins with a check to see if the command fell within a Komments++ environment, which is illegal. Then it performs basic input checking.
sub sections {
	my $argument = pop @_;
	my $options  = pop @_;
	my $command  = pop @_;

	if($environmentLevel>0){
	    print "Environments may not contain sectioning commands.\n\t Command: $command \n\tCommand argument: $argument \n";
	    die;
	}

	unless ( $command =~ m/(part|chapter|section|subsection|subsubsection|paragraph|function|method|subroutine)/ ) {
		die "Internal kpp error.";
	}

	if     ($options)  { 
	    die "\\" . $command . " takes no options.\n"; 
	}

	unless ($argument) {
		die "\\" . $command . " missing its mandatory argument.\n";
	}

#The next task detects whether the setioning command under consideration has been improperly nested. Subsubsections are improperly nested if current subsection counter equals zero.
	if($counters{subsection} eq 0 && $command eq "subsubsection"){
	    print "Improperly nested subsubsection command. Argument = $argument\n";
	    die;
	}
#Similarly, a subsection is improperly lested if the section counter equals zero.
	if($counters{section} eq 0 && $command eq "subsection"){
	    print "Improperly nested subsection command. Argument = $argument\n";
	    die;
	}
#A section can only be improperly nested if the document has a previous |\backslash{}part| command. In this case, the section is improperly nested if the chapter counter equals zero.	
	if($counters{part}>0){ 
	    if($counters{chapter} eq 0 && $command eq "section"){
		print "Improperly nested section command. Argument = $argument\n";
		die;
	    }
	}
#A chapter can only be improperly nested if it is the first chapter and a lower-level sectioning command has already been used.
	if($command eq "chapter" && $counters{chapter} eq 0 && ($counters{section}>0 || $counters{subsection}>0 || $counters{subsubsection}>0)){
	    print "Improperly nested chapter command. Argument = $argument\n";
	    die;
	}
#Similarly, a part can only be improperly nested if it is the first part and a lower-level sectioning command has already been used.
	if($command eq "part" && $counters{part} eq 0 && ($counters{chapter}>0 || $counters{section}>0 || $counters{subsection}>0 || $counters{subsubsection}>0)){
	    print "Improperly nested part command. Argument = $argument\n";
	    die;
	}
#With the error checking completed, the actual processing of the sectioning command's argument can proceed. We strip its surrounding braces, retrieve any cross-referencing label it contains, and feed it to |process|.
	$argument = &stripBraces($argument);
	my $label = &label($argument);
	$processLevel++;
	$argument = &process($argument);
	$processLevel--;
#So that a document class's Javascript code can rely each sectioning unit having a cross-referencing label, we give it a default one based on |\${}defaultLabelCounter| if the user did not specify one.	
	unless ($label) {
	    $label = "_default_" . $defaultLabelCounter++;
	}
#The most visible consequence of a sectioning command is the resulting pair of header tags. These contain the processed argument as well as automatically generated sectioning numbers. Which of the six possible header tags gets used for this particular sectioning command gets retrieved from the |%sectionTags| hash, and the section numbers come from the |sectionNumberText| subroutine. As noted above, |incrementCounters| creates a string containing the appropriate opening and closing division tags. Since it also increments the global |%counters|, we call this before calling |sectionNumberText|.
	my $sectionTag = $sectionTags{$command};
	my $divisionTags=&incrementCounters($command);
	my $sectioningNumbers=&sectionNumberText($command);
#The last step before constructing the xHTML output is to save cross referencing information. The global hash |%reflabels| associates the cross reference label with the string in |\${}sectioningNumbers|, and |%refappstat| associates it with a dummy variable indicating the unit's presence in the appendix.
	$reflabels{$label} = $sectioningNumbers;
	$refappstat{$label} = $isInAppendix;
#We are now prepared to create the subroutine's xHTML output. This begins with the division tags generated by |incrementCounters| and the opening of the header tag. The latter is given a class equal to the section command's name if it is in the document's main body. If instead it is in an appendix, then it has ``|Appendix|'' appended to its class value.
	my $output;
	if ($isInAppendix == 1) {
	    $output = "</p>\n".$divisionTags."<" . $sectionTag . " class=\"" . $command . "Appendix\" id=\"" . $label . "\">";
	}
	elsif ($isInAppendix == 0) {
	    $output = "</p>\n".$divisionTags."<" . $sectionTag . " class=\"" . $command . "\" id=\"" . $label . "\">";
	}
#The output proceeds with the section unit's title in |\${}argument| placed within |<span>...</span>| tags and finishes with the closure of the section tag.
	$output=$output.$sectioningNumbers."<span class=\"sectionName\">".$argument . "</span></" . $sectionTag . ">\n<p>";
	return $output;
}
#\subroutine{The |incrementCounters| subroutine}
#The subroutine for incrementing |%counters| and generating the appropriate closing |</div>| tags and any required opening |<div>| is long but not involved.
sub incrementCounters{
	my $command=$_[0];	
	my $output;
#|\backslash{}part| resets the chapter counter to the |negative| of its value, to indicate that the preceeding chapter has already been closed.
	if($command eq "part"){
	my @footnoteTableArray=&footnoteTable();
	my $footnoteTable="";
	if(@footnoteTableArray){
	    $footnoteTable=join("\n",@footnoteTableArray);
	}

	    $counters{part}++;
	    if($counters{subsubsection}>0){
		$output="</div></div></div></div>$footnoteTable</div>";
	    }
	    elsif($counters{subsection}>0){
		$output="</div></div></div>$footnoteTable</div>";
	    }
	    elsif($counters{section}>0){
		$output="</div></div>$footnoteTable</div>";
	    }
	    elsif($counters{chapter}>0){
		$output="</div>$footnoteTable</div>";
	    }
	    elsif($counters{part}>1){
		$output="$footnoteTable</div>";
	    }
	    $output=$output."<div class=\"part\">";
	$counters{chapter}=-$counters{chapter};
	$counters{section}=0;
	$counters{subsection}=0;
	$counters{subsubsection}=0;
	$counters{equation}=0;
	$counters{figure}=0;
	$counters{table}=0;
	} 
	elsif($command eq "chapter"){
	    if($counters{chapter}<0){
		$counters{chapter}=-$counters{chapter};
		$counters{chapter}++;
		$output=$output."<div class=\"chapter\">";
	    } else {
		my @footnoteTableArray=&footnoteTable();
		my $footnoteTable="";
		if(@footnoteTableArray){
		    $footnoteTable=join("\n",@footnoteTableArray);
		}
		$counters{chapter}++;
		if($counters{subsubsection}>0){
		    $output="</div></div></div>$footnoteTable</div>";
		}
		elsif($counters{subsection}>0){
		    $output="</div></div>$footnoteTable</div>";
		}
		elsif($counters{section}>0){
		    $output="</div>$footnoteTable</div>";
		}
		elsif($counters{chapter}>1) {
		    $output="$footnoteTable</div>";
		}
		$output=$output."<div class=\"chapter\">";
	    }
	    $counters{section}=0;
	    $counters{subsection}=0;
	    $counters{subsubsection}=0;
	    $counters{equation}=0;
	    $counters{figure}=0;
	    $counters{table}=0;
	} 
	elsif($command eq "section"){
		$counters{section}++;
		if($counters{subsubsection}>0){
		    $output="</div></div></div>";
		}
		elsif($counters{subsection}>0){
		    $output="</div></div>";
		}
		elsif($counters{section}>1){
		    $output="</div>";
		}
		$output=$output."<div class=\"section\">";

		$counters{subsection}=0;
		$counters{subsubsection}=0;

	} 
	elsif($command eq "subsection"){
		$counters{subsection}++;
		if($counters{subsubsection}>0){
		    $output="</div></div>";
		    } 
		elsif($counters{subsection}>1){
		    $output="</div>";
		}
		$output=$output."<div class=\"subsection\">";

		$counters{subsubsection}=0;
	} elsif($command eq "subsubsection"){
		$counters{subsubsection}++;
		if($counters{subsubsection}>1){
		    $output = "</div>";
		}
		$output=$output."<div class=\"subsubsection\">";
	} else {
#Since |\backslash{}paragraph| and its synonyms do not contribute to the document tree's structure, we do nothing for all other command names.
	}
	return $output;
}
#\subroutine{The |resetCounters| subroutine}
#This subroutine resets all of the counters to zero and closes any open sectioning divisions. The main processor calls it in three circumstances: when processing a |preface| environment in the front matter, when the user starts the appendices with the |\backslash{}appendix| command, and at the end of the |process| subroutine.
sub resetCounters{
	
    my $output;
    if($counters{subsubsection}>0){
	$output=$output."</div>";
    }
    if ($counters{subsection}>0){
	$output=$output."</div>";
    }
    if ($counters{section}>0){
	my @footnoteTableArray=&footnoteTable();
	my $footnoteTable="";
	if(@footnoteTableArray && $counters{chapter}==0){
	    $footnoteTable=join("\n",@footnoteTableArray);
	}
	$output=$output."</div>$footnoteTable";
    }
    if ($counters{chapter}>0){
	my @footnoteTableArray=&footnoteTable();
	my $footnoteTable="";
	if(@footnoteTableArray){
	    $footnoteTable=join("\n",@footnoteTableArray);
	}
	$output=$output."$footnoteTable</div>";
    }
    if ($counters{part}>0){
	$output=$output."</div>";
    }
#The next block handles the footnotes for the preface environment.
    if ($counters{section}==0 && $counters{chapter}==0){
	my @footnoteTableArray=&footnoteTable();
	my $footnoteTable="";
	if(@footnoteTableArray){
	    $footnoteTable=join("\n",@footnoteTableArray);
	}
	$output=$output."$footnoteTable";
    }

    $counters{part}=0;
    $counters{chapter}=0;
    $counters{section}=0;
    $counters{subsection}=0;
    $counters{subsubsection}=0;
    
    return $output;
}
#\function{The |footnoteTable| subroutine}
# The two subroutines above rely on |footnoteTable| to create a table of footnotes from the global variable |@footnotes| and to reset that global. We place each footnotes table within a division of the |"footnotes"| class.
sub footnoteTable{
    if(@footnotes){
	unshift @footnotes, "<div class=\"footnotes\">\n<hr/>\n<div class=\"footnotesLabel\"><span class=\"footnotesLabelAnchor\"></span></div>\n<table>\n";
	push @footnotes, "\n</table>\n</div>\n";
    } else {
    }
    my @output=@footnotes;
    @footnotes=();
    return @output;
}
#\subroutine{The |sectionNumberText| subroutine and its supporting subroutines}
# In a LaTeX, document a subsubsection might be labelled with a sectioning number like ``2.3.2'', which would indicate that it is the second subsubsection of the third subsection of the second section. This subroutine creates that text and embeds it and its components in appropriately classed spans. LaTeX also provides facilities for changing these numbers to Roman numbers (capital or small) or ordinary letters (again, capital or small). We leave the mimicry of that functionality to the document classes' Javascript code.
sub sectionNumberText{
	
	my $command=$_[0];	
#The subroutine begins with the generation of every possible number we could use. 
	my $partNumber=$counters{part};
	my $chapterNumber=$counters{chapter};
	my $sectionNumber=$counters{section};
	my $subsectionNumber=$counters{subsection};
	my $subsubsectionNumber=$counters{subsubsection};

#With the strings of cardinal numbers created, we can embed them into their eponymous spans and concatinate the results into the output. To keep the resulting xHTML at least somewhat readable, we do not include part or chapter numbers unless the corresponding counter exceeds zero.
	my $output;
	if($partNumber > 0 &&($command eq "part" || $command eq "chapter" || $command eq "section" || $command eq "subsection" || $command eq "subsubsection")){
	    $output = $output."<span class=\"partNumber\">".$partNumber."</span>";
	}
	if ($chapterNumber > 0 && ($command eq "chapter" || $command eq "section" || $command eq "subsection" || $command eq "subsubsection")){
	    $output = $output."<span class=\"chapterNumber\">".$chapterNumber."</span>";
	}
	if($command eq "section" || $command eq "subsection" || $command eq "subsubsection"){
	    $output=$output."<span class=\"sectionNumber\">".$sectionNumber."</span>";
	}
	if($command eq "subsection" || $command eq "subsubsection"){
	    $output = $output."<span class=\"subsectionNumber\">".$subsectionNumber."</span>";
	}
	if($command eq "subsubsection"){
	    $output=$output."<span class=\"subsubsectionNumber\">".$subsubsectionNumber."</span>";
	}
	return $output;
}

#\subroutine{The |appendix| subroutine}
#The final sectioning command requiring implementation is |\backslash{}appendix| This marks the boundary between the main text and any appendices. Its implementing subroutine accomplishes three tasks.
#\begin{itemize}
#\item changes the global indicator variable for appendix content to |1|, 
#\item calls |resetCounters| to set the section counters in |%counters| to zero and return a string closing any open sectioning divisions, and
#\item adds an empty |<div><span>...</span></div>| which the document class code can use to place a label marking the start of the appendices.
#\end{itemize}
sub appendix {
	my $argument = pop @_;
	my $options  = pop @_;
	my $command  = pop @_;

	$isInAppendix = 1;	
	my $output=&resetCounters;
	$output = "</p>\n".$output."\n<div id=\"appendixLabel\"><span id=\"appendixLabelAnchor\"></span></div>\n<p>";
	return $output;
}
#\subsubsection{Other Commands}
#
# Just as with the environment-implementing subroutines, we proceed through the subroutines that implement commands in order of their appearance in |%commands|.
#
#\subroutine{The |shebang| subroutine}
# The |\backslash{}shebang| command returns a procesed version the contents of the |\${}shebang| global variable. 
sub shebang {
    my $argument = pop @_;
    my $options  = pop @_;
    my $command  = pop @_;

    my $output=&process($shebang);
}
#\subroutine{The |accents| subroutine}
#Table 3.1 of \cite{lamport1994} lists 14 commands for accenting letters. Komments++ implements all of these commands and an additional one which places a ring above the character with Unicode replacement. For all but three of the accents, the Unicode standard gives symbols for commonly accented characters (e.g. vowels). If we cannot use these, then the command uses the requested accent's Unicode combining diacritical. Although the subroutine is long, it is not very involved. 
sub accents {

	my $argument = pop @_;
	my $options  = pop @_;
	my $command  = pop @_;

	my $output;

	#Check inputs.
	unless ( $command =~ m/(\`|\'|\^|\"|~|=|\.|t|u|v|H|b|d|r|c)/ ) {
		die "Internal kpp error: Incorrect command processing routine called.";
	}
	if     ($options)  { die "\\" . $command . " takes no options.\n"; }
	unless ($argument) {
		die "\\" . $command . " missing its mandatory argument.\n";
	}

	#Strip the argument's enclosing braces.
	$argument = &stripBraces($argument);

	#Check the argument length.
	if ( $command eq 't' ) {

		unless ( length($argument) == 2 ) {
			die "\\t requires an input of exactly two characters.\n";
		}
	}
	else {
		unless ( length($argument) == 1 ) {
			die "\\" . $command . " requires an input of one exactly character.\n";
		}
	}

#With the input checking completed, we can procede to work through the accents one-by-one. Unicode provides \`{A}, \`{a}, \`{E}, \`{e}, \`{I}, \`{i}, \`{O}, \`{o}, \`{U}, \`{u}, and a combining diacritical that we apply to other letters, as in \`{c}.
	if ( $command =~ m/\`/ ) {    
		if ( $argument =~ m/A/ ) {
			$output = "&#x00C0;";
		}
		elsif ( $argument =~ m/E/ ) {
			$output = "&#x00C8;";
		}
		elsif ( $argument =~ m/I/ ) {
			$output = "&#x00CC;";
		}
		elsif ( $argument =~ m/O/ ) {
			$output = "&#x00D2;";
		}
		elsif ( $argument =~ m/U/ ) {
			$output = "&#x00D9;";
		}
		elsif ( $argument =~ m/a/ ) {
			$output = "&#x00E0;";
		}
		elsif ( $argument =~ m/e/ ) {
			$output = "&#x00E8;";
		}
		elsif ( $argument =~ m/i/ ) {
			$output = "&#x00EC;";
		}
		elsif ( $argument =~ m/o/ ) {
			$output = "&#x00F2;";
		}
		elsif ( $argument =~ m/u/ ) {
			$output = "&#x00F9;";
		}
		else {
			$output = $argument . "&#x0300;";
		}
	}
#Next comes the acute accent. Unicode provides \'{A}, \'{a}, \'{E}, \'{e}, \'{I}, \'{i}, \'{O}, \'{o}, \'{U}, \'{u}, \'{Y}, \'{y}, and a combinging diacritical which we apply to other characters, like \'{c}.
	elsif ( $command =~ m/\'/ ) {
		if ( $argument =~ m/A/ ) {
			$output = "&#x00C1;";
		}
		elsif ( $argument =~ m/E/ ) {
			$output = "&#x00C9;";
		}
		elsif ( $argument =~ m/I/ ) {
			$output = "&#x00CD;";
		}
		elsif ( $argument =~ m/O/ ) {
			$output = "&#x00D3;";
		}
		elsif ( $argument =~ m/U/ ) {
			$output = "&#x00DA;";
		}
		elsif ( $argument =~ m/Y/ ) {
			$output = "&#x00DD;";
		}
		elsif ( $argument =~ m/a/ ) {
			$output = "&#x00E1;";
		}
		elsif ( $argument =~ m/e/ ) {
			$output = "&#x00E9;";
		}
		elsif ( $argument =~ m/i/ ) {
			$output = "&#x00ED;";
		}
		elsif ( $argument =~ m/o/ ) {
			$output = "&#x00F3;";
		}
		elsif ( $argument =~ m/u/ ) {
			$output = "&#x00FA;";
		}
		elsif ( $argument =~ m/y/ ) {
			$output = "&#x00FD;";
		}
		else {
			$output = $argument . "&#x0301;";
		}
	}
#The circumflex. Unicode provides \^{A}, \^{a}, \^{E}, \^{e}, \^{I}, \^{i}, \^{O}, \^{o}, \^{U}, \^{u}, \^{Y}, \^{y}, \^{G}, \^{g}, \^{J}, \^{j}, \^{S}, \^{s}, and a combining diacritical for circumflexing other characters, as in \^{c}.
	elsif ( $command =~ m/\^/ ) {
		if ( $argument =~ m/A/ ) {
			$output = "&#x00C2;";
		}
		elsif ( $argument =~ m/E/ ) {
			$output = "&#x00CA;";
		}
		elsif ( $argument =~ m/I/ ) {
			$output = "&#x00CE;";
		}
		elsif ( $argument =~ m/O/ ) {
			$output = "&#x00D4;";
		}
		elsif ( $argument =~ m/U/ ) {
			$output = "&#x00DB;";
		}
		elsif ( $argument =~ m/Y/ ) {
			$output = "&#x0176;";
		}
		elsif ( $argument =~ m/G/ ) {
			$output = "&#x011C;";
		}
		elsif ( $argument =~ m/J/ ) {
			$output = "&#x0134;";
		}
		elsif ( $argument =~ m/S/ ) {
			$output = "&#x015C;";
		}
		elsif ( $argument =~ m/a/ ) {
			$output = "&#x00E2;";
		}
		elsif ( $argument =~ m/e/ ) {
			$output = "&#x00EA;";
		}
		elsif ( $argument =~ m/i/ ) {
			$output = "&#x00EE;";
		}
		elsif ( $argument =~ m/o/ ) {
			$output = "&#x00F4;";
		}
		elsif ( $argument =~ m/u/ ) {
			$output = "&#x00FB;";
		}
		elsif ( $argument =~ m/y/ ) {
			$output = "&#x0177;";
		}
		elsif ( $argument =~ m/g/ ) {
			$output = "&#x011D;";
		}
		elsif ( $argument =~ m/j/ ) {
			$output = "&#x0135;";
		}
		elsif ( $argument =~ m/s/ ) {
			$output = "&#x015D;";
		}
		else {
			$output = $argument . "&#x0302;";
		}
	}
#The umlaut. Unicode provides \"{A}, \"{a}, \"{E}, \"{e}, \"{I}, \"{i}, \"{O}, \"{o}, \"{U}, \"{u}, \"{Y}, \"{y}, and a combining diacritical to umlaut other characters, as in \"{c}.
	elsif ( $command =~ m/\"/ ) {
		if ( $argument =~ m/A/ ) {
			$output = "&#x00C4;";
		}
		elsif ( $argument =~ m/E/ ) {
			$output = "&#x00CB;";
		}
		elsif ( $argument =~ m/I/ ) {
			$output = "&#x00CF;";
		}
		elsif ( $argument =~ m/O/ ) {
			$output = "&#x00D6;";
		}
		elsif ( $argument =~ m/U/ ) {
			$output = "&#x00DC;";
		}
		elsif ( $argument =~ m/Y/ ) {
			$output = "&#x0178;";
		}
		elsif ( $argument =~ m/a/ ) {
			$output = "&#x00E4;";
		}
		elsif ( $argument =~ m/e/ ) {
			$output = "&#x00EB;";
		}
		elsif ( $argument =~ m/i/ ) {
			$output = "&#x00EF;";
		}
		elsif ( $argument =~ m/o/ ) {
			$output = "&#x00F6;";
		}
		elsif ( $argument =~ m/u/ ) {
			$output = "&#x00FC;";
		}
		elsif ( $argument =~ m/y/ ) {
			$output = "&#x00FF;";
		}
		else {
			$output = $argument . "&#x0308;";
		}
	}
#The tilde. Unicode provides \~{A}, \~{a}, \~{O}, \~{o}, \~{n}, and a combining diacritical which we use for other characters, as in \~{c}.
	elsif ( $command =~ m/~/ ) {
		if ( $argument =~ m/A/ ) {
			$output = "&#x00C3;";
		}
		elsif ( $argument =~ m/O/ ) {
			$output = "&#x00D5;";
		}
		elsif ( $argument =~ m/a/ ) {
			$output = "&#x00E3;";
		}
		elsif ( $argument =~ m/o/ ) {
			$output = "&#x00F5;";
		}
		elsif ( $argument =~ m/n/ ) {
			$output = "&#x00F1;";
		}
		else {
			$output = $argument . "&#x0303;";
		}
	}
#The macron, also known as the ``bar''. Unicode provides \={A}, \={a}, \={E}, \={e}, \={I}, \={i}, \={O}, \={o}, \={U}, \={u}, \={Y}, \={y}, and a combining diacritical for other characters, as in \={c}.
	elsif ( $command =~ m/=/ ) {
		if ( $argument =~ m/A/ ) {
			$output = "&#x0100;";
		}
		elsif ( $argument =~ m/E/ ) {
			$output = "&#x0112;";
		}
		elsif ( $argument =~ m/I/ ) {
			$output = "&#x012A;";
		}
		elsif ( $argument =~ m/O/ ) {
			$output = "&#x014C;";
		}
		elsif ( $argument =~ m/U/ ) {
			$output = "&#x016A;";
		}
		elsif ( $argument =~ m/Y/ ) {
			$output = "&#x0232;";
		}
		elsif ( $argument =~ m/a/ ) {
			$output = "&#x0101;";
		}
		elsif ( $argument =~ m/e/ ) {
			$output = "&#x0113;";
		}
		elsif ( $argument =~ m/i/ ) {
			$output = "&#x012B;";
		}
		elsif ( $argument =~ m/o/ ) {
			$output = "&#x014D;";
		}
		elsif ( $argument =~ m/u/ ) {
			$output = "&#x016B;";
		}
		elsif ( $argument =~ m/y/ ) {
			$output = "&#x0233;";
		}
		else {
			$output = $argument . "&#x0304;";
		}
	}
#The dot. Unicode provides \.{A}, \.{a}, \.{E}, \.{e}, \.{I}, \.{O}, \.{o}, \.{C}, \.{c}, \.{Z}, \.{z}, and a combining diacritical for other characters, as in \.{c}.
	elsif ( $command =~ m/\./ ) {
		if ( $argument =~ m/A/ ) {
			$output = "&#x0226;";
		}
		elsif ( $argument =~ m/E/ ) {
			$output = "&#x0116;";
		}
		elsif ( $argument =~ m/I/ ) {
			$output = "&#x0130;";
		}
		elsif ( $argument =~ m/O/ ) {
			$output = "&#x022E;";
		}
		elsif ( $argument =~ m/C/ ) {
			$output = "&#x010A;";
		}
		elsif ( $argument =~ m/Z/ ) {
			$output = "&#x017B;";
		}
		elsif ( $argument =~ m/a/ ) {
			$output = "&#x0227;";
		}
		elsif ( $argument =~ m/e/ ) {
			$output = "&#x0117;";
		}
		elsif ( $argument =~ m/o/ ) {
			$output = "&#x022F;";
		}
		elsif ( $argument =~ m/c/ ) {
			$output = "&#x010B;";
		}
		elsif ( $argument =~ m/z/ ) {
			$output = "&#x017C;";
		}
		else {
			$output = $argument . "&#x0307;";
		}
	}
#The Breve. Unicode provides \u{A}, \u{a}, \u{E}, \u{e}, \u{I}, \u{i}, \u{O}, \u{o}, \u{U}, \u{u}, and a combining diaritical for other characters, as in \u{c}.
	elsif ( $command =~ m/u/ ) {
		if ( $argument =~ m/A/ ) {
			$output = "&#x0102;";
		}
		elsif ( $argument =~ m/E/ ) {
			$output = "&#x0114;";
		}
		elsif ( $argument =~ m/I/ ) {
			$output = "&#x012C;";
		}
		elsif ( $argument =~ m/O/ ) {
			$output = "&#x014E;";
		}
		elsif ( $argument =~ m/U/ ) {
			$output = "&#x016C;";
		}
		elsif ( $argument =~ m/a/ ) {
			$output = "&#x0103;";
		}
		elsif ( $argument =~ m/e/ ) {
			$output = "&#x0115;";
		}
		elsif ( $argument =~ m/i/ ) {
			$output = "&#x012D;";
		}
		elsif ( $argument =~ m/o/ ) {
			$output = "&#x014F;";
		}
		elsif ( $argument =~ m/u/ ) {
			$output = "&#x016D;";
		}
		else {
			$output = $argument . "&#x0306;";
		}
	}
#The Caron, also known as the Hacek or simply ``check''. Unicode provides \v{A}, \v{a}, \v{E}, \v{e}, \v{I}, \v{i}, \v{O}, \v{o}, \v{U}, \v{u}, \v{C}, \v{c}, \v{D}, \v{N}, \v{R}, \v{S}, \v{Z}, and a combining diacritical for other characters, as in \v{c}.
	elsif ( $command =~ m/v/ ) {
		if ( $argument =~ m/A/ ) {
			$output = "&#x01CD;";
		}
		elsif ( $argument =~ m/E/ ) {
			$output = "&#x011A;";
		}
		elsif ( $argument =~ m/I/ ) {
			$output = "&#x01CF;";
		}
		elsif ( $argument =~ m/O/ ) {
			$output = "&#x01D1;";
		}
		elsif ( $argument =~ m/U/ ) {
			$output = "&#x01D3;";
		}
		elsif ( $argument =~ m/C/ ) {
			$output = "&#x010C;";
		}
		elsif ( $argument =~ m/D/ ) {
			$output = "&#x010E;";
		}
		elsif ( $argument =~ m/N/ ) {
			$output = "&#x0147;";
		}
		elsif ( $argument =~ m/R/ ) {
			$output = "&#x0158;";
		}
		elsif ( $argument =~ m/S/ ) {
			$output = "&#x0160;";
		}
		elsif ( $argument =~ m/Z/ ) {
			$output = "&#x017D;";
		}
		elsif ( $argument =~ m/a/ ) {
			$output = "&#x01CE;";
		}
		elsif ( $argument =~ m/e/ ) {
			$output = "&#x011B;";
		}
		elsif ( $argument =~ m/i/ ) {
			$output = "&#x01D0;";
		}
		elsif ( $argument =~ m/o/ ) {
			$output = "&#x01D2;";
		}
		elsif ( $argument =~ m/u/ ) {
			$output = "&#x01D4;";
		}
		elsif ( $argument =~ m/c/ ) {
			$output = "&#x010D;";
		}
		elsif ( $argument =~ m/n/ ) {
			$output = "&#x0148;";
		}
		elsif ( $argument =~ m/r/ ) {
			$output = "&#x0159;";
		}
		elsif ( $argument =~ m/s/ ) {
			$output = "&#x0161;";
		}
		elsif ( $argument =~ m/z/ ) {
			$output = "&#x017E;";
		}
		else {
			$output = $argument . "&#x030C;";
		}
	}
#The accute (or Hungarian) umlaut. Unicode provides \H{O}, \H{o}, \H{U}, \H{u}, \H{Y}, \H{y}, and a combining diacritical for other characters, as in \H{c}.
	elsif ( $command =~ m/H/ ) {
		if ( $argument =~ m/O/ ) {
			$output = "&#336;";
		}
		elsif ( $argument =~ m/U/ ) {
			$output = "&#368;";
		}
		elsif ( $argument =~ m/Y/ ) {
			$output = "&#1266;";
		}
		elsif ( $argument =~ m/o/ ) {
			$output = "&#337;";
		}
		elsif ( $argument =~ m/u/ ) {
			$output = "&#369;";
		}
		elsif ( $argument =~ m/y/ ) {
			$output = "&#1267;";
		}
		else {
			$output = $argument . "&#x030B;";
		}
	}
#A bar \emph{under} the letter, as in \b{o}. Unicode provides no special glyphs for this accent, so we use the Unicode ``Combining Macron Below'' for all characters.
	elsif ( $command =~ m/b/ ) {
		$output = $argument . "&#x0331;";
	}
#A dot \emph{under} the letter, as in \d{a}. We implement this with the Unicode ``Combining Dot Below'' for all characters.
	elsif ( $command =~ m/d/ ) {
		$output = $argument . "&#x0323;";
	}
#The accenting command Komments++ adds to those provided by LaTeX puts a ring over the letter. Unicode provides \r{A}, \r{a}, \r{U}, \r{u}, and a combining diacritical for other letters, as in \r{c}.
	elsif ( $command =~ m/r/ ) {
		if ( $argument =~ m/A/ ) {
			$output = "&#x00C5;";
		}
		elsif ( $argument =~ m/U/ ) {
			$output = "&#x016E;";
		}
		elsif ( $argument =~ m/a/ ) {
			$output = "&#x00E5;";
		}
		elsif ( $argument =~ m/u/ ) {
			$output = "&#x016F;";
		}
		else {
			$output = $argument . "&#x030A;";
		}
	}
#The Cedilla. Unicode provides \c{C}, \c{c}, \c{K}, \c{k}, \c{L}, \c{l}, \c{N}, \c{n}, \c{R}, \c{r}, \c{S}, \c{s}, \c{T}, \c{t}, \c{G}, and a combining diacritical for other letters, as in \c{d}. Since the combining diacritical looks more pleasing than the custom characters is some fonts, we might choose to expand its use in future versions.
	elsif ( $command =~ m/c/ ) {    #Cedilla
		if ( $argument =~ m/C/ ) {    #Use the Unicode Cedilla Characters for C, K, L, N, R, S, T, and capital G.
			$output = "&#x00C7;";
		}
		elsif ( $argument =~ m/G/ ) {
			$output = "&#x0122;";
		}
		elsif ( $argument =~ m/K/ ) {
			$output = "&#x0136;";
		}
		elsif ( $argument =~ m/L/ ) {
			$output = "&#x013B;";
		}
		elsif ( $argument =~ m/N/ ) {
			$output = "&#x0145;";
		}
		elsif ( $argument =~ m/R/ ) {
			$output = "&#x0156;";
		}
		elsif ( $argument =~ m/S/ ) {
			$output = "&#x015E;";
		}
		elsif ( $argument =~ m/T/ ) {
			$output = "&#x0162;";
		}
		elsif ( $argument =~ m/c/ ) {
			$output = "&#x00E7;";
		}
		elsif ( $argument =~ m/k/ ) {
			$output = "&#x0137;";
		}
		elsif ( $argument =~ m/l/ ) {
			$output = "&#x013C;";
		}
		elsif ( $argument =~ m/n/ ) {
			$output = "&#x0146;";
		}
		elsif ( $argument =~ m/r/ ) {
			$output = "&#x0157;";
		}
		elsif ( $argument =~ m/s/ ) {
			$output = "&#x015F;";
		}
		elsif ( $argument =~ m/t/ ) {
			$output = "&#x0163;";
		}
		else {
			$output = $argument . "&#x0327;";
		}
	}
#The final accenting command is the tie, as in \t{oo}. We implement this with the Unicode Combining Double Inverted Breve. Neither Safari nor Firefox renders this well, so it is a candidate for improvement or deletion.
	elsif ( $command =~ m/t/ ) {
		my $first  = substr( $argument, 0, 1 );
		my $second = substr( $argument, 1, 1 );

		$output = $first . "&#x0361;" . $second;
	}
}
#\subroutine{|symbols|}
#\cite{lamport1994} lists the LaTeX commands for several non-English symbols in Table 3.2 and the commands for a handful of other useful symbols, including those for the LaTeX conrol characters, immediately below it. We implement these and several other symbols using the |symbols| subroutine. Its only task is to retrieve the appropriate Unicode character from |%symbolTable| and place it into the output.
sub symbols {

	my $argument = pop @_;
	my $options  = pop @_;
	my $command  = pop @_;

	my $output = $symbolTable{$command};
	unless($output){
	    die "Internal kpp error. Attempted to process symbol command without symbolTable entry.";
	}
	return $output;
}
#\subroutine{|typestyle|}
#LaTeX provides ten commands for changing the type style of their arguments. The Komments++ processor supports these commands by feeding their arguments to the |process| subroutine and then placing the output within |<span>...</span>| tags. The span's class indicates the chosen type style, and the document class is responsible for fulfilling the author's type style request.

sub typestyle {
	my $argument = pop @_;
	my $options  = pop @_;
	my $command  = pop @_;

	unless ( $command =~ m/(emph|textup|textit|textsl|textsc|textmd|textbf|textrm|textsf|texttt)/ ) {
		die "Internal kpp error.";
	}
	if     ($options)  { die "\\" . $command . " takes no options.\n"; }
	unless ($argument) {
		die "\\" . $command . " missing its mandatory argument.\n";
	}

	$argument=&stripBraces($argument);
	$processLevel++;
	$argument = &process($argument);
	$processLevel--;

	my $output = "<span class=\"" . $command . "\">" . $argument . "</span>";
	return $output;
}

#\subroutine{|semantics|}
#This subroutine implements semantic commands, like |info|, which simply place their arguments within appropriately classed |<span>|s.
sub semantics {

my $argument = pop @_;
	my $options  = pop @_;
	my $command  = pop @_;

	unless ( $command =~ m/^info$/ ) {
		die "Internal kpp error.";
	}
	unless ($argument) { die "\\$command missing its mandatory argument.\n"; }

        $argument=&stripBraces($argument);
        $argument=&process($argument);
        my $output = "<span class=\"$command\">$argument</span>";
        return $output;
}
#\subroutine{|images|}
#This subroutine implements the |image| command. Both commands yield an |<img>| tag referencing the given image file. The tag's class equals its calling command's name, so the document class files are responsible for centering the images inserted with |\backslash{}centeredimage|. Any accompanying command options get used as replacement text for the images.
sub images {
	my $argument = pop @_;
	my $options  = pop @_;
	my $command  = pop @_;
	
	my $output;

	unless ( $command =~ m/^image$/ ) {
		die "Internal kpp error.";
	}
	unless ($argument) { die "\\image missing its mandatory argument.\n"; }

#Search for image replacement text in the options, which is any string within standard quotation marks.
	my $replacementText="Image unavailable.";
	if($options=~s/(?<=")([^"]*)(?=")//){
	    $replacementText=$1;
	} 
#Search for a given scale, which is a number followed by a percentage sign.
	my $scale="100%";
	if($options=~s/(\d+%)//){
	    $scale=$1;
	}
	  
#Search for an alignment, either |left|, |right|, or |center| not within quotation marks.
	my $alignment="";
	if($options=~s/(?<!")\s*(left|center|right)\s*(?!")//){
	    $alignment=$1;
	}

	my $imageFile=&stripBraces($argument);
	my $output = "<img src=\"$imageFile\" alt=\"$replacementText\" class=\"$alignment"."$command\" width=\"$scale\"/>";
#Since aligned images produce a block-level elements, we close the preceeding paragraph and open a new one.
	if($alignment=~m/left|center|right/){
	    $output="</p>".$output."<p>";
	}
#Add the image file to the list of files to be zipped, if appropriate.
	unless ($imageFile =~ /^http/){
	    push @filesToBeZipped, $imageFile." ";
	}
#Return the output.
	return $output;
}
#\subroutine{|caption|}
#As in LaTeX, the |\backslash{}caption| command is used to create a caption for a float. Accordingly, its implementing subroutine throws an error if the global |\${}floatType| does not equal one of the three permissable types. Otherwise, it produces a caption with an appropriate float number. If the caption includes a |\backslash{}label| command, then its argument can be used to cross reference the float.
sub caption {
	my $argument = pop @_;
	my $options  = pop @_;
	my $command  = pop @_;

	my $output;
	my $label;

	if ( $floatType eq "None" ) {
		die "Fatal error: caption found outside of float.\nCaption argument: $argument \n";
	}

	$argument=&stripBraces($argument);
	$label = &label($argument);

	$processLevel++;
	$argument = &process($argument);
	$processLevel--;

	my $floatNumber;
	if ( $floatType eq "Figure"){
	    $floatNumber=$counters{figure};
	} elsif ($floatType eq "Table"){
	    $floatNumber=$counters{table};
	} elsif ($floatType eq "Box"){
	    $floatNumber=$counters{box};
	} else {
	    die "Internal kpp error. Caption command called with invalid global \$floatType equal to $floatType.\n";
	}
	$floatNumber='<span class="floatNumber">'.$floatNumber.'</span>';

	my $sectioningNumbers=&sectionNumberText("chapter");
	if ($label) {
		$reflabels{$label} = $sectioningNumbers.$floatNumber;
		$refappstat{$label} = $isInAppendix;
		$output = '</p><p class="caption" id="' . $label . '">' . $floatType . ' ' . $sectioningNumbers.$floatNumber.": ". $argument . '</p><p>';
	}
	else {
		$output = '</p><p class="caption">' . $floatType . ' ' .$sectioningNumbers.$floatNumber.': '. $argument . '</p><p>';
	}
	return $output;
}
#\subroutine{|url|}
#Komments++ provides the |\backslash{}url| command for inserting hyperlinks. This is the only command that takes an optional second argument. If the second argument is present, then it is used as ``covering'' text for the url. If it is absent, the hyperlink displays the url itself.
sub url {

	my $argument = pop @_;
	my $options  = pop @_;
	my $command  = pop @_;

	$argument =~ m/($matchingBraces)($matchingBraces)?/;
	my $target = &stripBraces($1);
	my $label  = &stripBraces($2);

#If the user has specified the optional label, then the output |<a>| tag gets its class set to |"coveredURL"|. Otherwise, its class equals |"nakedURL"|.
	my $output;
	if ($label) {
	    $processLevel++;
		$label = &process($label);
	    $processLevel--;
		$output = '<a href="' . $target . '" class = "coveredURL">' . $label . '</a>';
	}
	else {
		$label = $target;
		$output = '<a href="' . $target . '" class = "nakedURL">' . $label . '</a>';
	}
	return $output;
} 
#\subroutine{|footnote|}
# Just like its LaTeX counterpart, the |\backslash{}footnote| command's argument inserts a footnote marker at its location in the text and produces a footnote at the bottom of the page. Since Komments++ uses one long ``page'' on the screen, this might better be described as an endnote. However, we stick with convention. The argument may contain a |\backslash{}label| command, which creates a cross reference label for the footnote's number.
sub footnote {
	my $argument = pop @_;
	my $options  = pop @_;
	my $command  = pop @_;

	$argument = &stripBraces($argument);
	$processLevel++;
	$argument = &process($argument);
	$processLevel--;
#The footnote text itself goes into the global array |@footnotes|. The |incrementCounters| and |resetCounters| subroutines use this to create tables of footnotes. The subroutine returns xHTML code for the footnote marker in |$output|.
	my $footnotenumber = @footnotes + 1;
	my $output;
	if ($isInAppendix){
	    push @footnotes, '<tr id="AppendixChapter'.$counters{chapter}.'footnote'.$footnotenumber.'"><td class="footnoteNumber"><sup>'.$footnotenumber.'</sup></td><td class="footnoteContent">'.$argument.'</td></tr>'; 
	    $output = '<a href="#AppendixChapter'.$counters{chapter}.'footnote' . $footnotenumber.'" class="footnoteMarker"><sup>' . $footnotenumber . '</sup></a>';
	} else {
	    push @footnotes, '<tr id="Chapter'.$counters{chapter}.'footnote'.$footnotenumber.'"><td class="footnoteNumber"><sup>'.$footnotenumber.'</sup></td><td class="footnoteContent">'.$argument.'</td></tr>';
	    $output = '<a href="#Chapter'.$counters{chapter}.'footnote' . $footnotenumber . '" class="footnoteMarker"><sup>' . $footnotenumber . '</sup></a>';
	}

	return $output;
}
#\subroutine{|cite|}
#Just as in LaTeX, the |\backslash{}cite| command inserts a citation to a bibliographic reference. The |cite| subroutine gives these the class |"unfinished cite"| and fills them with their citation labels. In its final step, the |bodyPages| subroutine replaces these arguments with their appropriate references and changes their classes to |"cite"|.
sub cite {
	my $argument = pop @_;
	my $options  = pop @_;
	my $command  = pop @_;

	$argument=&stripBraces($argument);
	my $output = "<a href=\"#$argument\" class=\"unfinished cite\">$argument</a>";
	return $output;
}
#\subroutine{|ref|}
#The |\backslash{}ref| command inserts a citation to a cross-referenced document element. Its implemention parallels that of |\backslash{}cite|.
sub ref {
	my $argument = pop @_;
	my $options  = pop @_;
	my $command  = pop @_;

	$argument=&stripBraces($argument);
	my $output = "<a href=\"#$argument\" class=\"unfinished ref\">$argument</a>";
	return $output;
}
#\subroutine{|comments|}
#The final subroutine requiring our attention is |comments|. This implements the |\backslash{}openCommentBlock|, |\backslash{}closeCommentBlock|, and |backslash{}inlineComment| commands, which \emph{render the symbols for these operations for the language referenced in is argument.} This is obviously handy since such symbols have profound syntactic meaning in Komments++.
sub comments {

	my $argument = pop @_;
	my $options  = pop @_;
	my $command  = pop @_;

	my $output;
	$argument=&stripBraces($argument);

	unless ( $command =~
		m/^(closeCommentBlock|openCommentBlock|inlineComment)$/i )
	{
		die "Internal kpp error.";
	}
	
	if ($options)  { die "\\$command takes no options."; }
	
	unless ( $argument =~
		m/^(C|do|stata|f90|fortran|perl|pl|m|matlab|tex|latex)$/i )
	{
		die "Error: Unrecognized language key \"$argument\" for command \"$command\"";
	}
	
	if ( $argument =~ m/c/i ) {    #C
	    if ( $command =~ m/closeCommentBlock/i) { $output = "*/"}
	    if ( $command =~ m/openCommentBlock/i) { $output = "/*"}
	    if ( $command =~ m/inlineComment/i) { $output = "//"}
	} elsif ( $argument =~ m/(m|matlab)/i ) {    #Matlab
	    if ( $command =~ m/closeCommentBlock/i) { $output = "%}"}
	    if ( $command =~ m/openCommentBlock/i) { $output = "%{"}
	    if ( $command =~ m/inlineComment/i) { $output = "%"}
	} elsif ( $argument =~ m/(do|stata)/i ) {         #Stata
	    if ( $command =~ m/closeCommentBlock/i) { $output = "*/"}
	    if ( $command =~ m/openCommentBlock/i) { $output = "/*"}
	    if ( $command =~ m/inlineComment/i) { $output = "//"}
	} elsif ( $argument =~ m/(tex|latex)/i ) {         #LaTeX
	    if ( $command =~ m/closeCommentBlock/i) { $output = ""}
	    if ( $command =~ m/openCommentBlock/i) { $output = ""}
	    if ( $command =~ m/inlineComment/i) { $output = "%"}	    
	} elsif ( $argument =~ m/(f90|fortran)/i ) {         #Fortran
	    if ( $command =~ m/closeCommentBlock/i) { $output = ""}
	    if ( $command =~ m/openCommentBlock/i) { $output = ""}
	    if ( $command =~ m/inlineComment/i) { $output = "!"}	    
	} elsif ( $argument =~ m/(pl|perl)/i ) {         #Perl
	    if ( $command =~ m/closeCommentBlock/i) { $output = ""}
	    if ( $command =~ m/openCommentBlock/i) { $output = ""}
	    if ( $command =~ m/inlineComment/i) { $output = "#"}	    
	} else { die "Unknown file extension: $argument\n"; }

	return $output;
}
#\subsection{Front Matter}
#A document's front matter contains bibliographic information, and posssibly a document abstract or preface. The |frontMatter| subroutine takes care of creating this, and for this task it uses several commands that the main processor sends to the |returnNothing| subroutine. Just like with |bodyPages|, |frontMatter| begins with the concatination of its input into one long string and the declaration of local variables.
sub frontMatter {
	
	my $input=join("",@_);
	my @output;
	
	my $title;
	my $date;
	my $abstract;
	my $preface;
	my $dedication;
	my $copyrightnote;
	my $doi;
	my $coverart;
	my $classification;
	my @unionBugsOutput;
	my $unionBugParagraph;
	my @authors;
	my @authorsOutput;
	my @thanks;	
	my $thanks;
	my $thanksSymbol;
#Now, we are prepared to extract the abstract, preface, and bibliographic information from the document's source. The argument of the first |\backslash{}title| command encountered is used for the document's title. If the document contains no such command, then the filename gets typset as code for the title.
	if($input=~m/\\title($matchingBraces)/s){
	 	$title=$1;
	} else {
	    $title="|$fileName|";
	}
#The document's date comes from the first |\backslash{}date| command. If there is not one, then we set it to the current daily date in English.	
	if($input=~m/\\date($matchingBraces)/s){
		$date=$1;
	} else {
	    my @months=qw(January February March April May June July August September October November December);
	    my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdet)=localtime(time);
	    $year=$year+1900;
	    $date = "$months[$month] $mday, $year";
	}
#A dedication from the author or authors comes from the |dedication| enviroment.
	if($input=~m/\\begin\{dedication\}(.*)\\end\{dedication\}/s){
	    $dedication=$1;
	}
#The document's preface (if any) comes from the first |preface| environment.
	if($input=~m/\\begin\{preface\}(.*)\\end\{preface\}/s){
	    $preface=$1;
#The part and chapter commands are illegal in the preface.
	    if($preface=~m/(?<!\\)(\\part|\\chapter)/){
               die "\part or \chapter command in preface.";
            }
	}
#The document's abstract (if any) comes from the first abstract environment. All sectioning commands are illegal in the abstract. We enforce this restriction during processing below.
	if($input=~m/\\begin\{abstract\}(.*?)\\end\{abstract\}/s){
		$abstract=$1;
	} 
#Each of the document's authors should have a corresponding |\backslash{}author| command. The following loop (which relies on the familiar |\backslash{}G| anchor) extracts these into the |@authors| array.	
	while($input=~m/\G.*?\\author($matchingBraces)/cgs){
		push @authors, $1;
	}
#If the document contains no |\backslash{}author| commands, then we make the current user responsible. We place her or his login id within pipes so that it later gets typeset as code.
	unless (@authors>0){
	    push @authors, "|".getlogin()."|";
	}
#In Komments++, the logos and crests that litter our professional lives are called \emph{union bugs}, and the |\backslash{}unionbug| command includes them within the document. These get treated just like the |\backslash{}author| commands, except if none are present no default gets used.	The command takes an optional scale parameter, which should be followed by the percentage sign.
	while($input=~m/\G.*?\\unionbug((?:$matchingBrackets)?$matchingBraces)/gcs){
	    my $thisUnionBug=$1;
	    my $options;
	    my $scale="100%";
	    my $replacementText=" A Union Bug ";

	    if ($thisUnionBug =~ /$matchingBrackets/){
		$options=$&;
		$thisUnionBug=$'; #'

		if ($options =~ /\d+%/){
		    $scale=$&
		}
		if ($options =~ /(?<=")[^"]*(?=")/){
		    $replacementText=$&
		}
	    }
#Next, we process the given path to the union bug. If it is local, make it relative to the current file and add it to the list of files to be zipped.'
            $thisUnionBug=&stripBraces($thisUnionBug);
	    if ($thisUnionBug =~ /^http/)
	    {

	    }
	    else {
		push @filesToBeZipped, $thisUnionBug." ";
	    }
		
            push @unionBugsOutput,  "<img src=\"$thisUnionBug\" alt=\"$replacementText\" class=\"unionBug\" width=\"$scale\"/>";
	}
	    
#Some documents get assigned digital object identifiers (or doi's), which facilitates their long-term retrieval. This can be included in the front matter with the |\backslash{}doi| command. Since document's only get one doi, we only use the first one encountered.
	if($input=~m/\\doi($matchingBraces)/s){
	    $doi=$1;
	}
#Some documents have associated cover art. The |\backslash{}coverart| command indicates the source of any such artwork. Like the |\backslash{}unionbug| command, it takes an optional scale parameter.
	my $coverArtReplacementText="Cover Art";
	my $coverArtScale="100%";
	if($input=~m/\\coverart((?:$matchingBrackets)?$matchingBraces)/s){
	    $coverart=$1;
	    my $options;

	    if ($coverart =~ /$matchingBrackets/){
		$options=$&;
		$coverart=$'; #'

		if ($options =~ /\d+%/){
		    $coverArtScale=$&
		}
		if ($options =~ /(?<=")[^"]*(?=")/){
		    $coverArtReplacementText=$&
		}
	    }


	}
#Within some organizations, documents also recieve a classification, such as ``Top Secret''. The |\backslash{}classification| command includes this in the front matter.
	if($input=~m/\\classification($matchingBraces)/s){
	    $classification=$1;
	}
#Finally, the front matter may contain a copyright notice placed by the |\backslash{}copyrightnote| command. (Note that the |\backslash{}copyright| command produces the standard copyright \emph{symbol}, \copyright{}.)
	if($input=~m/\\copyrightnote($matchingBraces)/s){
	    $copyrightnote=$1;
	}
#This completes the extraction of abstract and bibliographic information, so its processing may commence. The processing |\${}title| begins by feeding it to the |thanks| subroutine. This returns an array with two elements. The first contains one table row (a |<tr>...</tr>| tag) for each |\\thanks| command in its input. If the authors were not thankful, then this is empty. The second is the title itself \emph{after} having been sent through the |process| subroutine. This includes includes the footnote reference symbol generated from a |\backslash{}thanks| command. We replace |\${}title| with this second element and add the first element to the |@thanks| array.
	if ($title) {
		$title=&stripBraces($title);
		my @thanksOutput=&thanks($title);

		$title=pop @thanksOutput;
		my $thisThanksEntry=pop @thanksOutput;
		if($thisThanksEntry){
		    push @thanks, $thisThanksEntry    
		}
	}
#Each element of |@authors| gets processed just like |\${}title| was. However, the processed author names are placed into |<span>...</span>| tags with class set to |"author"| and then filed away in |@authorsOutput|.
	foreach(@authors){
		my $thisAuthor=$_;
		$thisAuthor=&stripBraces($thisAuthor);
		my @thanksOutput=&thanks($thisAuthor);

		$thisAuthor=pop @thanksOutput;
		my $thisThanksEntry=pop @thanksOutput;
		
		push @authorsOutput, "<span class=\"author\">".$thisAuthor."</span>";
		if($thisThanksEntry){
		    push @thanks, $thisThanksEntry;
		}
	}
#The |\${}date|, |\${}abstract|, |\${}dedication|, |\${}copyrightnote| and |\${}classification| simply get put through |process|.			
	if ($date) {
	    $date=&stripBraces($date);
		
	    $processLevel++;
	    $environmentLevel++;
	    $date=&process($date);
	    $environmentLevel--;
	    $processLevel--;
	}

	if ($abstract){
	        
	    $processLevel++;
	    $environmentLevel++;
	    $abstract=&process($abstract);
	    $environmentLevel--;
	    $processLevel--;
	}

	if ($dedication){
	    $processLevel++;
	    $environmentLevel++;
	    $dedication=&process($dedication);
	    $environmentLevel--;
	    $processLevel--;
	}

	if($copyrightnote){
	    $copyrightnote=&stripBraces($copyrightnote);
		
	    $processLevel++;
	    $environmentLevel++;
	    $copyrightnote=&process($copyrightnote);
	    $environmentLevel--;
	    $processLevel--;
	}

	if ($classification){
	    $classification=&stripBraces($classification);
	    $processLevel++;
	    $classification=&process($classification);
	    $processLevel--;
	}
#The preface can have footnotes, which come at its end.
	if ($preface){
	    $preface=&process($preface);
	    my $footnotesAndClosingDivs=&resetCounters();
	    $preface=$preface.$footnotesAndClosingDivs;
	}
#If there is cover art that is not retrieved from the web, make its path relative if it is not already add it to the list of files to be zipped. In any case, create an image tag referencing the cover art.
	if ($coverart){
	    $coverart=&stripBraces($coverart);
	    if($coverart =~ /^http/){
	    }
	    else {
	        push @filesToBeZipped, $coverart." ";
	    }
	    $coverart= '<img src="'.$coverart.'" alt="'.$coverArtReplacementText.'" class="coverArt" width="'.$coverArtScale.'"/>';
	}
	
#Finally, we process |\${}doi| by placing it within an anchor tag. We make the anchor functional by prepending the DOI server.
	if($doi){
	    $doi=&stripBraces($doi);
	    $doi="<a href=\"http://dx.doi.org/".$doi."\">".$doi."</a>";
	}
#This completes the processing of the appendix and bibliographic information. We now assemble it into division with |id| equal to |"frontMatter"|.
	my @output;
	push @output, "<div id=\"frontMatter\">\n";
#We open the division with the title, which we put into a paragraph with |id| equal to |"documentTitle"|;
	push @output, "<p id=\"documentTitle\">$title</p>\n";
#The |"authorList"| paragraph collects the authors.
    	push @output, "<p id=\"authorList\">";
    	push @output, @authorsOutput;
    	push @output, "<\/p>\n";
#Any union bugs go into the |"unionBugs"| paragraph.	
	if (@unionBugsOutput){
	    push @output, "<p id=\"unionBugs\">";
	    push @output, @unionBugsOutput;
	    push @output, "<\/p>\n";
	}
#The |\${}date|, |\${}abstract|, |\${}preface|, and |\${}dedication| go into eponymous paragraphs.
	push @output, "<p id=\"documentDate\"> $date </p>\n";
#and any |\${}abstract| goes into the |"documentAbstract"| paragraph.	
	if($abstract){
		push @output, "<p id=\"documentAbstract\"> $abstract </p>\n";
	}
	if($preface){
	    push @output, "<div id=\"documentPreface\"> $preface </div>\n";
	}
	if($dedication){
	    push @output, "<p id=\"documentDedication\"> $dedication </p>\n";
	}
#Footnotes typically appear above one another at the bottom of the page, so we place the processed arguments of the |\backslash{}thanks| commands within |<table>...</table>| tags with |id| set to |"documentThanks"|.
	if(@thanks){
   		 push @output, "<table id=\"documentThanks\">\n";
		 push @output, @thanks;
		 push @output, "</table>\n";
	}
#A document copyright, a doi, and a classification directive all follow the table of thanks in eponymous paragraphs.	
	if($copyrightnote){
	    push @output, "<p id=\"documentCopyright\">";
	    push @output, $copyrightnote;
	    push @output, "</p>\n";
	}
	if($doi){
	    push @output, "<p id=\"doi\">";
	    push @output, $doi;
	    push @output, "</p>\n";
	}
	if($classification){
	    push @output, "<p id=\"classification\">";
	    push @output, $classification;
	    push @output, "</p>\n";
	}
	if($coverart){
	    push @output, "<p id=\"coverArt\">";
	    push @output, $coverart;
	    push @output, "</p>\n";
	}
	push @output, "</div>\n";
#This completes the |frontMatter| division's construction. Since its content can contain bibliographic citations and cross references, we go back over it filling these in just as we did in |bodyPages|. 
	my $outputLength = @output;
	my $i;
	for ( $i = 0 ; $i < $outputLength ; $i++ ) {    
		while ( $output[$i] =~ m/\<a href="#([^"]*)" class="unfinished cite"\>\1/ ) {    
			my $label = $1;
			if (exists $citelabels{$label}){
			    $output[$i] =~ s/class="unfinished cite"\>$label/class="cite"\>$citelabels{$label}/g;
			} else {
			    $output[$i] =~s/class="unfinished cite"\>$label/class="cite"\>$label(\?)/g;
			}
		}
	}
	for ( $i = 0 ; $i < $outputLength ; $i++ ) {                           
	    while ( $output[$i] =~ m/\<a href="#([^"]*)" class="unfinished ref"\>\1/ ) {     
		my $label = $1;
		my $temp = $&;
		if ($refappstat{$label} == 0 & exists $reflabels{$label}) {
		    $output[$i] =~ s/\<a href="#$label" class="unfinished ref"\>$label/\<a href="#$label" class="ref"\>$reflabels{$label}/g;
		} elsif ($refappstat{$label} == 1 & exists $reflabels{$label}) {
		    $output[$i] =~ s/\<a href="#$label" class="unfinished ref"\>$label/\<a href="#$label" class="appendixref"\>$reflabels{$label}/g;
		} elsif ($refappstat{$label} == 0) {
		    $output[$i] =~ s/\<a href="#$label" class="unfinished ref"\>$label/\<a href="#$label" class="ref"\>$label(\?)/g;
		} else {
		    $output[$i] =~ s/\<a href="#$label" class="unfinished ref"\>$label/\<a href="#$label" class="appendixref"\>$label(\?)/g;
		}
	    }
	}
	return @output;
}
#\subroutine{|thanks|}
#The |thanks| subroutine works as described above.
sub thanks{
	
	my $input=$_[0];
	my @output;
	my $thanksEntry;
	my $thanksSymbol;
	my $thanksRows="";
	$processLevel++;	
	$environmentLevel++;
       
	while($input=~/\\thanks($matchingBraces)/){
      		$thanksEntry=&stripBraces($1);
#The symbol that links this entry in the thanks table with the text gets taken off the top of |@thanksSymbols|.
        	$thanksSymbol=pop @thanksSymbols;
        	$thanksEntry=&process($thanksEntry); 			#Run the contents through process.
        	$thanksRows=$thanksRows."<tr><td class=\"thankssymbol\">$thanksSymbol</td><td class=\"thanks\">$thanksEntry</td></tr>\n"; #Create the entry for the thanks array.
        	$input=~s/\\thanks($matchingBraces)/<sup>$thanksSymbol<\/sup>/; #Replace the \thanks command with the relevant thanks symbol.
        	
    	} 
	push @output, $thanksRows;
	push @output, &process($input); #Process the input.
	$environmentLevel--;
    	$processLevel--;
    	return @output;
}
#\subsection{Comment-Free Code Display}
# The penultimate step in the document's creation is the fabrication of the |onlyCode| division, which displays all of the document's working code together without intervening commentary. It includes a |"workingCode"| class |<table>| to display all of the code of each file referenced in the document's construction.

sub onlyCode {

    my %input = @_;    
    my @output;
    my @comments = @{ $input{comments} };
    my @code     = @{ $input{code} };
    my @fileNames = @{ $input{fileNames}};
    my @lineNumbers = @{ $input{lineNumbers}};

    my $commentsLength = @{ $input{comments} }; 
    my $codeLength     = @{ $input{code} };
    
    #Looping variables.
    my $file;
    my $i;

#Recall that |readfile| puts an entry into |@filenames| each time a new file is opened and read. Since a given file can be included more than once, we need to remove duplicates from this list before constructing our code listing. The next loop does this.
    my @uniqueFiles;
    my %seen;
    foreach $file (@fileNames){

	unless($seen{$file}){
	    $seen{$file}=1;
	    push @uniqueFiles, $file;
	}
    }
#We open the division and construct one table of code for each file. This code closely parallels that used in |weave|. After running through all of the files, we close the division and return the output.
    push @output, "<div id=\"onlyCode\">\n";
    foreach $file (@uniqueFiles) {

	push @output, "<table class=\"workingCode\">\n";
	
	my $barNumber=0;	  #Counter to indicate the ``bar number'' (for shading) of each row of code.
	my $barClass="odd";       #Variable to indicate whether the current bar is odd or even.	

	for($i=0;$i<$codeLength;$i++){

	    if($fileNames[$i] eq $file and $code[$i]){

		if(int(($lineNumbers[$i]-1)/BARLINES) % 2){
		    $barClass="shaded";
		} else {
		    $barClass="unshaded";
		}
		
		push @output, "<tr class=\"$barClass\"><td class=\"fileName\">$fileNames[$i]</td><td class=\"lineNumber\">$lineNumbers[$i]</td><td class=\"workingCodeLine\">$code[$i]</td></tr>\n";

	    }

	}
	push @output, "</table>\n";
    }
    push @output, "</div>\n";
    return @output;
}
#\subsection{The xHTML Footer}
#Closing the document's |<body>| and |<html>| tags is the final task in its construction. This subroutine returns the text that does so within a single-element array.
sub xhtmlFooter {
	my @xhtmlFooter;
	push @xhtmlFooter, "</body>\n</html>";
	return @xhtmlFooter;
}
#
#\begin{bibliography}
#\bibitem[Friedl (2006)]{friedl2006} Friedl, Jeffrey E.F. 2006. \emph{Mastering Regular Expressions.} Third Edition. O'Reilly Media, Inc. Sebastopol, California.
#\bibitem[Lamport (1994)]{lamport1994} Lamport, Leslie. 1994. \emph{LaTeX: A Document Preparation System.} Second Edition. Addison-Wesley Publishing Company. Menlo Park, California.
#\end{bibliography}
