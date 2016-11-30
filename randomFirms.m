%% randomFirms.m
%{
This function randomly draws a realization of the post-survival number of
active firms given last period's post-survival number of active firms
and the current period's demand state and cost shock. The computation of
the number of firms follows the construction of the unique symmetric Nash
equilibrium of the one-shot survival game (see the discussion preceding
Corollary 1 in the paper), which takes advantage of the monotonicity of
$v_S(n,c)$ (see Lemma 2).  Given $n$, $c$, and $w$, the possible
realizations of $N'$ can be classified using the following cases:

 \begin{itemize}

 \item $v_S(1,c) \leq \exp (w)$: In this case, even a monopolist would not
be willing to remain active. Thus, all firms leave the market for sure and
there is no entry. This case is only relevant when $n>0$, i.e. when there is a
positive number of incumbents. If the number of incumbents is equal to
zero, and the above condition holds, then there will not be any entry and
the number of firms remains at zero.

 \item $v_S(n,c) \leq \exp (w) < v_S(1,c)$: In this case, a monopolist finds
survival profitable, but the current number of firms $n$ does not. Thus,
some firms will be leaving the market and firms' survival strategies
satisfy $a_S(n,c, w) \in (0,1)$. $N'$ follows a binomial
distribution with $n$ trials and success probability $a_S(n,c,w)$.
This case is only well defined when $n>1$.

 \item $v_S(n,c) > \exp (w) $: All $n$ incumbents find survival profitable.
In addition, there may be some entry. We will use the entry strategies to
compute $n'$. In fact, we will count for how many $n'$ the entry condition
$v_S(n',c) > (1+\varphi) \exp (w) $ is satisfied. This case is only
relevant if $n<\check n$, i.e. the current number of incumbents is
strictly less than $\check n$. If $n=\check n$, there will not be any
entry by construction.

 \end{itemize}

 The function takes as inputs last period's post-survival number of active firms
|N|, the current number of consumers |C|, the realized cost shock |W|, and
the equilibrium post-survival value function, |vS|. |N|, |C|, and |W|
are column vectors of length |rCheck| containing one entry per
market. The output is the column vector |Nprime| of length |rCheck|,
which contains the post-survival number of active firms in each market.
%}

function Nprime = randomFirms(N, C, W, Settings, Param, vS)

Nprime = NaN(size(N));

for nX = 1:Settings.rCheck
    
    switch (true)
        %\% All firms leave (only relevant if N(nX)>0)
        case N(nX) > 0 && (vS(1, C(nX)) <= exp(W(nX)))
            Nprime(nX) = 0;
            
        %\% Some firms leave (only relevant if N(nX) > 1)
        case N(nX) > 1 && (vS(max(1,N(nX)), C(nX)) <= exp(W(nX)))
            aS = mixingProbabilities(N(nX), C(nX), W(nX), vS);
            Nprime(nX) = binornd(N(nX), aS);
            
        %\% All incumbents stay; there may be entry.
        case N(nX) < Settings.nCheck && (vS(max(1, N(nX)), C(nX)) > exp(W(nX)))
            Nprime(nX) = N(nX) + sum(vS((N(nX) + 1):Settings.nCheck, C(nX)) ...
                - (1 + Param.phi((N(nX) + 1):Settings.nCheck)') .* exp(W(nX)) > 0);
            
        %\% Remaining cases include N(nX)=0 and no entry, or N(nX)=Settings.nCheck and no exit).
        otherwise
            Nprime(nX) = N(nX);
    end
end
% This concludes \textbf{randomFirms}.
end
