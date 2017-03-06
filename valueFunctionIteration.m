%% valueFunctionIteration.m
%{
The function |valueFunctionIteration| requires the arguments
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
the $n^{\text{th}}$ row of |pEntry| stores $\Pr \left(w < \overline
w_E(n, :)\right)$.

\item |pEntrySet| is a matrix of dimension $(\check n  + 1) \times \check c$
that stores the equilibrium probabilities that \emph{exactly} |row| firms
are active post-entry under demand state |column|. Thus, the
$n^{\text{th}}$ row of |pEntrySet| stores $\Pr \left(\overline w_E(n + 1,
:) \leq w < \overline w_E(n, :)\right)$.

\item |pStay| is a matrix of dimension $\check n  \times \check c$ that
stores the equilibrium probabilities that  |row| firms find \emph{certain}
survival profitable under demand state |column|. Thus, the $n^{\text{th}}$
row of |pStay| stores $\Pr \left(w < \overline w_S(n, :)\right)$.

\end{itemize}

The goal is to construct the $(\check n  + 1) \times \check c$ matrix |vS|,
in which the last row is set to zero by construction. Each column in |vS|
constitutes a fixed point to the Bellman equation characterized by equation
(\ref{vS_3}). The procedure will follow a backward recursion on the number
of firms, from $\check n $ back to 1. For $n = \check n$, the Bellman
equation has $v_S(\check n ,c)$ on both sides as entry cannot occur. For
$n<\check n$, the Bellman equation will depend only on $v_S(n',c)$ for
$n'>n$, the values of which are already in memory because we are iterating
backwards.

%}
function [vS, pEntry, pEntrySet, pStay] = ...
    valueFunctionIteration(Settings, Param)

% We allocate the various matrices that will be returned by the function and
% set their initial values to zero.
vS = zeros(Settings.nCheck + 1, Settings.cCheck);
pEntry = zeros(Settings.nCheck + 1, Settings.cCheck);
pEntrySet = zeros(Settings.nCheck + 1, Settings.cCheck);
pStay = zeros(Settings.nCheck, Settings.cCheck);

% Now we begin the backward recursion, starting from |nCheck|. We will
% iterate on |vS(n, :)| using equation (\ref{vS_3}), which we map into the
% relevant \textsc{Matlab} variables below:
%
% \begin{equation}
% \begin{split}
% v_S(n,c) &=  \rho \mathbb E\bigg[ \; & \overbrace{ \pi(n,C')}^{\textbf{flowSurplus}}  - \overbrace{\left[ 1 - G_W \left(\theta_W ^ 2 - \log v_S(n,C') \right) \right]}^{\textbf{partialExp}} \\
%          &                              + & \overbrace{v_S(n, C') \left(G_W\left[\log v_S(n,C')\right] - G_W\left[\log v_S(n + 1,C') - \log (1+\varphi)\right]\right)}^{\textbf{valueSureSurvNoEntry}}  \\
%          &                              + & \overbrace{\sum_{n'=n + 1}^{\check n} v_S(n', C') \left(G_W\left[\log v_S(n',C')-\log (1+\varphi) \right] - G_W\left[\log v_S(n' + 1,C') - \log(1+ \varphi) \right]  \right) }^{\textbf{valueAdditionalEntry}} \bigg| C=c\bigg].
% \end{split}
% \end{equation}
%
% The expectation operator with respect to $C'$ is implemented by
% left-multiplying the inside of the expectation in the equation above (a
% column vector with |cCheck| elements) by the transition probability
% matrix |Param.demand.transMat|.  The iteration is complete when the
% difference |vSdiff| between  |vS(n, :)| and its update |n vSPrime| does not
% exceed the stopping  criterion, |Settings.tolInner|.  Start by
% initializing |vSdiff| to 1 (which exceeds |Settings.tolInner|).
% We pre-compute $\theta_W ^ 2$ and the demand grid (transposed) at the beginning,
% so we do not have to do so repeatedly inside the loops below.
thetaW2 = Param.thetaW ^ 2;
gridTrans = exp(Settings.logGrid)';

for n = Settings.nCheck:-1:1

    % % initialize
    iter = 0;
    vSdiff = 1;
    vSn = ones(Settings.cCheck, 1);

    % % pre-compute flow surplus so we don't have to do so repeatedly inside the while loop
    flowSurplus = gridTrans * Param.k(n) / n;

    % % pre-compute value from additional entry, because this is known
    valueAdditionalEntry = ...
            sum(pEntrySet((n + 1):end, :) .* vS((n + 1):end, :) , 1)';

    % % get row (n+1) out of pEntry and store it as column
    pEntrynPlus1 = pEntry(n + 1, :)';

    % % iterate until convergence
    while (vSdiff > Settings.tolInner && iter < Settings.maxIter)

        iter = iter + 1;
        logvSn = log(vSn);
        pStayn = normcdf(logvSn, -0.5 * thetaW2, Param.thetaW);
        partialExp = 1 - normcdf(0.5 * thetaW2 - logvSn, 0, Param.thetaW);
        valueSureSurvNoEntry = (pStayn - pEntrynPlus1) .* vSn;
        vSnPrime = (Param.rho * Param.demand.transMat * (flowSurplus ...
            - partialExp + valueSureSurvNoEntry + valueAdditionalEntry));
        vSdiff = max(abs(vSn - vSnPrime));
        vSn = vSnPrime;

    end

    if (iter == Settings.maxIter)
       error('value function iteration failed');
    end

    vS(n, :) = vSn;
    pStay(n, :) = pStayn;
    pEntry(n, :) = normcdf(logvSn - log((1 + Param.phi(n))), -0.5 * thetaW2, Param.thetaW);
    pEntrySet(n, :) = pEntry(n, :) - pEntry(n + 1, :);

end

% Note that we only need to compute the entry probabilities outside of the
% value function iteration. We use the variable |iter| to keep track of the
% number of iterations for each value function iteration. Whenever |iter|
% exceeds |Settings.maxIter|, the value function iteration is terminated
% and a error is returned. This concludes
% |valueFunctionIteration|.
end
