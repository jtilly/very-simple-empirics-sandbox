%% dgp.m
%{
This function generates data $(N,C,W)$ for |Settings.rCheck| markets and
|Settings.tCheck| time periods. Demand in the first period is drawn from
the ergodic distribution. To eliminate initial condition effects,
|Settings.tBurn|+|Settings.tCheck| periods will be generated, but only the
last |Settings.tCheck| periods will be used. The function
requires the structures |Settings| and |Param| as inputs. The function
returns a |Data| structure with three $\check t \times \check r$ matrices
|N|, |C|, and |W|, where each entry corresponds to some time period $t$ in
some market $r$. |N|  contains the number of active firms. |C| contains the
index for the demand grid |logGrid| that corresponds to the demand state.
|W| consists of realizations of the cost shocks. In practice, |W| is
unobserved to the econometrician and thus we will not use it during the
estimation. Here, we return |W| as additional information that can be used
to debug the program or to compute additional statistics, such as the
average realized fixed costs or the average realized entry costs.
%}

function Data = dgp(Settings, Param)

N = NaN(Settings.tBurn + Settings.tCheck, Settings.rCheck);
C = NaN(Settings.tBurn + Settings.tCheck, Settings.rCheck);

% We now compute the post-survival equilibrium value functions using
% \textbf{valueFuncrionIteration}:
vS = valueFunctionIteration(Settings,Param);

% The cost shocks are iid across markets and periods, so we can draw them
% all at once and store them in the matrix |W| which is of dimension
% |Settings.tBurn + Settings.tCheck| by |Settings.rCheck|.
W = Param.omega * randn(Settings.tBurn + Settings.tCheck, Settings.rCheck) -0.5 * Param.omega ^ 2;

% Next, we draw an initial demand state from the ergodic distribution of
% the demand process for each market using the \textbf{randomDiscr}
% function, which is documented in the appendix. With the initial demand state for each market in hand, for each
% time period we use the transition matrix to draw the current demand state
% given the previous state:

C(1,:) = randomDiscr(repmat(Param.demand.ergDist, 1, Settings.rCheck));
for t = 2 : Settings.tBurn + Settings.tCheck
    C(t, :) = randomDiscr(Param.demand.transMat(C(t - 1, :), :)');
end

% The initial number of firms in each market is drawn randomly from a
% discrete uniform distribution on $\{ {1,2,\ldots ,\check n } \}$. In each
% period following the first one, the number of firms is generated using
% the \textbf{randomFirms} function, which randomly draws realizations of
% the cost shocks and then uses the firms' equilibrium strategies to update
% the number of active firms. We draw the numbers of firms separately for
% the burn-in phase and the real sample, because for the latter we also
% want to store the realized fixed and entry costs.

N(1,:) = randsample(Settings.nCheck, Settings.rCheck, true);

for t = 2:Settings.tBurn+Settings.tCheck
    N(t, :) = randomFirms(N(t - 1, :)', C(t, :)', W(t, :)', Settings, Param, vS);
end

% Now we have the matrices |N|, |C|, and |W|; each of dimension
% |Settings.tBurn + Settings.tCheck| by |Settings.rCheck|. From this, we store only the
% last |Settings.tCheck| periods in the structure |Data|:
Data.C = C((end - Settings.tCheck + 1):end, :);
Data.N = N((end - Settings.tCheck + 1):end, :);
Data.W = W((end - Settings.tCheck + 1):end, :);

% This concludes the function \textbf{dgp}.
end
