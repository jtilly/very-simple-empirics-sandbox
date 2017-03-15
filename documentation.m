%{
\documentclass{article}
\title{Matlab Documentation for Very Simple Markov-Perfect Industry Dynamics: Empirics\thanks{We thank Emanuel Marcu for excellent research assistance.}}

\author{Jaap H. Abbring\thanks{CentER, Department of Econometrics \& OR, Tilburg University. E-mail: \url{mailto:jaap@abbring.org}{jaap@abbring.org}.}}
\author{Jeffrey R. Campbell \thanks{Economic Research, Federal Reserve Bank of Chicago, and CentER, Tilburg University. E-mail: \url{mailto:jcampbell@frbchi.org}{jcampbell@frbchi.org}.}}
\author{Jan Tilly \thanks{Department of Economics, University of Pennsylvania. E-mail: \url{jtilly@econ.upenn.edu}{jtilly@econ.upenn.edu}.}}
\author{Nan Yang \thanks{Business School, National University of Singapore. E-mail: \url{yangnan@nus.edu.sg}{yangnan@nus.edu.sg}.}}

\date{March 2017}
\head{Very Simple Markov-Perfect Industry Dynamics: Empirics}

\begin{abstract} This software package lists and describes the programs
used in \cite{acty2017b}.\end{abstract}

In this software package, we present \textsc{Matlab} programs that
implement the estimation algorithm introduced in \cite{acty2017b} using
simulated data. This software package is intended to serve as a platform
for replication, experimentation, and teaching. The entire package can be
downloaded from
\url{http://jtilly.io/very-simple-markov-perfect/very-simple.zip}{here}.
The code can be executed in \textsc{Matlab} by running the script
|example.m|.

This documentation is structured as follows. First, we briefly review the
model presented in \cite{acty2017b}, which is a special case of the model
presented in \cite{acty2017a}. Second, we introduce the algorithm that
computes the equilibrium and show how to compute the model's likelihood
function. Third, we discuss all the necessary ingredients to generate data
from the model. Fourth, we put all of the above together in the script
|example.m|, where we create a synthetic sample and estimate the underlying
primitives.

\section{Model}

Consider a local market. Time is discrete and indexed by
$t\in\mathbb{N}\equiv\{1,2,\ldots\}$. In period $t$, firms that have
entered in the past and not yet exited serve the market. We name each firm
$f\in{\cal F}\equiv\left(\{0\}\cup\mathbb{N}\right)\times\mathbb{N}$. The
first component of a firm's name gives the date in which it has its only
opportunity to enter the market, and the second component is its order in
that date's entry queue. Firms are identical except for the timing of their
entry opportunities.

We divide each period into two subperiods, the entry and survival stages.
Period $t$ begins on the left with the entry stage. If $t=1$, nature sets
the number $N_1$ of firms serving the market in period $1$, their names
$(0,1),\ldots,(0,N_1)$ if $N_1>0$, and the initial demand state $C_1$. If
$t>1$, these are inherited from the previous period. We assume that $C_t$
follows a first-order Markov process and denote its support with $\cal C$.
Throughout the paper, we refer to $C_t$ as ``demand,'' but it can encompass
any observed, relevant, and time-varying characteristics of the market,
depending on the empirical context. In our empirical application, $C_t$ is
the local market's residential population.

Each incumbent firm serves the market and earns a surplus $\pi(N_t,C_t)$.
We assume that \begin{itemize} \item $\exists \check{\pi}<\infty$ such that
$\forall (n,c)\in\mathbb{N}\times\cal C$,
$\mathbb{E}[\pi(n,C^\prime)|C=c]\leq\check{\pi}$; \item $\exists
\check{n}\in\mathbb{N}$ such that $\forall n>\check{n}$ and $\forall
c\in\cal C$, $\pi(n,c) = 0$; and \item $\forall
(n,c)\in\mathbb{N}\times\cal C$, $\pi(n,c) \geq \pi(n+1,c)$. \end{itemize}
Here and throughout; we denote the next period's value of a generic
variable $Z$ with $Z^\prime$, random variables with capital Roman letters,
and their realizations with the corresponding small Roman letters. The
first assumption is technical and allows us to restrict equilibrium values
to the space of bounded functions. The second assumption allows us to
restrict equilibrium analysis to markets with at most $\check{n}$ firms. It
is not restrictive in empirical applications to oligopolies. The third
assumption requires the addition of a competitor to reduce weakly each
incumbent's surplus.

After incumbents earn their surpluses, nature draws the current period's
shock to continuation and entry costs, $W_t$, from a distribution $G_W$
with positive density everywhere on the real line. Then, period $t$'s
cohort of potential entrants $\{t\}\times\mathbb{N}$ make entry decisions
in the order of the second component of their names. We denote firm $f$'s
entry decision with $a^f_E\in\left\{0,1\right\}$. An entrant ($a^f_E=1$)
pays the sunk cost $\varphi \exp(W_{t})$, with $\varphi>0$. A firm choosing
not to enter ($a^f_E=0$) earns a payoff of zero and never has another entry
opportunity. Such a refusal to enter also ends the entry stage, so firms
remaining in this period's entry cohort that have not yet had an
opportunity to enter \emph{never} get to do so. Since the next firm in line
faces exactly the same choice as did the firm that refused to enter, it
will make the same refusal decision in any symmetric equilibrium. Since
every period has at least one firm refusing an available entry opportunity,
the model is one of free entry.

We denote the number of firms in the market after the entry stage, the sum
of the incumbents and the actual entrants, with $N_{E,t}$. Suppose that the
names of these active firms are $f_1,\ldots,f_{N_{E,t}}$. In the subsequent
survival stage, they simultaneously decide on continuation with
probabilities $a_S^{f_1},\ldots, a_S^{f_{N_{E,t}}}\in[0,1]$. After these
decisions, all survival outcomes are realized independently across firms
according to the chosen Bernoulli distributions. Firms that survive pay a
fixed cost $\exp(W_t)$. A firm can avoid this cost by exiting to earn zero.
Firms that have exited cannot reenter the market later. The $N_{t+1}$
surviving firms continue to the next period, $t+1$. The period ends with
nature drawing a new demand state $C_{t+1}$ from the conditional
distribution $G_C(\cdot\; | \;C_t)$. All firms discount future profits and
costs with the discount factor $\rho\in[0,1)$.

we will assume that, for each market, the data contain information on
$N_t$, $C_t$, and possibly some time-invariant market characteristics $X$
that shift the market's primitives. The market-level cost shocks $W_t$ are
not observed by the econometrician and serve as the model's structural
econometric errors. Because they are observed by all firms and affect their
payoffs from entry and survival, they make the relation between the
observed demand state $C_t$ and the market structure $N_t$ statistically
nondegenerate.

The assumptions on $\{C_t, W_t\}$ make it a first-order Markov process
satisfying a conditional independence assumption. This ensures that the
distribution of $(N_{t},C_{t})$ conditional on $(N_{t^\star},C_{t^\star})$
for all ${t^\star}<t$ depends only on $(N_{t-1},C_{t-1})$, so we require
only the model's transition rules to calculate the conditional likelihood
function.

\subsection{Value Functions and Entry Rules}

We begin by implementing the computational algorithm to compute the equilibrium
value functions that we present in the paper. The post-survival value function
$v_S(n,c)$ is computed recursively by iterating on a sequence of Bellman
equations.

Recall the definitions of the entry thresholds in the paper,

\begin{equation} \overline w_{E}(n,c) = \log v_{S}\left(n, c\right) -
\log\left(1 + \varphi\right). \end{equation}

The post-survival value function is given by

\begin{equation} \begin{split} v_S(n, c) = \rho \mathbb E\big[
\pi(\check{n}, C')\; +&\int_{\overline{w}_E(n + 1, C')}^{\log v_S(n, C')}
&\left(- \exp(w) + v_S(n, C')\right) d G_W(w) \\ + \sum_{n' =
n+1}^{\check n}\;&\int_{\overline{w}_E(n' + 1, C')}^{\overline{w}_E(n',
C')} &\left(- \exp(w) + v_S(n', C')\right) d G_W(w) \big| C=c\big],
\end{split} \label{vS_2} \end{equation}

The above is the key equation that we will use to numerically compute the
equilibrium. First, we consolidate the econometric error and obtain

\begin{equation} \begin{split} v_S(n, c) = \rho \mathbb E\big[
\pi(\check{n}, C')\; +&v_S(n, C') \int_{\overline{w}_E(n + 1, C')}^{\log
v_S(n, C')}  d G_W(w) + \sum_{n' = n+1}^{\check n} v_S(n',
C')\int_{\overline{w}_E(n' + 1, C')}^{\overline{w}_E(n', C')} d G_W(w) \\
- \int_{-\infty}^{\log v_S(n, C')} \;&\exp(w) d G_W(w) \big| C=c\big].
\end{split} \label{vS_3} \end{equation}

Second, we invoke the distributional assumption on $W$,

\begin{equation} W \sim N(-\frac{1}{2}\omega^2,\omega^2),
\end{equation}

which gives us a closed form solution for the
\url{http://en.wikipedia.org/wiki/Log-normal_distribution#Partial_expectation}{partial
expectation},

\begin{equation} \int_{-\infty}^{\log v_S(n, C')} \exp(w) d G_W(w) =
\left[1 - \Phi\left(\frac{ \frac{1}{2}\omega^2 - \log
v_S(n,C')}{\omega}\right)\right] \label{partialExpectation}
\end{equation}

where $\Phi(\cdot)$ refers to the standard normal cumulative distribution
function. The remaining two integrals in equation (\ref{vS_3}) can be
expressed using the cumulative distribution function of $W$:

\begin{equation} \int_{\overline{w}_E(n + 1, C')}^{\log v_S(n, C')}  d
G_W(w) = G_W\left[\log v_S(n,C')\right] - G_W\left[\log v_S(n+1,C') - \log
(1 + \varphi)\right] \label{pSureSurvivalNoEntry} \end{equation}

\begin{equation} \int_{\overline{w}_E(n' + 1, C')}^{\overline{w}_E(n', C')}
d G_W(w) = G_W\left[\log v_S(n',C')-\log(1 + \varphi)\right] -
G_W\left[\log v_S(n'+1,C') - \log(1 + \varphi)\right] \label{pEntrySet}
\end{equation}

We now implement the value function iteration on equation (\ref{vS_3}) in
\textsc{Matlab}.

\input[2..end]{valueFunctionIteration.m}

\subsection{Survival Rules}

Our equilibrium computation algorithm |valueFunctionIteration| is fast
because we do not need to completely characterize firms' survival
strategies to compute the equilibrium value functions. We know that
\emph{when} firms mix between staying and exiting, the must receive a
continuation value of zero. Firms use mixed strategies whenever the cost
shock falls into the interval \begin{equation} \overline w_S(n, c) \leq w <
w_S(1, c), \end{equation} which means that it is not profitable for all $n$
active firms to continue, but the market is profitable enough for at least
one firm to continue.

What we have not computed thus far is how firms mix between continuation
and exit when the cost shock falls into this interval. The mixing
probabilities $a_S$ are implicitly defined by the indifference condition
\begin{equation} \label{eq:indifference1} \sum_{n'=1}^{n} {n - 1 \choose n'
- 1} a_S^{n' - 1}\left(1-a_S\right)^{n-n'}\left(-
\exp(w)+v_{S}(n',c)\right)=0. \end{equation} The indifference condition
states that when $n$ active firms all use the survival rule |a_S|, the
expected value from using survival rule |a_S| equals zero.

We compute the solution to (\ref{eq:indifference1}) in
|mixingProbabilities|.

\input[2..end]{mixingProbabilities.m}

\section{Likelihood}

Before turning to the computation of the likelihood, we first review the
likelihood construction described in the paper. Suppose we have data for
$\check r$ markets. Each market is characterized by $\check t$ observations
that include the demand state $C_{t,r}$ and the number of active firms
$N_{t,r}$. We wish to estimate the parameter vector

\begin{equation} \theta \equiv (\theta_C, \theta_P, \theta_W) \equiv (
(\mu_C, \sigma_C), (k, \varphi), \omega). \end{equation}

The likelihood contribution of a single market-level observation, i.e. a
transition from $(c, n)$ to $(c', n')$ for market $r$ is given by

\begin{equation} \ell_{t+1,r}\left(\theta\right) =
f_{N_{t+1,r},C_{t+1,r}}\left(n',c' |
C_{t,r}=c,N_{t,r}=n;\theta_C,\theta_P,\theta_W\right) \end{equation}

where $f_{N_{t+1,r},C_{t+1,r}}$ stands for the joint density of
$(N_{t+1,r},C_{t+1,r})$ conditional on $(N_{t,r},C_{t,r})$. Notice that
$C_{t+1,r}$ is drawn by nature according to $G_{C,r}(\cdot|C_{t,r})$
independently of $N_{t+1,r}$. Moreover, by the structure of the game,
firms' decisions, which determine $N_{t+1,r}$, are made prior to the draw
of $C_{t+1,r}$ and are therefore not affected by $C_{t+1,r}$. Hence, we can
write the likelihood contribution as the product of the conditional
densities:

\begin{equation} \ell_{t+1,r}\left(\theta\right) = f_{C_{t+1,r}}\left(c'
| C_{t,r}=c;\theta_C\right) \cdot f_{N_{t+1,r}}\left(n' |
C_{t,r}=c,N_{t,r}=n;\theta_C,\theta_P,\theta_W\right) \end{equation}

where $f_{C_{t+1,r}}$ and $f_{N_{t+1,r}}$ denote the conditional densities.
The expression for the conditional density of $N_{t+1,r}$ equals
$p\left(N_{r,t+1}\;|\;N_{r,t},C_{r,t};\theta\right)$. That is,

\begin{equation} f_{N_{t+1,r}}\left(n' |
C_{t,r}=c,N_{t,r}=n;\theta_C,\theta_P,\theta_W\right) =
\Pr(N_{r,t+1}=n'|N_{r,t}=n,C_{r,t}=c;\theta) \equiv
p\left(N_{r,t+1}\;|\;N_{r,t},C_{r,t};\theta\right) \end{equation}

The conditional density of $N_{t+1,r}$ is the probability that market $r$
with $n$ firms in demand state $c$ has $n'$ firms next period. Also, the
conditional density of the demand process is given in the paper by the
function $g_C$. That is,

\begin{equation} f_{C_{t+1,r}}\left(c' | C_{t,r}=c;\theta_C\right) = g_C
\left(C_{t+1,r} |C_{t,r}; \theta_C\right) \end{equation}

The likelihood function is then defined as in the paper:

\begin{equation} \mathcal{L}\left(\theta\right)= \mathcal{L}_C\left(
\theta_C\right) \cdot \mathcal{L}_N\left(\theta\right) \end{equation}

where

\begin{equation} \mathcal{L}_C\left(\theta_C\right) = \prod_{r=1}^{\check
r} \prod_{t=1}^{\check t-1} g_C\left(C_{t+1,r} |C_{t,r}; \theta_C
\right) \end{equation}

\begin{equation} \mathcal{L}_N\left(\theta\right) = \prod_{r=1}^{\check
r} \prod_{t=1}^{\check t-1} p\left(N_{r,t+1}\; | \;N_{r,t},C_{r,t};\theta
\right) \end{equation}

$\mathcal{L}_C\left(\theta_C\right)$ can be calculated easily from demand
data alone, with no need to solve the model, as $g_C\left(C_{t+1,r}
|C_{t,r};\theta_C\right)$ translates to entries in the transition matrix
of the demand process. In contrast, computing $\mathcal{L}_N\left(\theta
\right)$ requires solving for the equilibrium of the model.

The three-steps estimation procedure is as described in
\cite{ecta1987Rust}:

\begin{enumerate}

\item \textbf{ Estimate $\theta_C$ with $\tilde\theta_C\equiv\arg
\max_{\theta_C}{\cal L}_C(\theta_C)$.}

\item \textbf{ Estimate $(\theta_P, \theta_W)$ with
$(\tilde\theta_P,\tilde\theta_W)\equiv\arg\max_{(\theta_P,\theta_W)}{\cal
L}_N(\theta_P,\tilde\theta_C,\theta_W)$.}

\item \textbf{ Estimate $\theta$ by maximizing the full likelihood function
$\hat\theta\equiv\arg\max_\theta{\cal L}(\theta)$, using
$\tilde\theta\equiv(\tilde\theta_P,\tilde\theta_C,\tilde\theta_W)$ as
starting value.}

\end{enumerate}

The first two steps are thus used for providing starting values for the
full information maximum likelihood (FIML) in Step 3. As can be seen from
experimenting with the code, the first two steps provide very good starting
values for the FIML, which therefore converges after only a small number of
iterations. Note that it is the second step which gives the procedure the
name NXFP: solving the model entails solving for the fixed point of the
value functions, and this is nested within the optimization procedure that
maximizes the likelihood.

The starting values for the first step are directly calculated from the
data as the mean and standard deviation of the innovations of logged
demand. The starting values for $\theta_P$ and $\theta_W$ in the second
step are randomly drawn from a uniform distribution with support $[1,5]$.

The next subsections describe each of the three steps. Standard errors are
computed using the outer-product-of-the-gradient method. Since the FIML is
asymptotically efficient, while the estimators in the first two steps are
not, we only discuss the computation of standard errors in the third step.

\subsection{Likelihood Step 1: Estimate $\theta_C$}


\input[2..end]{likelihoodStep1.m}

\subsection{Likelihood Step 2: Estimate $(\theta_P,\theta_W)$}

\input[2..end]{likelihoodStep2.m}

\subsection{Likelihood Step 3: Estimate $(\theta_C, \theta_P, \theta_W)$}

\input[2..end]{likelihoodStep3.m}

\section{Data}

Here we describe how to generate a synthetic sample with data on the number
of active firms and the number of consumers for $\check r $ markets and
$\check t $ time periods. The data generation process consists of two
functions.

\begin{itemize}

\item |randomFirms| simulates firms' entry and exit decisions conditional
on the current number of active firms, the realization of the demand state,
and the realization of the cost shock. \item |dgp| generates a synthetic
panel data set containing the demand state and number of active firms.

\end{itemize}

\subsection{Draw Number of Firms}

\input[2..end]{randomFirms.m}

\subsection{Assemble Data Set}

\input[2..end]{dgp.m}

\section{Example Script: |example.m|}

\input[1..end]{example.m}

\section{Appendix A: List of Structures}

Throughout the \textsc{Matlab} code, the structures |Settings|, |Param|,
and |Data| play an important role. We define their contents in this
section.

The structure |Settings| contains parameters that govern the execution of
the \textsc{Matlab}. All elements in |Settings| need to be defined by hand
and remain constant throughout the execution of the program.

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

\item |Settings.integrationLength| is the integer valued number of points
used for the Gauss-Legendre integration.

\item |Settings.integrationNodes| is the real valued row vector of length
|Settings.integrationLength| with Gauss-Legendre nodes.

\item |Settings.integrationWeights| is the real valued row vector of length
|Settings.integrationLength| with Gauss-Legendre weights.

\item |estimates2k(x)| is an anonymous function that maps the argument a
vector of estimates |x| into the vector valued outcome |Param.k|, which
will be defined below.

\item |estimates2phi(x)| is an anonymous function that maps the argument a
vector of estimates |x| into the vector valued outcome |Param.phi|, which
will be defined below.

\item |estimates2omega(x)| is an anonymous function that maps the argument
a vector of estimates |x| into the real valued outcome |Param.omega|,
which will be defined below.

\end{itemize}

The structure |Param| contains the primitives of the model.

\begin{itemize}

\item |Param.rho| is the real valued discount factor.

\item |Param.k| is a real valued row vector of length |Settings.nCheck|
that parameterizes the surplus function, $k(n)$.

\item |Param.phi| is a real valued scalar that contains the entry costs, $\varphi$.

\item |Param.omega| is a real and parameterizes the scale, $\omega$, of
the cost shock distribution.

\item |Param.demand.muC| is a real and parameterizes the mean, $\mu_C$, of
the log innovations of the demand process.

\item |Param.demand.sigmaC| is a real and parameterizes the standard
deviation, $\sigma_C$, of the log innovations of the demand process.

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

This part of the appendix contains descriptions of all auxiliary functions
used that were not described above.

\subsection{Compute Markov Process}

\input[2..end]{markov.m}

\subsection{Draw from Discrete Distribution}

\input[4..end]{randomDiscr.m}

\subsection{Compute Gauss-Legendre Weights}

\input[4..end]{lgwt.m}

\begin{bibliography}

\bibitem[Abbring et al. (2017a)]{acty2017a} Abbring, J. H., J. R. Campbell,
J. Tilly, N. Yang (2017a): "\url{http://jtilly.io/acty1a.pdf}{Very Simple Markov-Perfect Industry Dynamics: Theory}" \textit{mimeo}.

\bibitem[Abbring et al. (2017b)]{acty2017b} Abbring,
J. H., J. R. Campbell, J. Tilly, N. Yang (2017b): "\url{http://jtilly.io/acty1b.pdf}{Very Simple
Markov-Perfect Industry Dynamics: Empirics}" \textit{mimeo}.

\bibitem[Dube et al. (2012)]{ecta2012DubeFoxSu} Dube, J.-P., J. T. Fox, and
C.-L. Su (2012):
"\url{http://onlinelibrary.wiley.com/doi/10.3982/ECTA8585/abstract}{Improving
the Numerical Performance of Static and Dynamic Aggregate Discrete Choice
Random Coefficients Demand Estimation}," \textit{Econometrica}, 80,
2231-2267.

\bibitem[Rust (1987)]{ecta1987Rust} Rust, J. (1987):
"\url{http://www.hss.caltech.edu/~mshum/stats/rust.pdf}{Optimal Replacement
of GMC Bus Engines: An Empirical Model of Harold Zurcher},"
\textit{Econometrica}, 55, 999-1033.

\bibitem[Tauchen(1986)]{el1986Tauchen} Tauchen, G. (1986):
"\url{http://www.sciencedirect.com/science/article/pii/0165176586901680}{Finite
State Markov-Chain Approximations to Univariate and Vector
Autoregressions}," \textit{Economic Letters}, 20, 177-181.

\end{bibliography}
%}
