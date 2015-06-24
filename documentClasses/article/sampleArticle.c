//\documentclass{article}


/* \title{A Quick Introduction to Komments++\thanks{This sample article demonstrates many features of Komments++ in general and the article document class in particular.}} 
 \head{Quick Introduction to Komments++, Version 1.0} */
// \date{December 20, 2011}
//\author{Jeffrey R. Campbell\thanks{Lead Developer, Komments++}}
/* \begin{abstract}
This sample article demonstrates features of Komments++ in general and the article document class in particular. One of the most notable of these is the integration of mathematics, like $a^2+b^2=c^2$ with code like |float c = sqrt(a^2+b^2);|
\end{abstract}
\unionbug{../../logo.jpg}

*/

//\section{The code: $X$ \label{code}}
// Here is some random text.
#include<stdio.h>
//\subsection{The content:$Y$ \label{content}}
// Some text for this subsection.
//\subsection{The fluff\label{fluff}}
// blah blah blah $X_{X_{X_{X}}}$.
//\subsubsection{A subsubsection: $Z$}
int main(void){

    int x; //Here is a declaration of |x| as an integer.\footnote{There is disagreement about the proper symbol to use to indicate the set of integers.}
    printf("Hello world!\n"); //A test comment.
    /* The return statement is optional. */ 
    return 0; //And we are done.\footnote{The following text just tests some features of compp.}

}

/* A comment in the code that is escaped will display like this.  \esc */


//\section{Examples of |compp|}
/* The first example of displayed material in the LaTeX book is a quotation. Here are two from that book. For these, we use the |quote| environment.
\begin{quote}
Many people would rather learn about a program at their computer than by reading a book. \textit{Page 2 of } \cite{aw1994Lamport} 

The |tabular| environment makes it easy to draw tables with horizontal and vertical lines. Don't abuse this feature. Lines usually just add clutter to a table; they are seldom helpful. The numbered tables in this book do not contain a single line. \textit{Page 63 of } \cite{aw1994Lamport}
\end{quote}

LaTeX provides a second environment for displaying quotations, |quotation|. It differs from |quote| only by indenting each paragraph. Here is an example of its use.
\begin{quotation}
The calculus was the first achievement of modern mathematics and it is difficult to overestimate its importance. I think it defines more unequivocally than anything else the inception of modern mathematics; and the system of mathematical analysis, which is its logical development, still constitutes the greatest technical advance in exact thinking. \textit{John von Neumann}
\end{quotation}
*/

//Here is some \begin{code} inline code\end{code}.
//
/* This file tests the basics of compp processing of C language programs. It cost \euro0 to create. Let's see if it can make the \# sign. Next, show off the ability to display math, as with LaTeX.
\begin{displaymath}x^2+y^2=z^2\end{displaymath}
Of course, we can create hyperlinks. Here is one to the \url{http://www.chicagofed.org}{Federal Reserve Bank of Chicago}.
\paragraph{The lesser sectioning commands} There are several lesser sectioning commands available, including |\backslash{paragraph}|, |\backslash{function}|, and |\backslash{method}|.
*/

//\subsection{Image tests}
/* 
Here is a test image of the French flag. The |\backslash{image}| command loading it uses a relative path: \image{Icons-flag-fr.png}. The |\backslash{image}| command for this next test uses an absolute path name to load an image of the U.S. flag from |wikimedia.org|.  \image{http://upload.wikimedia.org/wikipedia/commons/7/7d/Icons-flag-us.png} 
*/
//
//Here is a test of the |\\centeredimage| command. It loads an image of Carl Sagan with a mock-up of the Viking lander. It should be centered and below this text.\centeredimage{Carl_Sagan_Viking.jpg} Notice that the centered image creates a new paragraph.



//\subsection{List tests}
/* \begin{dictionary} \item{One} One \item{Two} Two
\end{dictionary}
*/

