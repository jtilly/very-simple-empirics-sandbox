%% likelihoodStep2.m
% The function \textbf{likelihoodStep2} requires the structures |Data|, 
% |Settings|, and |Param|, and the vector |estimates| as inputs. It returns 
% the scalar valued negative log-likelihood function |ll| and a column vector  
% of length $\check r \times (\check t - 1)$ containing the market-time-specific  
% likelihood contributions, |likeCont|. 

function [ ll, likeCont] = likelihoodStep2(Data, Settings, Param, estimates)

% We start by mapping the vector |estimates| into the corresponding 
% elements in the |Param| structure. We do this using anonymous functions 
% that are defined in the structure |Settings|. By construction, |Param.k| 
% and |Param.phi| are vectors of length $\check n$. |Param.omega| is a 
% scalar. 

Param.k = Settings.estimates2k(estimates);
Param.phi = Settings.estimates2phi(estimates);
Param.omega = Settings.estimates2omega(estimates);

% Now we use \textbf{valueFunctionIteration.m} to solve the model by 
% iterating on the post-survival value function.  We also retrieve |pStay|, 
% |pEntry| and |pEntrySet|, which are the probability of certain survival 
% and the entry probabilities as described in 
% \textbf{valueFunctionIteration.m} above. 

[vS,pEntry,pEntrySet,pStay] = valueFunctionIteration(Settings, Param);

% Next we collect the transitions observed in the data and vectorize them. 
% The column vectors |from|, |to|, and |demand| are all of length $(\check 
% t - 1) \check r$. 

vec = @(x) x(:);
from = vec(Data.N(1:Settings.tCheck - 1, 1:Settings.rCheck));
to = vec(Data.N(2:Settings.tCheck, 1:Settings.rCheck));
demand = vec(Data.C(2:Settings.tCheck, 1:Settings.rCheck));

