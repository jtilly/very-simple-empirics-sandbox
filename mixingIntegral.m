%% mixingIntegral.m
%{
\textbf{Computing the integral resulting from mixed strategy play}

For a given survival strategy $a_S(n,c,w)$, the likelihood contribution from
(purely) mixed strategy play is given by
\begin{equation} \label{eq:likelihood_mixing_integral}
\int_{\log v_S(n,c)}^{\log v_S(1,c)} {n \choose n'}  a_S(n,c,w)^{n'}
\left(1-a_S(n,c,w)\right)^{n-n'} g_W(w) dw.
\end{equation}
The term inside the integral is the probability mass function of a
binomial distribution function with success probability $a_S(n,c,w)$.
The survival strategies are defined by the indifference condition
\begin{equation} \label{eq:indifference2}
\sum_{n'=1}^{n} {n - 1 \choose n' - 1} a_S^{n' - 1} \left(1-a_S\right)^{n-n'}
\left(- \exp(w)+v_{S}(n',c)\right)=0.
\end{equation}

In principle, we could compute the integral in
(\ref{eq:likelihood_mixing_integral}) directly by naively numerically
integrating over $W$. In practice, it is computationally convenient to do
a change of variables and integrate over the survival strategies
$a_S(n,c,\cdot)$ instead. To make an explicit distinction between the
survival strategy $a_S(n,c,w)$, which is a function of $n$, $c$, and $w$,
and the variable of integration, which is just a scalar. We will refer
to the latter as $p$. Thus, for a given value of $p$, we need to find the
value of $w$ such that $p = a_S(n,c,w)$.

Equation (\ref{eq:indifference2}) defines the inverse $a_S^{-1}(p;c,n)$ for which

\begin{equation}
a_S^{-1}(a_S(n,c,w);c,n) = w.
\end{equation}

This inverse function can be solved for analytically and it is given by

\begin{equation}
\underbrace{a_S^{-1}(p;c,n)}_{\textbf{aSinv}}
= \log \left(\underbrace{\sum_{n'=1}^{n} {n - 1 \choose n' - 1}
      p^{n' - 1} \left(1 - p\right)^{n-n'} v_{S}(n',c) }_{\textbf{expaSInv}}\right)
\end{equation}

Then note that $a_S^{-1}(1;c,n) = \log v_S(n,c)$ and $a_S^{-1}(0;c,n) =
\log v_S(1,c)$.
We can write the likelihood contribution as an integral over $p$:
\begin{equation}
\begin{split}
&\int_{1}^{0} {n \choose n'}  p^{n'} \left(1 - p\right)^{n-n'}
      \times \frac{da_S^{-1}(p;c,n)}{dp}g_{W}\left[a_S^{-1}(p;c,n)\right]
      dp \\
= &-\int_{0}^{1} {n \choose n'}  p^{n'} \left(1 - p\right)^{n-n'}
      \times \frac{da_S^{-1}(p;c,n)}{dp}g_{W}\left[a_S^{-1}(p;c,n)\right]
      dp \\
\approx &-\sum_{jX=1}^J {n \choose n'}  p_{jX}^{n'}
\left(1 - p_{j}\right)^{n-n'} \times
\underbrace{\underbrace{\frac{da_S^{-1}(p_{j};c,n)}{dp}}_{\textbf{daSinvdP}}
\underbrace{g_{W}\left[a_S^{-1}(p_{j};c,n)\right]}_{\textbf{normaSinv}}
\underbrace{w_{j}}_{\textbf{intWeights}}}_{\textbf{mixingDensity}},
\end{split}
\label{llContrMixing}
\end{equation}

where $p_{1}, ..., p_{J}$ refer to the
\url{http://en.wikipedia.org/wiki/Gaussian_quadrature}{Gauss-Legendre}
nodes and $w_{1}, ..., w_{J}$ to the corresponding weights. Notice that the
integration bounds are now 0 and 1 since if $w<\log v_S(n,c)$ the firms
surely survive and when $w>\log v_S(1,c)$ the firms surely exit.
Differentiation of $a_S^{-1}(p;c,n)$ gives

\begin{equation}
\underbrace{\frac{da_S^{-1}(p;c,n)}{dp}}_{\textbf{daSinvdP}} =
 \overbrace{ \sum_{n'=1}^{n} \overbrace{{n - 1 \choose n' - 1}
\left(p^{n'-2} (1 - p)^{(n-n' - 1)} \left( (n' - 1) (1 - p) - p (n-n') \right) \right)}^{\textbf{dbinomialPmfdP}} v_{S}(n',c)}^{\textbf{dexpaSInvdP}} \frac{1}{\underbrace{\exp(a_S^{-1}(p;c,n))}_{\textbf{expaSInv}}}
\end{equation}

Now, compute the matrix |mixingDensity| using (\ref{mixingDensity}). |mixingDensity| is of dimension
|Settings.integrationLength| by |Settings.cCheck| by |Settings.nCheck|. It is
defined as

\begin{equation}
      \text{mixingDensity(j,c,n)} =
      \underbrace{\frac{da_S^{-1}(p_{j};c,n)}{dp}}_{\textbf{daSinvdP}}
      \underbrace{g_{W}\left[a_S^{-1}(p_{j};c,n)\right]}_{\textbf{normaSinv}}
      \underbrace{w_{j}}_{\textbf{intWeights}}. \label{mixingDensity}
\end{equation}

The element $(p_{j}, c, n)$ gives us the density
of the mixing probability $p_{j}$ when demand equals $c$ and the
current number of incumbents is $n$.

In the function |mixingIntegral| we compute the integral in equation
(\ref{eq:likelihood_mixing_integral}) for a range of different combinations
of $n$, $n'$, and $c$ using the change of variable introduced above.
The function |mixingIntegral| takes as arguments the vectors |from|, |to|,
and |demand|, which correspond to $n$, $n'$, and $c$, respectively. The
function also takes as argument |vS|, the equilibrium post-survival value
functions, and the |Param| and |Settings| structures. The function returns a
vector |llhContributionsMixing| that is of the same dimension as the inputs
|from|, |to|, and |demand|.
%}

function [llhContributionsMixing] = ...
    mixingIntegral(from, to, demand, vS, Param, Settings)

%{
Note that mixed strategy play is only relevant for markets with at least
two firms. We define the auxiliary variable |expaSInv|, which equals
|expaSInv = exp(aSinv(:, :, n))|. |dexpaSInvdP| is another auxiliary variable
that stores the derivative of |expaSInv| with respect to |p|. Then assemble
|expaSInv| and |dexpaSInvdP| by looping over the possible outcomes from
mixing |nPrime=0,...,n|. |nPrime=0| refers to the case when all firms leave
due to mixed strategy play and |nPrime=n| refers to the case when all firm
stay due to mixed strategy play. Then, use |val| to compute |aSinv| and
compute the derivative with respect to |p| and store it as |daSinvdP|.
Lastly, we compute the mixing density.

We pre-compute |nchoosekMatrixPlusOne| which is a matrix of size $\check
n + 1$ by $\check n + 1$, where element $(i,j)$ contains $i - 1 \choose j - 1$. The
copious naming and indexing convention is owed to the fact that |Matlab|
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

mixingDensity = zeros(Settings.integrationLength, ...
                      Settings.cCheck, ...
                      Settings.nCheck);
aSinv = zeros(size(mixingDensity);
daSinvdP = zeros(size(mixingDensity);

p = Settings.integrationNodes;
w = Settings.integrationWeights;

for n = 2:Settings.nCheck

    expaSInv = zeros(length(p), Settings.cCheck);
    dexpaSInvdP = zeros(length(p), Settings.cCheck);

    for nPrime = 1:n

        nChoosek = nchoosekMatrixPlusOne(n, nPrime);
        binomialPmf = nChoosek .* repmat(p .^ (nPrime - 1) ...
            .* (1 - p) .^ (n - nPrime), 1, Settings.cCheck);
        dbinomialPmfdP = nChoosek .* repmat(p .^ (nPrime-2) ...
            .* (1 - p) .^ (n - nPrime - 1) ...
            .* ( (nPrime - 1) .* (1 - p) - p .* (n - nPrime)), 1, Settings.cCheck);
        repvS =  repmat(vS(nPrime, :), Settings.integrationLength,1);
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
% we only need to loop over all those observations where ``purely'' mixed
% strategy play does in fact occur.

llhContributionsMixing = zeros(length(from), 1);
for jX = 1:length(from)
    if(from(jX) > 1)
        nChoosek = nchoosekMatrixPlusOne(from(jX) + 1, to(jX) + 1);
        llhContributionsMixing(jX) = ...
            - sum(nChoosek .* p .^ to(jX) .* (1 - p) .^ (from(jX) - to(jX)) ...
                      .* mixingDensity(:,  demand(jX), from(jX)));
    end
end

% Note that it is possible to improve the performance of the code by only
% calling this function once instead of three times as we currently do in
% the likelihood function computation. However, that makes the code somewhat
% more difficult to follow, which is why we opted for the slightly slower
% version.