/*
\begin{itemize}
\item \begin{math}A\end{math}
\item \begin{itemize} \item C \item D \end{itemize}
\end{itemize}
*/


/* \begin{itemize}
\item Test one
\item \begin{enumerate} \item First \item Second \end{enumerate}
\end{itemize}
*/


/* \begin{itemize}
\item Another test
\item \begin{dictionary} \item{Gnu} A fuzzy creature. \item{Gnat} A pest. \end{dictionary}
\end{itemize}
*/

/* \begin{enumerate}
\item \begin{dictionary} \item{Baseball} A sport. \item{Bat} A mammal. \end{dictionary} 
\item Another item
\end{enumerate}
*/

//\subsection{Float tests}
//\subsubsection{|Figures|}
// Here is some text placed before the |figure| environments.
// \begin{figure}
// \begin{hiddencode}
// \input[all code]{sin.c}
// \end{hiddencode}
//\caption{A C program to calculate the sin  of zero.\label{dummyLabel}}
// Hover over the first line to reveal the program. Point away from the program to hide it again.
// \end{figure}

//\begin{figure}
//\centeredimage{JohnvonNeumann-LosAlamos.gif}
// \caption{John von Neumann at Los Alamos}
//
// To view this picture's source, visit \url{http://commons.wikimedia.org/wiki/File:JohnvonNeumann-LosAlamos.gif}{Wikimedia Commons}.
// \end{figure}
// And here is some text placed after the figure environments.
//\subsubsection{Tables}
/* \begin{table}

\begin{tabular}[llll]
\euro & |\backslash{euro}| & \pounds & |\backslash{pounds}|\\
\$ & |\backslash{$}| & \yen & |\backslash{yen}| \\
\nis & |\backslash{nis}| & \won & |\backslash{won}| 
\end{tabular}

\caption{Available Currency Symbols.}
\end{table} */


//\subsection{Math Tests}
//\[
// a+b=c
// \] 

//\begin{equation}
// d+e=f
//\end{equation}

// Some inline math \(1+1\) equals $\sqrt{4}$.

// Here is some displayed code
// \begin{displaycode}[option]
// printf("%4.3f",x);
// \end{displaycode}

// Here is another numbered equation.
/* \begin{equation}
a^2+b^2=c^2
\label{triangle}
\end{equation}
*/

// Here is a tabular environment.
// \begin{tabular}[lcc]
// Variable & Coefficient & Standard Error \\ \hline
// Population & 1.0 & 0.0 \\
// Race  & -3.2 & 4.5 \\
// \cline{1-3} Total & -2.2 & 4.5 \\
//  Result & \multicolumn{2}{c}{Significant} 
//\end{tabular} 

/* Here is an equation array.
\begin{eqnarray}
 1 & = & E[mR] \\
 W\times u_1(C,N) & = & u_2(C,1-N)
\end{eqnarray}
*/

//Here is a reference to the good old days in Subsection \ref{fluff}.
//Here is some inline code: |printf(f1,blah)|.

/* Here is some displayed code:
 ||   int x;
   x=1;
   x++;||
 */

/* Here is another displayed code:
|| gen x= y+z ||
*/

/* Here is the bibliography
\begin{bibliography}
\bibitem[Campbell (1998)]{red1998Campbell} Campbell, Jeffrey R. 1998. Entry, Exit, Embodied Technology, and Business Cycles. \textit{Review of Economic Dynamics} \textbf{1}(2) 371-402.
\bibitem[Abbring and Campbell (2010)]{ecta2010AbbbringCampbell} Abbring, Jaap H. and Jeffrey R. Campbell. 2010. Last-In First-Out Oligopoly Dynamics. \textit{Econometrica} \textbf{80}(1) 1-25.
\bibitem[Lamport (1994)]{aw1994Lamport} Lamport, Leslie. 1994. The LaTeX Book. Addison-Wesley. 
\end{bibliography}
*/

