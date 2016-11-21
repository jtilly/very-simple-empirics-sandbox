%{ 
\documentclass{article} 
\title{Very Simple Markov-Perfect Industry Dynamics \thanks{We are grateful to Emanuel Marcu for his outstanding research assistance.}} 
\author{Jaap H. Abbring\thanks{CentER, Department of Econometrics \& OR, Tilburg University. E-mail: \url{mailto:jaap@abbring.org}{jaap@abbring.org}.}} 
\author{Jeffrey R. Campbell \thanks{Economic Research, Federal Reserve Bank of Chicago, and CentER, Tilburg University. E-mail: \url{mailto:jcampbell@frbchi.org}{jcampbell@frbchi.org}.}} 
\author{Jan Tilly \thanks{Department of Economics, University of Pennsylvania. E-mail: \url{jtilly@econ.upenn.edu}{jtilly@econ.upenn.edu}.}} 
\author{Nan Yang \thanks{Business School, National University of Singapore. E-mail: \url{yangnan@nus.edu.sg}{yangnan@nus.edu.sg}.}} 
 
\date{July, 2014} 
 
\begin{abstract} 
This software package lists and describes the programs 
used in \cite{acty2014}. 
\end{abstract} 
 
In this software package, we present \textsc{Matlab}   programs that implement 
the estimation algorithm introduced in  \cite{acty2014}. The whole package can 
be downloaded from  \url{http://jtilly.io/very-simple-markov-perfect/very-simple.zip}{here}. We 
show how to simulate a market level panel data set from our dynamic game. We 
then implement the nested fixed point (NFXP) algorithm and estimate the 
structural parameters from the simulated data. This code is intended to serve 
as a platform for replication, experimentation, and teaching. The code 
presented here is fully functional yet it focuses on the essentials and 
demonstrates the ease with which our methodology can be applied in practice. 
The code can be executed in \textsc{Matlab} by running the script 
\textbf{example.m}. 
 
This documentation is structured as follows. After discussing a collection of 
recurring variable structures, we first introduce the algorithm that 
computes the equilibrium value functions. This algorithm is implemented by 
the function \textbf{valueFunctionIteration.m}. We then introduce the 
likelihood functions required for the three step estimation procedure. These 
are implemented by the functions \textbf{likelihoodStep1.m}, 
\textbf{likelihoodStep2.m}, and \textbf{likelihoodStep3.m}. We then discuss 
all the necessary ingredients to generate data from the model. This is 
implemented by the function \textbf{dgp.m}. Lastly, we put all of the above 
together in \textbf{example.m}, where we create a synthetic sample and 
estimate the underlying primitives. 
 
\section{Equilibrium computation} 
 
This subsection explains how \textbf{valueFunctionIteration.m} can be used 
to compute the unique Markov-perfect equilibrium of our dynamic game. The 
equilibrium computation procedure that is described in the paper involves 
iterating on the post-entry value function (which is a contraction mapping) 
using the Bellman equation 
 
\begin{equation} 
v_E(n,c,w)=\max\{0,-\exp (w)+\rho\mathbb{E}[\pi(n,C')+v_E(\mu(n,C',W'),C',W')|C=c]\} \label{vE} 
\end{equation} 
 
where 
 
\begin{equation} 
\mu(n,c,w) \equiv n + \sum_{m=n+1}^{\check n} a_E(m, c, w) 
\end{equation} 
 
(not to be confused with the $\mu$ that denotes the mean of the growth of 
the demand process) gives the current number of firms plus the  number of 
next period's entrants. The equilibrium entry strategy $a_E(n,c,w)$ is 
given by 
 
\begin{equation} 
a_E(n,c,w) = \mathbf{1}[v_E(n,c,w)>\varphi \exp (w)]. 
\end{equation} 
 
The post-entry value function $v_E(n,c,w)$ is then computed recursively by 
iterating on (\ref{vE}) in decreasing order of the number of active firms, 
starting with the maximal number of active firms $\check n$. 
 
What we do here in the \textsc{Matlab} code follows the same reasoning, 
however, we iterate on the post-survival value function $v_S(n,c)$ that 
does not depend on $w$. This reduces the dimensionality of the value 
function iteration  and yields substantial computational benefits. We first 
derive the sequence of Bellman equations that characterizes the equilibrium 
post-survival value function $v_S(n,c)$. 
 
The post-survival value function is defined as the sum of next period's 
flow profit and next period's post-entry value function (both of which are 
discounted to the present by $\rho$), 
 
\begin{equation} 
v_S(n,c) =  \rho \mathbb E_{C',W'}\big[ \pi(n,C' )  + v_E(\mu(n, C', W'), C',W')  \big| C=c\big]. 
\end{equation} 
 
When combined with equation (10) from the paper, which we repeat here for 
convenience 
 
\begin{equation} 
v_E(n,c,w) =  \max\{0, -\exp(w) + v_S(n,c) \}, 
\end{equation} 
 
we obtain a recursive expression of the post-survival value function 
 
\begin{equation} 
v_S(n,c) =  \rho \mathbb E_{C',W'}\big[ \pi(n,C' )  + \max\{0, -\exp(W') + v_S(\mu(n, C', W'),C') \}  \big| C=c\big]. 
\end{equation} 
 
Since we assume that $W'$ is i.i.d., we can further rewrite this expression 
as: 
 
\begin{equation} 
v_S(n,c) = \rho \mathbb E_{C'}\big[ \pi(n,C' ) 
      + \mathbb E_{W'} \left[ \max\{0, -\exp(W') + v_S(\mu(n, C', W'),C') \} \right] \big| C=c\big] 
\label{vS} 
\end{equation} 
 
Recall the definitions of the entry and survival thresholds in equations 
(14) and (15) in the main text of the paper, which are reproduced here: 
 
\begin{equation} 
\begin{split} 
\bar{w}_{E}(n,c) &\equiv \log v_{S} \left( n,c \right) - \log \left(1+\varphi \right)  \\ 
\bar{w}_{S}(n,c) &\equiv \log v_{S} \left( n,c \right). 
\end{split} 
\end{equation} 
 
We use the convention that 
 
\begin{equation} 
\overline w_S(\check n +1, c) = 
\overline w_E(\check n +1, c) = 
\overline w_E(\check n, c) = -\infty. 
\end{equation} 
 
From Lemma 2, it follows that the thresholds satisfy the monotonicity 
property 
 
\begin{equation} 
\overline w_S(1, c)         \geq 
\overline w_E(1, c)         \geq \cdots \geq 
\overline w_S(n, c)         \geq 
\overline w_E(n, c)         \geq \cdots \geq 
\overline w_S(\check n,c)   > 
\overline w_E(\check n, c)    = 
\overline w_S(\check n +1, c) = 
\overline w_E(\check n +1, c) = -\infty. 
\end{equation} 
 
The thresholds also yield a convenient representation of the number of 
active firms post-entry, 
 
\begin{equation} 
\mu(n,c',w') = 
    \begin{cases} 
        n    &\text{ if }  \overline w_E(n+1, c')\leq w'\\ 
        n'>n &\text{ if }  \overline w_E(n'+1, c') \leq w' < \overline w_E(n',c'). 
    \end{cases} 
\end{equation} 
 
To compute the expectation with respect to $W'$ on the RHS of equation 
(\ref{vS}), we can distinguish three cases: 
 
\begin{itemize} 
 
\item $w'>\overline w_S(n, c')$: The number of currently active firms 
is too large. Firms will leave the market with positive probability (with 
zero expected continuation value). 
 
\item $\overline w_S(n, c')\geq w'>\overline w_E(n+1, c')$: All 
incumbents remain active, but there is no entry. 
 
\item $\overline w_E(n', c') \geq w' > \overline w_E(n'+1, c')$ for 
$n'>n$: All incumbents remain active and there will be $n'-n$ additional 
entrants. 
 
\end{itemize} 
 
We can then write $v_S(n,c)$ as 
 
\begin{equation} 
\begin{split} 
v_S(n,c) &=  \rho \mathbb E_{C'}\bigg[ \; &\pi(n,C' )  \\ 
         &+                               &\mathbb E_{W'}\big[ \left( -\exp(W') + v_S(n, C') \right) \mathbf 1 \left[ \overline w_E(n+1, C') \leq W' < \overline w_S(n, C') \right]  \\ 
         &+ \sum_{n'=n+1}^{\check n}      &\mathbb E_{W'}\big[ \left( -\exp(W') + v_S(n', C') \right) \mathbf 1 \left[ \overline w_E(n'+1, C') \leq W' < \overline w_E(n', C') \right]    \big| C=c\bigg], 
\end{split} 
\end{equation} 
 
which is equivalent to 
 
\begin{equation} 
\begin{split} 
v_S(n,c) &=  \rho \mathbb E_{C'}\bigg[ \; &\pi(n,C' ) - \mathbb E_{W'}\big[  \exp(W')  \mathbf 1 \left[ W' < \overline w_S(n, C') \right] \big] \\ 
         &+                               & v_S(n, C')  \Pr \left( \overline w_E(n+1, C') \leq W' < \overline w_S(n , C') \right)  \\ 
         &+     \sum_{n'=n+1}^{\check n}  & v_S(n', C') \Pr \left( \overline w_E(n'+1,C') \leq W' < \overline w_E(n', C') \right)  \big| C=c\bigg]. 
\end{split} 
\label{vS_2} 
\end{equation} 
 
The above is the key equation that we will use to numerically compute the 
equilibrium. Now, invoke the distributional assumption on $W$, 
 
\begin{equation} 
W \sim N(-\frac{1}{2}\omega^2,\omega^2 ), 
\end{equation} 
 
which gives us a closed form solution for the 
\url{http://en.wikipedia.org/wiki/Log-normal_distribution#Partial_expectation}{partial 
expectation}: 
 
\begin{equation} 
\mathbb E_{W'} \left[  \exp(W') \mathbf 1 \left[  W' < \overline w_S(n, C') \right] \right] = 
\left[ 1 - \Phi \left( \frac{ \frac{1}{2}\omega^2 - \log v_S(n,C')}{\omega} \right) \right] 
\label{partialExpectation} 
\end{equation} 
 
where $\Phi(\cdot)$ refers to the standard normal cumulative distribution 
function. Defining $\tilde \Phi[x] = \Phi\left[ \frac{x + 0.5\omega^2 
}{\omega} \right]$, the event probabilities in (\ref{vS_2}) are 
 
\begin{equation} 
\Pr \left( \overline w_E(n+1, C') \leq W' < \overline w_S(n, C')\right) \\ 
= \tilde \Phi\left[\log v_S(n,C')\right] - \tilde \Phi\left[\log v_S(n+1,C') - \log (1+\varphi) \right] 
\label{pSureSurvivalNoEntry} 
\end{equation} 
 
 
for the number of firms staying the same, and 
 
\begin{equation} 
\Pr \left( \overline w_E(n'+1, C') \leq W' < \overline w_E(n', C') \right) \\ 
= \tilde \Phi\left[\log v_S(n',C')-\log (1+\varphi) \right] - \tilde \Phi\left[\log v_S(n'+1,C') - \log(1+ \varphi) \right] 
\label{pEntrySet} 
\end{equation} 
 
for the case of entry. We now implement the value function iteration on 
equation (\ref{vS_2}) in \textsc{Matlab}. 
 
\input[2..end]{valueFunctionIteration.m} 
 
\section{Likelihood computation} 
 
Before turning to the computation of the likelihood, we first review the 
likelihood construction described in the paper. Suppose we have data for 
$\check r$ markets. Each market is characterized by $\check t$ observations 
that include the demand state $C_{t,r}$ and the number of active firms 
$N_{t,r}$. We wish to estimate the parameter vector 
 
\begin{equation} 
\theta \equiv (\theta_C, \theta_P, \theta_W) \equiv ( (\mu,\sigma), (k, \varphi), \omega ). 
\end{equation} 
 
The likelihood contribution of a single market-level observation, i.e. a 
transition from $(c, n)$ to $(c', n')$ for market $r$ is given by 
 
\begin{equation} 
\ell_{t+1,r}\left( \theta \right) = f_{N_{t+1,r},C_{t+1,r}} \left(n',c' | C_{t,r}=c,N_{t,r}=n;\theta_C,\theta_P,\theta_W \right) 
\end{equation} 
 
where $f_{N_{t+1,r},C_{t+1,r}}$ stands for the joint density of 
$(N_{t+1,r},C_{t+1,r})$ conditional on $(N_{t,r},C_{t,r})$. Notice that 
$C_{t+1,r}$ is drawn by nature according to $G_{C,r}(\cdot|C_{t,r})$ 
independently of $N_{t+1,r}$. Moreover, by the structure of the game, 
firms' decisions, which determine $N_{t+1,r}$, are made prior to the draw 
of $C_{t+1,r}$ and are therefore not affected by $C_{t+1,r}$. Hence, we can 
write the likelihood contribution as the product of the conditional 
densities: 
 
\begin{equation} 
\ell_{t+1,r}\left( \theta \right) 
= f_{C_{t+1,r}} \left(c' | C_{t,r}=c;\theta_C\right) \cdot f_{N_{t+1,r}} \left(n' | C_{t,r}=c,N_{t,r}=n;\theta_C,\theta_P,\theta_W \right) 
\end{equation} 
 
where $f_{C_{t+1,r}}$ and $f_{N_{t+1,r}}$ denote the conditional densities. 
The expression for the conditional density of $N_{t+1,r}$ is referred to in 
the paper as $p\left(N_{r,t+1}\;|\;N_{r,t},C_{r,t};\theta\right)$. That is, 
 
 
\begin{equation} 
f_{N_{t+1,r}} \left(n' | C_{t,r}=c,N_{t,r}=n;\theta_C,\theta_P,\theta_W \right) 
= \Pr(N_{r,t+1}=n'|N_{r,t}=n,C_{r,t}=c;\theta) \equiv p\left(N_{r,t+1}\;|\;N_{r,t},C_{r,t};\theta\right) 
\end{equation} 
 
The conditional density of $N_{t+1,r}$ is the probability that market $r$ 
with $n$ firms in demand state $c$ has $n'$ firms next period. Also, the 
conditional density of the demand process is given in the paper by the 
function $g_C$. That is, 
 
\begin{equation} f_{C_{t+1,r}} \left(c' | C_{t,r}=c;\theta_C\right) = 
g_C \left( C_{t+1,r} |C_{t,r}; \theta_C \right) 
\end{equation} 
 
The likelihood function is then defined as in the paper: 
 
\begin{equation} 
\mathcal{L}\left( \theta \right)= \mathcal{L}_C\left( \theta_C \right) \cdot \mathcal{L}_N\left( \theta \right) 
\end{equation} 
 
where 
 
\begin{equation} 
\mathcal{L}_C\left( \theta_C \right) = \prod_{r=1}^{\check r}  \prod_{t=1}^{\check t-1}  g_C \left( C_{t+1,r} |C_{t,r}; \theta_C \right) 
\end{equation} 
 
\begin{equation} 
\mathcal{L}_N\left( \theta \right) = \prod_{r=1}^{\check r} \prod_{t=1}^{\check t-1} p\left(N_{r,t+1}\; | \;N_{r,t},C_{r,t};\theta \right) 
\end{equation} 
 
 
$\mathcal{L}_C\left( \theta_C \right)$ can be calculated easily from demand 
data alone, with no need to solve the model, as $g_C \left( C_{t+1,r} 
|C_{t,r};\theta_C \right)$  translates to entries in the transition matrix 
of the demand process. In contrast, computing $\mathcal{L}_N\left( \theta 
\right)$ requires solving for the equilibrium of the model. 
 
The three-steps estimation procedure is as described in 
\cite{ecta1987Rust}: 
 
\begin{itemize} 
 
\item \textbf{ Estimate $\theta_C$ with $\tilde\theta_C\equiv\arg 
\max_{\theta_C}{\cal L}_C(\theta_C)$;} 
 
\item \textbf{ estimate $(\theta_P,\theta_W)$ with 
$(\tilde\theta_P,\tilde\theta_W)\equiv\arg\max_{(\theta_P,\theta_W)}{\cal 
L}_N(\theta_P,\tilde\theta_C,\theta_W)$; and } 
 
\item \textbf{ estimate $\theta$ by maximizing the full likelihood function 
$\hat\theta\equiv\arg\max_\theta{\cal L}(\theta)$, using 
$\tilde\theta\equiv(\tilde\theta_P,\tilde\theta_C,\tilde\theta_W)$ as 
starting value.} 
 
\end{itemize} 
 
The first two steps are thus used for providing starting values for the 
full information maximum likelihood (FIML) in step 3. As can be seen from 
experimenting with the code, the first two steps provide very good starting 
values for the FIML, which therefore converges after only a small number of 
iterations. Note that it is the second step which gives the procedure the 
name NXFP: solving the model entails solving for the fixed point of the 
value functions, and this is nested within the iterative optimization to 
find the maximum likelihood. 
 
The starting values for the first step are directly calculated from the 
data as the mean and standard deviation of the  innovations of logged 
demand. The starting values for $\theta_P$ and $\theta_W$ in the second 
step are randomly drawn from a uniform distribution with support $[1,5]$. 
 
The next subsections describe each of the three steps. Standard errors are 
computed using the outer-product-of-the-gradient method. Since the FIML is 
asymptotically efficient, while the estimators in the first two steps are 
not, we only discuss the computation of standard errors in the third step. 
 
\subsection{\textbf{likelihoodStep1.m} - Estimating $\theta_C = \left( 
\mu, \sigma \right)$} 
 
 
\input[2..end]{likelihoodStep1.m} 
 
\subsection{\textbf{likelihoodStep2.m} - Estimating $\left( 
\theta_P,\theta_W \right) = \left( (k, \varphi), \omega \right)$} 
 
This function computes the second step likelihood function. 
 
\input[2..end]{likelihoodStep2.m} 
 
\subsection{\textbf{likelihoodStep3.m} - Full Information Likelihood} 
 
\input[2..end]{likelihoodStep3.m} 
 
\section{Data generating process} 
 
Here we describe how to generate a synthetic sample with firms and 
consumers for $\check r $ markets and $\check t $ time periods. The data 
generation process consists of three functions. 
 
\begin{itemize} 
 
\item \textbf{randomFirms.m} draws a vector of length $\check r$ with the 
number of firms next period $n'$ given the current realizations of demand 
$c$, cost shocks $w$, and the number of incumbents $n$. 
 
\item \textbf{mixingProbabilities.m} computes the purely mixed strategy 
survival probabilities. 
 
\item \textbf{dgp.m} puts the above functions together and returns a 
synthetic data set. 
 
\end{itemize} 
 
\subsection{\textbf{randomFirms.m}} 
 
\input[2..end]{randomFirms.m} 
 
\subsection{\textbf{mixingProbabilities.m}} 
 
\input[2..end]{mixingProbabilities.m} 
 
\subsection{\textbf{dgp.m}} 
 
\input[2..end]{dgp.m} 
 
The next section discusses how the three likelihood functions and the data 
generating function are used in the NFXP procedure. 
 
\section{The example script: \textbf{example.m}} 
\input[1..end]{example.m} 
 
 
\section{Appendix A: List of Structures} 
 
Throughout the Matlab code, the structures |Settings|, |Param|, and |Data| 
play an important role. We define their contents in this section. 
 
\subsection{|Settings|} 
 
The structure |Settings| contains parameters that govern the execution of 
the \textsc{Matlab}. All elements in  |Settings| need to be defined by hand 
and remain constant throughout the  execution of the program. 
 
\begin{itemize} 
 
\item |Settings.tolInner| the real valued tolerance for the inner loop of 
the NFXP. 
 
\item |Settings.tolOuter| the real valued tolerance for the outer loop of 
the NFXP. 
 
\item |Settings.maxIter| the integer valued maximum number of iterations 
the inner loop of the NXP may take before it throws an error. 
 
\item |Settings.nCheck| the integer valued maximum number of firms that the 
market can sustain, $\check n$. 
 
\item |Settings.cCheck| the integer valued number of support points that 
the demand process can take on. 
 
\item |Settings.lowBndC| is the real valued lower bound of the demand grid. 
 
\item |Settings.uppBndC| is the real valued upper bound of the demand grid. 
 
\item |Settings.logGrid| is a row vector of length |Settings.cCheck| with 
the logged demand grid. 
 
\item |Settings.d| is the real valued distance between two points on the 
logged demand grid. 
 
\item |Settings.rCheck| is the integer valued number of markets for which 
we have or simulate data, $\check r$. 
 
\item |Settings.tCheck| is the integer valued number of time periods for 
which we or simulate have data, $\check t$. 
 
\item |Settings.tBurn| is the integer valued number of burn in periods used 
during the simulation. 
 
\item |Settings.fdStep| is the real valued step size used to compute finite 
differences, when we compute the score of the likelihood function. 
 
\item |Settings.truncOrder| is the integer valued of points used for the 
Gauss-Legendre integration. 
 
\item |Settings.integrationNodes| is the real valued row vector of length 
|Settings.truncOrder| with Gauss-Legendre nodes. 
 
\item |Settings.integrationWeights| is the real valued row vector of length 
|Settings.truncOrder| with Gauss-Legendre weights. 
 
\item |estimates2k(x)| is an anonymous function that maps the argument --- 
a vector of estimates |x| --- into the vector valued outcome |Param.k|, 
which will be defined below. 
 
\item |estimates2phi(x)| is an anonymous function that maps the argument 
--- a vector of estimates |x| --- into the vector valued outcome 
|Param.phi|, which will be defined below. 
 
\item |estimates2omega(x)| is an anonymous function that maps the argument 
--- a vector of estimates |x| --- into the real valued outcome 
|Param.omega|, which will be defined below. 
 
\end{itemize} 
 
\subsection{|Param|} 
 
The structure |Param| contains the primitives of the model. 
 
\begin{itemize} 
 
\item |Param.rho| is the real valued discount factor. 
 
\item |Param.k| is a real valued row vector of length |Settings.nCheck| 
that parameterizes the surplus function, $k(n)$. 
 
\item |Param.phi| is a real valued row vector of length |Settings.nCheck| 
that parameterizes the median of the entry costs, $\varphi(n)$. 
 
\item |Param.omega| is a real and parameterizes the scale, $\omega$, of the 
cost shock distribution. 
 
\item |Param.demand.mu| is a real and parameterizes the mean, $\mu$, of the 
log innovations of the demand process. 
 
\item |Param.demand.sigma| is a real and parameterizes the standard 
deviation, $\sigma$, of the log innovations of the demand process. 
 
\item |Param.demand.transMat| is a real valued transition probability 
matrix of the demand process, which is of size |Settings.cCheck| by 
|Settings.cCheck|. 
 
\item |Param.demand.ergDist| is a real valued column vector of length 
|Settings.cCheck| with the ergodic distribution of the demand process. 
 
\item |Param.truth.step1| is a real valued row vector with the true 
parameter values for the first step in the three-step estimation procedure 
during the Monte Carlo simulation. 
 
\item |Param.truth.step2| is a real valued row vector with the true 
parameter values for the second step in the three-step estimation procedure 
during the Monte Carlo simulation. 
 
\item |Param.truth.step3| is a real valued row vector with the true 
parameter values for the third step in the three-step estimation procedure 
during the Monte Carlo simulation. 
 
\end{itemize} 
 
\subsection{|Data|} 
 
The structure |Data| contains the following elements. 
 
\begin{itemize} 
 
\item |Data.C| is an integer valued matrix of size |Settings.tCheck| by 
|Settings.rCheck|, where each element |(t,r)| contains the index of the 
logged demand grid that describes the demand state in market |r| at time 
|t|. 
 
\item |Data.N| is an integer valued matrix of size |Settings.tCheck| by 
|Settings.rCheck|, where each element |(t,r)| contains the number of active 
firms in market |r| at time |t|. 
 
\item |Data.W| is a real valued matrix of size |Settings.tCheck| by 
|Settings.rCheck| that contains the cost shocks that are generated in the 
Monte Carlo simulation. 
 
\end{itemize} 
 
\section{Appendix B: Auxiliary Functions} 
 
This Part of the appendix contains descriptions of all auxiliary functions used that were not described above. 
 
\subsection{\textbf{markov.m}} 
 
\input[2..end]{markov.m} 
 
\subsection{\textbf{randomDiscr.m}} 
 
\input[4..end]{randomDiscr.m} 
 
\subsection{\textbf{lgwt.m}} 
 
\input[4..end]{lgwt.m} 
 
\begin{bibliography} 
\bibitem[Abbring et al. (2014)]{acty2014} Abbring, J. H., J. R. Campbell, J. Tilly, N. Yang (2014): "\url{http://papers.ssrn.com/sol3/papers.cfm?abstract_id=2379468}{Very Simple Markov-Perfect Industry Dynamics}," \textit{CentER Discussion Paper Series} No. 2014-008. 
\bibitem[Dube et al. (2012)]{ecta2012DubeFoxSu} Dube, J.-P., J. T. Fox, and C.-L. Su (2012): "\url{http://onlinelibrary.wiley.com/doi/10.3982/ECTA8585/abstract}{Improving the Numerical Performance of Static and Dynamic Aggregate Discrete Choice Random Coefficients Demand Estimation}," \textit{Econometrica}, 80, 2231-2267. 
\bibitem[Rust (1987)]{ecta1987Rust} Rust, J. (1987): "\url{http://www.hss.caltech.edu/~mshum/stats/rust.pdf}{Optimal Replacement of GMC Bus Engines: An Empirical Model of Harold Zurcher}," \textit{Econometrica}, 55, 999-1033. 
\bibitem[Tauchen (1986)]{el1986Tauchen} Tauchen, G. (1986): "\url{http://www.sciencedirect.com/science/article/pii/0165176586901680}{Finite State Markov-Chain Approximations to Univariate and Vector Autoregressions}," \textit{Economic Letters}, 20, 177-181. 
\end{bibliography} 
%} 