% The construction of the likelihood contributions considers five separate   
% types of transitions from $n$ to $n'$.  
% \begin{itemize}  
% \item \textbf{Case 1: Entry ($\mathbf{n'>n}$).} The likelihood  
% contribution is  
% \begin{equation}   
% \mbox{Pr} \left( \overline w_E(n' + 1, c) \leq W < \overline w_E(n', c)  
% \right) = \tilde \Phi \left[\log v_S(n',c)-\log (1+\varphi) \right]   
% - \tilde \Phi \left[ \log v_S(n' + 1,c) - \log(1+ \varphi) \right],  
% \end{equation}  
% which is the probability that the cost shock is such that $n'$ firms can  
% be active post-entry but $n' + 1$ cannot. Here and throughout we will  
% convert subscripts to linear indices using the Matlab function  
% \url{http://www.mathworks.com/help/matlab/ref/sub2ind.html}{sub2ind}.  

selectMarketsEntry = to > from;
idx = sub2ind(size(pEntrySet), to(selectMarketsEntry), demand(selectMarketsEntry));
llhContributions_Entry = zeros(size(from));
llhContributions_Entry(selectMarketsEntry) = pEntrySet(idx);

% \item \textbf{Case 2: Zero firms and no firm enters ($\mathbf{n'=n=0}$).}  
% The likelihood contribution is  
% \begin{equation}  
% \mbox{Pr} \left( W \geq \overline w_E(1, c) \right) =   
% 1 - \tilde \Phi\left[\log v_S(1,c)-\log (1+\varphi) \right]  
% \end{equation}  

selectMarketsStayAtZero = from == 0 & to == 0;
llhContributions_StayAtZero = zeros(size(from));
llhContributions_StayAtZero(selectMarketsStayAtZero) = 1 - pEntry(1, demand(selectMarketsStayAtZero));

% \item \textbf{Case 3: Number of firms stays the same at a non-zero number  
% ($\mathbf{n'=n>0}$).} The likelihood contribution is  
% \begin{equation}   
% \mbox{Pr} \left( \overline w_S(n, c) \leq W < \overline w_E(n + 1, c) \right)   
% = \tilde \Phi\left[\log v_S(n,c) \right]  
%  - \tilde \Phi\left[\log v_S(n + 1,c) - \log (1+\varphi) \right]  
% \end{equation}  

selectMarketsStayAtNonZero = (from > 0 & from == to);
llhContributions_StayAtNonZero = zeros(size(from));
llhContributions_StayAtNonZero(selectMarketsStayAtNonZero) ...
= pStay(sub2ind(size(pStay), from(selectMarketsStayAtNonZero), demand(selectMarketsStayAtNonZero)) )- ...
  pEntry(sub2ind(size(pEntry), from(selectMarketsStayAtNonZero) + 1, demand(selectMarketsStayAtNonZero)));

% \item \textbf{Case 4: All firms leave ($\mathbf{n'=0, n>0}$).} The  
% likelihood contribution is  
% \begin{equation}    
% \mbox{Pr} \left( W \geq \overline w_S(1, c) \right)   
% = 1 - \tilde \Phi\left[\log v_S(1,c) \right]   
% \end{equation}  

llhContributions_AllLeave = zeros(size(from));
selectMarketsAllLeave = (to == 0 & from > 0);
llhContributions_AllLeave(selectMarketsAllLeave) = 1 - pStay(1, demand(selectMarketsAllLeave));

%{
\item \textbf{Case 5: Mixed survival strategies ($\mathbf{n'\leq n}$).}   
For a given survival strategy $a_S(n,c,w)$, the likelihood contribution from   
(purely) mixed strategy play is given by  
\begin{equation}  
\int_{\log v_S(n,c)}^{\log v_S(1,c)} {n \choose n'}  a_S(n,c,w)^{n'}  
\left(1-a_S(n,c,w)\right)^{n-n'} g_W(w) dw.  
\end{equation}  
The term inside the integral is the probabillity mass function of a   
binomial distribution function with success probability $a_S(n,c,w)$.  
The survival strategies are defined by the indifference condition   
(equation (5) in the paper)  
\begin{equation} \label{indifference} 
\sum_{n'=1}^{n} {n - 1 \choose n' - 1}\; a_S^{n' - 1} \left(1-a_S\right)^{n-n'}  
\left(- \exp(w)+v_{S}(n',c)\right)=0. 
\end{equation}  
 
In principle, we could compute this integral directly by numerically   
integrating over $W$. In practice, it is computationally convenient to do   
a change of variables and integrate over the survival strategies   
$a_S(n,c,\cdot)$ instead. To make an explicit distinction between the   
survival strategy $a_S(n,c,w)$ (which is a function of $n$, $c$, and $w$)   
and the variable of integration (which is just a scalar), we will refer   
to the latter as $p$. Thus, for a given value of $p$, we need to find the   
value of $w$ such that $p = a_S(n,c,w)$.   
 
Equation (\ref{indifference}) defines the   
inverse $a_S^{ - 1}(p;c,n)$ for which  
 
\begin{equation}  
a_S^{ - 1}(a_S(n,c,w);c,n) = w.  
\end{equation}  
 
This inverse function can be solved for analytically and it is given by  
 
\begin{equation}  
\underbrace{a_S^{ - 1}(p;c,n)}_{\textbf{aSinv}}  
= \log \left(\underbrace{\sum_{n'=1}^{n} {n - 1 \choose n' - 1}  
      p^{n' - 1} \left(1 - p\right)^{n-n'} v_{S}(n',c) }_{\textbf{expaSInv}}\right) 
\end{equation}  
 
Then note that $a_S^{ - 1}(1;c,n) = \log v_S(n,c)$ and $a_S^{ - 1}(0;c,n) = 
\log v_S(1,c)$.  
We can write the likelihood contribution as an integral over $p$:  
\begin{equation}  
\begin{split}  
&\int_{1}^{0} {n \choose n'}  p^{n'} \left(1 - p\right)^{n-n'}  
      \times \frac{da_S^{ - 1}(p;c,n)}{dp}g_{W}\left[a_S^{ - 1}(p;c,n)\right]  
      dp \\  
= &-\int_{0}^{1} {n \choose n'}  p^{n'} \left(1 - p\right)^{n-n'}  
      \times \frac{da_S^{ - 1}(p;c,n)}{dp}g_{W}\left[a_S^{ - 1}(p;c,n)\right]  
      dp \\  
\approx &-\sum_{jX=1}^J {n \choose n'}  p_{jX}^{n'}  
\left(1 - p_{jX}\right)^{n-n'} \times  
\underbrace{\underbrace{\frac{da_S^{ - 1}(p_{jX};c,n)}{dp}}_{\textbf{daSinvdP}}  
\underbrace{g_{W}\left[a_S^{ - 1}(p_{jX};c,n)\right]}_{\textbf{normaSinv}}  
\underbrace{w_{jX}}_{\textbf{intWeights}}}_{\textbf{mixingDensity}},  
\end{split}  
\label{llContrMixing} 
\end{equation}  
 
where $p_{1}, ..., p_{J}$ refer to the   
\url{http://en.wikipedia.org/wiki/Gaussian_quadrature}{Gauss-Legendre}   
nodes and $w_{1}, ..., w_{J}$ to the corresponding weights. Notice that the  
integration bounds are now 0 and 1 since if $w<\log v_S(n,c)$ the firms  
surely survive and when $w>\log v_S(1,c)$ the firms surely exit.  
Differentiation of $a_S^{ - 1}(p;c,n)$ gives  
 
\begin{equation}  
\underbrace{\frac{da_S^{ - 1}(p;c,n)}{dp}}_{\textbf{daSinvdP}} =  
 \overbrace{ \sum_{n'=1}^{n} \overbrace{{n - 1 \choose n' - 1}   
\left(p^{n'-2} (1 - p)^{(n-n' - 1)} \left( (n' - 1) (1 - p) - p (n-n') \right) \right)}^{\textbf{dbinomialPmfdP}} v_{S}(n',c)}^{\textbf{dexpaSInvdP}} \frac{1}{\underbrace{\exp(a_S^{ - 1}(p;c,n))}_{\textbf{expaSInv}}}  
\end{equation}  
 
Now, compute the matrix |mixingDensity| using (\ref{mixingDensity}). |mixingDensity| is of dimension   
|Settings.truncOrder| by |Settings.cCheck| by |Settings.nCheck|. It is   
defined as   
 
\begin{equation}    
      \text{mixingDensity(jX,c,n)} =    
      \underbrace{\frac{da_S^{ - 1}(p_{jX};c,n)}{dp}}_{\textbf{daSinvdP}}  
      \underbrace{g_{W}\left[a_S^{ - 1}(p_{jX};c,n)\right]}_{\textbf{normaSinv}}  
      \underbrace{w_{jX}}_{\textbf{intWeights}}. \label{mixingDensity}  
\end{equation}  
 
The element $(p_{jX}, c, n)$ gives us the density 
of the mixing probability $p_{jX}$ when demand equals $c$ and the 
current number of incumbents is $n$. 
 
Note that mixed strategy play is only relevant for markets with at least   
two firms. We define the auxiliary variable |expaSInv|, which equals   
|expaSInv = exp(aSinv(:, :, n))|. |dexpaSInvdP| is another auxiliary variable   
that stores the derivative of |expaSInv| with respect to |p|. Then assemble   
|expaSInv| and |dexpaSInvdP| by looping over the possible outcomes from   
mixing |nPrime=0,...,n|. |nPrime=0| refers to the case when all firms leave   
due to mixed strategy play and |nPrime=n| refers to the case when all firm   
stay due to mixed strategy play. Then, use |val| to compute |aSinv| and   
compute the derivative with respect to |p| and store it as |daSinvdP|.   
Lastly, compute the mixing density, where we already take into account that   
we use Gauss-Legendre weights that are stored in the vector |weights|   
during the integration steps.   
 
We pre-compute |nchoosekMatrixPlusOne| which is a matrix of size $\check  
n + 1$ by $\check n + 1$, where element $(i,j)$ contains $i - 1 \choose j - 1$. The  
copious naming and indexing convention is owed to the fact that Matlab's  
indexing starts at one, not zero, so element $(1,1)$ corresponds to $0  
\choose 0$. Pre-computing this matrix is helpful, because factorial  
operations are computationally demanding.  
%}

nchoosekMatrixPlusOne = ones(Settings.nCheck + 1);

for nX=2:Settings.nCheck
    for iX=0:(nX - 1)
        nchoosekMatrixPlusOne(nX + 1, iX + 1) = nchoosek(nX, iX);
    end
end 

% We then set up to compute the matrix |mixingDensity|, as given by 
% (\ref{mixingDensity}). 

mixingDensity = zeros(length(Settings.integrationNodes), Settings.cCheck, Settings.nCheck);
aSinv = zeros(length(Settings.integrationNodes), Settings.cCheck, Settings.nCheck);
daSinvdP = zeros(length(Settings.integrationNodes), Settings.cCheck, Settings.nCheck);

p = Settings.integrationNodes;
w = Settings.integrationWeights;
 
for n = 2:Settings.nCheck
     
    expaSInv = zeros(length(p), Settings.cCheck);
    dexpaSInvdP = zeros(length(p), Settings.cCheck);
     
    for nPrime = 1:n
        
        nCk = nchoosekMatrixPlusOne(n, nPrime);
        binomialPmf = nCk .* repmat(p .^ (nPrime - 1) .* (1 - p) .^ (n - nPrime), 1, Settings.cCheck);
        dbinomialPmfdP = nCk .* repmat(p .^ (nPrime-2) .* (1 - p) .^ (n - nPrime - 1) ...
                      .* ( (nPrime - 1) .* (1 - p) - p .* (n - nPrime)), 1, Settings.cCheck);
        repvS =  repmat(vS(nPrime, :), Settings.truncOrder,1);
        expaSInv = expaSInv +  binomialPmf .* repvS ;
        dexpaSInvdP = dexpaSInvdP +  dbinomialPmfdP .* repvS;
        
    end
    
    aSinv(:, :, n) =  log ( expaSInv );
    daSinvdP(:, :, n) =  dexpaSInvdP ./ expaSInv;
     
    intWeights = repmat(w, 1, Settings.cCheck);
    normaSinv = normpdf(aSinv(:, :, n), -.5*Param.omega^2, Param.omega);
    mixingDensity(:, :, n) = daSinvdP(:, :, n) .* normaSinv .* intWeights;
end

% With the matrix |mixingDensity| in hand, we can compute the likelihood  
% contributions from mixed strategy play using (\ref{llContrMixing}). Note  
% that this time, we cannot  avoid the use of loops altogether. However,  
% we only need to loop over all  those observations where purely mixed 
% strategy play does in fact occur.   

selectMixing = (from >= 2 & to <= from);
idx = selectMixing .* (1:length(from))';
idx(idx==0) = []; % \% vector with indices with pure mixed strategy play
llhContributions_Mixing = zeros(size(from));
 
for jX=1:length(idx)
 
    nCk = nchoosekMatrixPlusOne(from(idx(jX)) + 1, to(idx(jX)) + 1);
    llhContributions_Mixing(idx(jX)) = ...
        -sum(nCk .* p .^ to(idx(jX)) .* (1 - p) .^ (from(idx(jX)) - to(idx(jX))) ...
                  .* mixingDensity(:,  demand(idx(jX)), from(idx(jX))) );
 
end 

% \end{itemize}

% Finally, sum up the likelihood contributions from the five cases and 
% return the negative log likelihood function. When |ll| is not real 
% valued, the negative log likelihood is set to |inf|. 

ll = -sum(log(llhContributions_Entry + ...
              llhContributions_StayAtZero + ...
              llhContributions_StayAtNonZero + ...
              llhContributions_AllLeave + ...
              llhContributions_Mixing));
           
if(isnan(ll) || max(real(ll)~=ll) == 1)
    ll = inf;
end

% If two outputs are requested, we also return the likelihood contributions: 

if(nargout == 2)
    likeCont = llhContributions_Entry +...
               llhContributions_StayAtZero +...
               llhContributions_StayAtNonZero +...
               llhContributions_AllLeave +...
               llhContributions_Mixing;
end

% This concludes \textbf{likelihoodStep2.m}.
end