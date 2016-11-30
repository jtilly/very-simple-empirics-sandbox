%% valueFunctionIteration.m
%{
The function \textbf{valueFunctionIteration.m} requires the arguments  
|Settings| and |Param|. It returns the following four matrices:  
  
\begin{itemize}   
  
\item |vS| is a matrix of dimension $(\check n  + 1) \times \check c$ that  
stores the equilibrium post-survival value functions. By definition, the  
last row consists of zeros (and exists mostly for computational  
convenience).  
  
\item |pEntry| is a matrix of dimension $(\check n  + 1) \times \check c$  
that stores the equilibrium entry probabilities, i.e. each element contains  
the probability that \emph{at least} |row| firms are active post-entry  
under demand state |column|. Again, the last row consists of zeros. Thus,  
the $n^{\text{th}}$ row of |pEntry| stores $\Pr \left(W' < \overline  
w_E(n, C')\right)$.  
  
\item |pEntrySet| is a matrix of dimension $(\check n  + 1) \times \check c$  
that stores the equilibrium probabilities that \emph{exactly} |row| firms  
are active post-entry under demand state |column|. Thus, the  
$n^{\text{th}}$ row of |pEntrySet| stores $\Pr \left(\overline w_E(n + 1,  
C') \leq W' < \overline w_E(n, C')\right)$.  
  
\item |pStay| is a matrix of dimension $\check n  \times \check c$ that  
stores the equilibrium probabilities that  |row| firms find \emph{certain}  
survival profitable under demand state |column|. Thus, the $n^{\text{th}}$  
row of |pStay| stores $\Pr \left(W' < \overline w_S(n, C')\right)$.  
  
\end{itemize}   
  
The goal is to construct the $(\check n  + 1) \times \check c$ matrix |vS|,  
in which the last row is set to zero by construction. Each column in |vS|  
constitutes a fixed point to the Bellman equation characterized by equation  
(\ref{vS_2}). The procedure will follow a backward recursion on the number  
of firms, from $\check n $ back to 1. For $n = \check n$, the Bellman  
equation has $v_S(\check n ,c)$ on both sides as entry cannot occur. For  
$n<\check n$, the Bellman equation will depend only on $v_S(n',c)$ for  
$n'>n$, the values of which are already in memory because we are iterating  
backwards.  

%}
function [vS, pEntry, pEntrySet, pStay] = valueFunctionIteration(Settings, Param)

% Preallocate the matrices that will be returned by the function.

vS = ones(Settings.nCheck + 1, Settings.cCheck);
pEntry = zeros(Settings.nCheck + 1, Settings.cCheck);
pEntrySet = zeros(Settings.nCheck + 1, Settings.cCheck);
pStay = zeros(Settings.nCheck, Settings.cCheck);

% Now we begin the backward recursion, starting from |nCheck|. We will  
% iterate on |vS(n, :)| using equation (\ref{vS_2}), which we map into the  
% relevant \textsc{Matlab} variables below:  
%
% \begin{equation} 
% \begin{split} 
% v_S(n,c) &=  \rho \mathbb E_{C'}\bigg[ \; & \overbrace{ \pi(n,C')}^{\textbf{flowSurplus}}  - \overbrace{\left[ 1 - \tilde \Phi \left(\omega ^ 2 - \log v_S(n,C') \right) \right]}^{\textbf{partialExp}} \\ 
%          &                              + & \overbrace{v_S(n, C') \left(\tilde \Phi\left[\log v_S(n,C')\right] - \tilde \Phi\left[\log v_S(n + 1,C') - \log (1+\varphi)\right]\right)}^{\textbf{valueSureSurvNoEntry}}  \\ 
%          &                              + & \overbrace{\sum_{n'=n + 1}^{\check n} v_S(n', C') \left(\tilde \Phi\left[\log v_S(n',C')-\log (1+\varphi) \right] - \tilde \Phi\left[\log v_S(n' + 1,C') - \log(1+ \varphi) \right]  \right) }^{\textbf{valueAdditionalEntry}} \bigg| C=c\bigg].
% \end{split} 
% \end{equation} 
%
% The expectation operator with respect to $C'$ is implemented by  
% left-multiplying the inside of the expectation in the equation above (a  
% column vector with |cCheck| elements) by the transition probability  
% matrix |Param.demand.transMat|.  The iteration is complete when the  
% difference |vSdiff| between  |vS(n, :)| and its update |vSPrime| does not  
% exceed the stopping  criterion, |Settings.tolInner|.  Start by  
% initializing |vSdiff| to 1 (which exceeds |Settings.tolInner|).  
% We pre-compute $\omega ^ 2$ at the beginning, so we do not have to do 
% so repeatedly inside the loops below.
omega2 = Param.omega ^ 2;
 
for n = Settings.nCheck:-1:1
    
    iter = 0;
    vSdiff = 1;

    % % pre-compute flow surplus so we don't have to do so repeatedly inside the while loop
    flowSurplus = exp(Settings.logGrid)' * Param.k(n) / n;
    
    while (vSdiff > Settings.tolInner && iter < Settings.maxIter)
        
        iter = iter + 1;
        logvS = log(vS(n, :)');
        pStay(n, :) = normcdf(logvS, -0.5 * omega2, Param.omega);
        partialExp = 1 - normcdf(0.5 * omega2 - logvS, 0, Param.omega);
        valueSureSurvNoEntry = ((pStay(n, :) - pEntry(n + 1, :)) .* vS(n, :))';
        valueAdditionalEntry = sum(pEntrySet((n + 1):end, :) .* vS((n + 1):end, :) , 1)';
        
        vSPrime = (Param.rho * Param.demand.transMat * ...
            (flowSurplus - partialExp + valueSureSurvNoEntry + valueAdditionalEntry))'; 
        
        vSdiff = max(abs(vS(n, :) - vSPrime));
        vS(n, :) = vSPrime;
        
    end
    
    if (iter == Settings.maxIter) 
       error('value function iteration failed'); 
    end
    
    pEntry(n, :) = normcdf(logvS - log((1 + Param.phi(n))), -0.5 * omega2, Param.omega);
    pEntrySet(n, :) = pEntry(n, :) - pEntry(n + 1, :);

end

% Note that we only need to compute the entry probabilities outside of the   
% value function iteration. We use the variable |iter| to keep track of the  
% number of iterations for each value function iteration. Whenever |iter|  
% exceeds |Settings.maxIter|, the value function iteration is terminated  
% and a error is returned. This concludes  
% \textbf{valueFunctionIteration}.  
% 
% The speed of our implementation of |valueFunctionIteration| could be 
% increased if we transposed the matrices |vS|, |pEntry|, |pEntrySet|, and 
% |pStay|. Since \textsc{Matlab} stores matrices in memory in column major order, \textsc{Matlab} 
% faster traverses through the first dimension of a matrix than through the second. 
% We use the slightly slower implementation in this package, because we 
% find it aligns better with the underlying mathematical expressions. 
end