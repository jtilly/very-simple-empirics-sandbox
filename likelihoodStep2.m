%% likelihoodStep2.m
% We now construct the likelihood contributions that result from the number of firms evolving from $n$ to $n'$. Recall that we obtain cost-shock thresholds for entry and \emph{sure} survival, defined by $\overline w_{E}(n,c) \equiv \log v_{S}(n,c) - \log\left(1 + \tilde \varphi\right)$ and $\overline w_{S}(n,c)\equiv \log v_{S}(n,c)$. We briefly review the theory before we implement the computation in \textsc{Matlab}. We consider five mutually exclusive cases.
%
% \begin{itemize}
% \item \textbf{Case I: $\mathbf{n'>n}$.}
% If the number of firms increases from $n$ in period $t-1$ to $n'>n$ in period $t$, then it must be profitable for the $n'$th firm to enter, but not for the $(n'+1)$th: $\overline w_{E}(n'+1,c)\leq W  < \overline w_{E}(n',c)$. The probability of this event is
% \begin{equation} \label{app:eq:llhcontr1}
% \tilde \Phi\left[\overline w_{E}(n',c)\right]-\tilde \Phi\left[\overline w_{E}(n'+1,c)\right].
% \end{equation}
%
% \item \textbf{Case II: $\mathbf{0<n'<n}$.}
% If the number of firms decreases from $n$ in period $t-1$ to $n'$ in period $t$, with $0<n'<n$, then $W $ must take a value $w$ such that  firms exit with probability $a_{S}(n,c,w)\in(0,1)$. Thus, this value $w$ must be high enough so that $n$ firms cannot survive profitably, $w\geq\overline w_{S}(n,c)$, but low enough for a single firm to survive profitably, $w<\overline w_{S}(1,c)$. Given such value $w$, $N'$ is binomially distributed with success probability $a_{S}(n,c,w)$ and population size $n$. Hence, the probability of observing a transition from $n$ to $n'$ with $0<n'<n$ equals
% \begin{equation} \label{app:eq:llhcontr2}
% \int_{\overline w_{S}(n,c)}^{\overline w_{S}(1,c)} {n \choose n'} a_{S}(n,c,w)^{n'} \left[1-a_{S}(n,c,w)\right]^{n-n'} \tilde \varphi(w)dw,
% \end{equation}
%
% where $\tilde \varphi$ is the density of $\tilde \Phi$. The integrand in (\ref{app:eq:llhcontr2}) involves the mixing probabilities $a_{S}(n,c,w)$. We discuss how we compute this integral in detail below.
%
% \item \textbf{Case III: $\mathbf{n'=0, n>0}$.}
% If all firms exit in period $t-1$, then either it is not profitable for even a single firm to continue, $W \geq \overline w_{S}(1,c)$, or it is profitable for some but not all firms to continue, $\overline w_{S}(n,c) \leq W <\overline w_{S}(1,c)$, firms exit with probability $a_S(n,c)\in(0,1)$ as in Case II, and by chance none of the $n$ firms survives. The probability of these events is
% \begin{equation}
% \label{app:eq:llhcontr3}
% 1-\tilde \Phi\left[\overline w_{S}(1,c)\right] +\int_{\overline w_{S}(n,c)}^{\overline w_{S}(1,c)} \left[1-a_{S}(n,c,w)\right]^{n} \tilde \varphi(w)dw.
% \end{equation}
%
% \item \textbf{Case IV: $\mathbf{n'=0, n=0}$.}
% In this case, the market is populated by zero firms and it is not profitable for even a monopolist to enter.
% \begin{equation}
% \label{app:eq:llhcontr4}
% 1-\tilde \Phi\left[\overline w_{E}(1,c)\right].
% \end{equation}
%
% \item \textbf{Case V: $\mathbf{n' = n > 0}$.}
% If there is entry nor exit in period $t-1$, then either no firm finds it profitable to enter and all $n$ incumbents find it profitable to stay, $\overline w_{E}(n+1,c) \leq W <\overline w_{S}(n,c),$ or the $n$ incumbents mix as in Cases II and III, but by chance end up all staying. The probability of these events is
% \begin{equation} \label{app:eq:llhcontr5}
% \tilde \Phi\left[\overline w_{S}(n,c)\right]-\tilde \Phi\left[\overline w_{E}(n+1,c)\right] + \int_{\overline w_{S}(n,c)}^{\overline w_{S}(1,c)} a_{S}(n,c,w)^{n} \tilde \varphi(w)dw.
% \end{equation}
% \end{itemize}
% We compute the likelihood using the function |likelihoodStep2|
% that requires as inputs the structures |Data|, |Settings|, and |Param|, and
% the vector |estimates| as inputs. It returns the scalar valued negative
% log-likelihood function |ll| and a column vector of length $\check r \times
% (\check t - 1)$ containing the market-time-specific likelihood contributions,
% |likeCont|.

function [ll, likeCont] = likelihoodStep2(Data, Settings, Param, estimates)

% We start by mapping the vector |estimates| into the corresponding
% elements in the |Param| structure. We do this using anonymous functions
% that are defined in the structure |Settings|. By construction, |Param.k|
% and |Param.phi| are vectors of length $\check n$. |Param.omega| is a
% scalar.

Param.k = Settings.estimates2k(estimates);
Param.phi = Settings.estimates2phi(estimates);
Param.omega = Settings.estimates2omega(estimates);

% Now we use |valueFunctionIteration| to solve the model by
% iterating on the post-survival value function.  We also retrieve |pStay|,
% |pEntry| and |pEntrySet|, which are the probability of certain survival
% and the entry probabilities as described in
% |valueFunctionIteration| above.

[vS,pEntry,pEntrySet,pStay] = valueFunctionIteration(Settings, Param);

% Next we collect the transitions observed in the data and vectorize them.
% The column vectors |from|, |to|, and |demand| are all of length $(\check
% t - 1) \times \check r$.

vec = @(x) x(:);
from = vec(Data.N(1:Settings.tCheck - 1, 1:Settings.rCheck));
to = vec(Data.N(2:Settings.tCheck, 1:Settings.rCheck));
demand = vec(Data.C(2:Settings.tCheck, 1:Settings.rCheck));

% Here and throughout we will
% convert subscripts to linear indices using the Matlab function
% \url{http://www.mathworks.com/help/matlab/ref/sub2ind.html}{sub2ind}.
%
% \textbf{Case I:} We store all of the likelihood contributions
% resulting from entry in the vector |llhContributionsCaseI|.
selectMarketsCaseI = to > from;
llhContributionsCaseI = zeros(size(from));
llhContributionsCaseI(selectMarketsCaseI) = ...
    pEntrySet(sub2ind(size(pEntrySet), to(selectMarketsCaseI), demand(selectMarketsCaseI)));

% \textbf{Case II:} We store all of the likelihood contributions resulting from exit to
% a non-zero number of firms in the vector |llhContributionsCaseII|.
selectMarketsCaseII = from > to & to > 0;
llhContributionsCaseII = zeros(size(from));
llhContributionsCaseII(selectMarketsCaseII) =  ...
    mixingIntegral(from(selectMarketsCaseII), ...
                   to(selectMarketsCaseII), ...
                   demand(selectMarketsCaseII), vS, Param, Settings);
% Note that this case involves computing the integral over mixed strategy play,
% which we do in the function |mixingIntegral|. We document its content below.
%
% \textbf{Case III:} We store all of the likelihood contributions resulting from transitions
% to zero (from a positive number of firms) in |llhContributionsCaseIII|.
selectMarketsCaseIII = to == 0 & from > 0;
llhContributionsCaseIII = zeros(size(from));
llhContributionsCaseIII(selectMarketsCaseIII) = ...
    1 - pStay(1, demand(selectMarketsCaseIII))' + ...
    mixingIntegral(from(selectMarketsCaseIII), ...
                   to(selectMarketsCaseIII), ...
                   demand(selectMarketsCaseIII), vS, Param, Settings);

% \textbf{Case IV:} We store all of the likelihood contributions resulting from when the
% number of active firms remains at zero in |llhContributionsCaseIV|.
selectMarketsCaseIV = to == 0 & from == 0;
llhContributionsCaseIV = zeros(size(from));
llhContributionsCaseIV(selectMarketsCaseIV) = ...
    1 - pEntry(1, demand(selectMarketsCaseIV))';

% \textbf{Case V:} We store all of the likelihood contributions resulting from the number
% of firms staying the same in |llhContributionsCaseV|.
selectMarketsCaseV = from == to & to > 0;
llhContributionsCaseV = zeros(size(from));
llhContributionsCaseV(selectMarketsCaseV) = ...
    pStay(sub2ind(size(pStay), from(selectMarketsCaseV), demand(selectMarketsCaseV))) - ...
    pEntry(sub2ind(size(pEntry), from(selectMarketsCaseV) + 1, demand(selectMarketsCaseV)))  + ...
    mixingIntegral(from(selectMarketsCaseV), ...
                   to(selectMarketsCaseV), ...
                   demand(selectMarketsCaseV), vS, Param, Settings);

% Finally, we sum up the likelihood contributions from the five cases and
% return the negative log likelihood function. When |ll| is not real
% valued, the negative log likelihood is set to |inf|.

ll = -sum(log(llhContributionsCaseI + ...
              llhContributionsCaseII + ...
              llhContributionsCaseIII + ...
              llhContributionsCaseIV + ...
              llhContributionsCaseV));
 
if(isnan(ll) || max(real(ll)~=ll) == 1)
    ll = inf;
end

% If two outputs are requested, we also return the likelihood contributions:

if(nargout == 2)
    likeCont = llhContributionsCaseI +...
               llhContributionsCaseII +...
               llhContributionsCaseIII +...
               llhContributionsCaseIV +...
               llhContributionsCaseV;
end
% This concludes |likelihoodStep2|.
%
% We still need to specify what exactly happens in the function
% |mixingIntegral|.
%
% \input[2..end]{mixingIntegral.m}

end
