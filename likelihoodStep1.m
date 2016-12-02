%% likelihoodStep1.m
% This function computes the first step likelihood function from demand
% data. This function takes as inputs the |Data| structure (from which the
% matrix |data.C| will be used), the |Settings| structure, and the
% |estimates| vector which consists of $\mu_C$ and $\sigma_C$. The output of
% the function is the negative log likelihood |ll| and the $(\check t
% -1)\cdot \check r \times1$ vector of likelihood contributions |likeCont|.
% Notice that the data contains $\check t$ time periods, which gives us
% $\check t -1$ transitions to construct the likelihood function.

function [ll, likeCont] = likelihoodStep1(Data , Settings, estimates)

% We look for transitions from $C_{t,r}$ to $C_{t+1,r}$ for
% $t=1,\ldots,\check t-1$. Start by constructing two matrices of size
% $(\check t -1)\times \check r $ named |from| and |to|, which include
% $C_{t,r}$  and $C_{t+1,r}$, respectively, for $t=1,\ldots,\check t-1$
% and $r=1,\ldots,\check r $. Thus, |from| and |to| are vectors with as
% many elements as there are transitions in the data.
from = Data.C(1:(Settings.tCheck - 1), 1:Settings.rCheck);
to = Data.C(2:Settings.tCheck, 1:Settings.rCheck);

% Preallocate the $(\check t -1)\cdot \check r \times1$ likelihood
% contribution vector:
likeCont = NaN(size(from(:),1), 1);

% Assign |mu| and |sigma|, the values with respect to which we will
% maximize this likelihood function from the input |estimates|.
mu = estimates(1);
sigma = estimates(2);

% Now, compute the likelihood for each transition that is observed in the
% data given |mu| and |sigma|. For all transitions, calculate likelihood
% contributions according to \cite{el1986Tauchen}. We make a distinction
% between transitions to interior points of the demand grid and transitions
% to points on the boundary.
%
% Transitions to an interior point yield a likelihood contribution of
%
% \begin{equation}
% \Pi_{i,j} =   Pr\left[ C'=c_{[j]} |C=c_{[i]}\right]
%           =   \Phi\left(\frac{\log c_{[j]} - \log c_{[i]} +\frac{d}{2}-\mu_C}{\sigma_C}\right)
%             - \Phi\left(\frac{\log c_{[j]} - \log c_{[i]} -\frac{d}{2}-\mu_C}{\sigma_C}\right)
% \end{equation}
%
% Similarly, transition to the lower and upper bound yield likelihood contributions of
% \begin{equation}
% \Pi_{i,1} =   Pr\left[ C'=c_{[1]} |C=c_{[i]}\right]
%           =   \Phi\left(\frac{\log c_{[1]} - \log c_{[i]} +\frac{d}{2}-\mu_C}{\sigma_C}\right)
% \end{equation}
%
% and
%
% \begin{equation}
% \Pi_{i,\check c} = Pr\left[ C'=c_{[\check c ]} |C=c_{[i]}\right]
%                  = 1-\Phi\left(\frac{\log c_{[\check c ]} - \log c_{[i]} -\frac{d}{2}-\mu_C}{\sigma_C}\right),
% \end{equation}
%
% respectively.
%
% We then take the log of the contributions, sum them up, and
% return the negative log-likelihood contribution.

selectInteriorTransitions = to > 1 & to < Settings.cCheck;

likeCont(selectInteriorTransitions ) ...
    = normcdf((Settings.logGrid(to(selectInteriorTransitions)) ...
    - Settings.logGrid(from(selectInteriorTransitions)) + Settings.d / 2 - mu) / sigma)...
    - normcdf((Settings.logGrid(to(selectInteriorTransitions)) ...
    - Settings.logGrid(from(selectInteriorTransitions)) - Settings.d / 2 - mu) / sigma);
 
likeCont(to == 1) = normcdf((Settings.logGrid(1) -...
    Settings.logGrid(from(to == 1)) + Settings.d / 2 - mu) / sigma);
 
likeCont(to == Settings.cCheck) = 1 - normcdf((Settings.logGrid(Settings.cCheck) ...
    - Settings.logGrid(from(to == Settings.cCheck)) - Settings.d / 2 - mu) / sigma);
 
ll = -sum(log(likeCont));

% This concludes |likelihoodStep1|.
end
