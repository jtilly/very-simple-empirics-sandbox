% The script starts with setting the seed for the random number generators.
% Setting the seed ensures that the results of this program can be
% replicated regardless of where and when the code is run. That is, once
% the seed is set, users can make changes to the code and be sure that
% changes in the results are not because different random values were
% generated.
s = RandStream('mlfg6331_64');
RandStream.setGlobalStream(s);

% Next, we define two variable structures. The |Settings| structure
% collects various settings used in the remainder of the program. The
% |Param| structure collects the true parameter values to be used in the
% generation of the data.
%
% The NFXP algorithm crucially depends on two tolerance parameters. The
% tolerance parameters |tolInner| and |tolOuter| refer to the inner
% tolerance for the iteration of the value function when the model is
% solved, and the outer tolerance for the likelihood optimizations,
% respectively. As discussed in the paper, we follow
% \cite{ecta2012DubeFoxSu} by ensuring that the inner tolerance is smaller
% than the outer tolerance to prevent false convergence. |maxIter| stores
% the maximum number of iteration steps that are allowed during the value
% function iteration.

Settings.tolInner = 1e-10;
Settings.tolOuter = 1e-6;
Settings.maxIter = 1000;

% The maximum number of firms that can ever be sustained in equilibrium is
% defined as |nCheck|.

Settings.nCheck = 5;

% There are three parameters that govern the support of the demand
% process. |cCheck| is the number of possible demand states.  |lowBndC| and
% |uppBndC| are the lower and upper bounds of the demand grid,
% respectively.

Settings.cCheck = 200;
Settings.lowBndC = 0.5;
Settings.uppBndC = 5;

% We define the grid |logGrid| as a row vector with $\check c$
% elements that are equidistant on the logarithmic scale. |d| is
% the distance between any two elements of |logGrid|.

Settings.logGrid = ...
linspace(log(Settings.lowBndC), log(Settings.uppBndC), Settings.cCheck);
Settings.d = Settings.logGrid(2) - Settings.logGrid(1);

% Next, we define the number of markets |rCheck| and the number of time
% periods |tCheck|. In the data generating process (\textbf{dgp.m}), we
% will draw data for |tBurn + tCheck| periods, but only store the last
% |tCheck| time periods of data.  |tBurn| denotes the number of burn-in
% periods that are used to ensure that the simulated data refers to the
% approximately ergodic distribution of the model.

Settings.rCheck = 1000;
Settings.tCheck = 10;
Settings.tBurn = 100;

% Standard errors are computed using the outer-product-of-the-gradient
% method. To compute the gradients (likelihood scores) we use two sided
% finite differences. The parameter |fdStep| refers to the step size of
% this  approximation.

Settings.fdStep = 1e-7;

% To compute the likelihood contribution of purely mixed strategy play, we
% will need to numerically integrate over the support of the survival
% strategies, $(0,1)$. We will do so using Gauss-Legendre quadrature.
% |truncOrder| refers to number of Gauss-Legendre nodes used. We document
% the function \textbf{lgwt.m} in the Appendix.

Settings.truncOrder = 32;
[Settings.integrationNodes, Settings.integrationWeights] = ...
    lgwt(Settings.truncOrder, 0, 1);

% We can now define the settings for the optimizer used during the
% estimation. Note that these options will be used for \textsc{Matlab}'s
% constrained optimization function \textbf{fmincon}.

options = optimset( 'Algorithm', 'interior-point', 'Display', 'iter', ...
    'TolFun', Settings.tolOuter, 'TolX', Settings.tolOuter, ...
    'GradObj', 'off');

% We now define the true values listed in the paper for the parameters of
% the model, starting with the discount factor:

Param.rho = 1/1.05;

% The true values for the estimated parameters in $\theta$ are defined as

Param.k = [1.8, 1.4, 1.2, 1, 0.9];
Param.phi = [10, 10, 10, 10, 10];
Param.omega = 1;
Param.demand.mu = 0;
Param.demand.sigma = 0.02;

% We then collect the true parameter values into a vector for each of the
% three steps of the estimation procedure.

Param.truth.step1 = [Param.demand.mu, Param.demand.sigma];
Param.truth.step2 = [Param.k, Param.phi(1), Param.omega];
Param.truth.step3 = [Param.truth.step2, Param.truth.step1];

 
% We now generate a synthetic sample that we will then estimate using the
% three step estimation procedure. We begin the data generation by computing
% the transition matrix and the ergodic distribution of the demand process,
% using the true values for its parameters $(\mu_C, \sigma_C)$. This is done using the function
% \textbf{markov.m}, which creates the $\check c \times \check c$ transition matrix
% |Param.demand.transMat| and the $\check c \times 1$ ergodic distribution
% |Param.demand.ergdist|. We document \textbf{markov.m} in the Appendix.

Param = markov(Param, Settings);

% Next, we generate the dataset $(n,c)$ using \textbf{dgp.m}. This creates
% the two $\check t \times \check r$ matrices |data.C| and |data.N|. Then
% construct the |from| and |to| matrices of size $(\check t -1)\times
% \check r $ as we did in \textbf{likelihoodStep1.m}.

Data = dgp(Settings, Param);
to = Data.C(2:Settings.tCheck, 1:Settings.rCheck);
from = Data.C(1:Settings.tCheck-1, 1:Settings.rCheck);

% These matrices  include $C_{t,r}$  and $C_{t+1,r}$, respectively, for
% $t=1,\ldots,\check t -1$ and $r=1,\ldots,\check r $, as given in the
% $\check{t}\times \check r $ matrix |Data.C|. As discussed above, we use
% the mean and standard deviations of the innovations in logged demand as
% starting values for $(\mu_C, \sigma_C)$. These are stored in
% |startValues.step1|

logTransitions = log([from(:) to(:)]);
innovLogC = logTransitions(:, 2) - logTransitions(:, 1);
startValues.step1 = [mean(innovLogC)  std(innovLogC)];

% Declare the first step likelihood function to be the objective function.
% This is an anonymous function with parameter vector |estimates|

objFunStep1 = @(estimates) likelihoodStep1(Data, Settings, estimates);

% Store the negative log likelihood evaluated at the true values of
% $(\mu_C, \sigma_C)$. This will later allow us to compare the negative log
% likelihood function at the final estimates to the negative log likelihood
% function at the true parameter values (the former should always be
% smaller than the latter).

llhTruth.step1 = objFunStep1(Param.truth.step1);

% Next, maximize the likelihood function using \textbf{fmincon}.  The only
% constraint under which we are maximizing is that $\sigma >0$. We impose
% this constraint by specifying the lower bound of $(\mu_C, \sigma_C)$ to be
% |[-inf,0]|. The estimates of $(\mu_C, \sigma_C)$ are stored in
% |Estimates.step1|, the likelihood at the optimal value is stored in
% |llh.step1| and the exit flag (the reason for which the optimization
% ended) is stored in |exitFlag.step1|.

tic;
[Estimates.step1, llh.step1, exitFlag.step1] = fmincon(objFunStep1, ...
    startValues.step1, [], [], [], [], [-inf, 0], [], [], options);
computingTime.step1 = toc;

% Now consider the second step, in which we estimate $(k,\varphi,\omega)$.
% Start by creating anonymous functions which will be used in
% \textbf{likelihoodStep2.m} to map the vector of parameter estimates into
% the |Param| structure:

Settings.estimates2k = @(x) x(1:Settings.nCheck);
Settings.estimates2phi = @(x) x(6) * ones(1, Settings.nCheck);
Settings.estimates2omega = @(x) x(7);

% Starting values are the same random draw from a uniform distribution on
% $[1,5]$:

startValues.step2 = 1 + 4 * ones(1, length(Param.truth.step2)) * rand;

% Applying \textbf{markov.m}, we then generate
% the transition matrix and ergodic distribution using the estimated values
% $(\hat \mu,\hat \sigma)$ from the first step as the parameters for the
% demand process:

Param = markov(Param, Settings, Estimates.step1(1), Estimates.step1(2));

% Declare the objective function as in the first step:

objFunStep2 = @(estimates) likelihoodStep2(Data, Settings, Param, estimates);

% The maximization is constrained by imposing that $(\hat k,\hat
% \varphi,\hat \omega)$ are nonnegative. Store the negative log-likelihood
% at the true parameter values:

lb = zeros(size(startValues.step2));
llhTruth.step2 = objFunStep2(Param.truth.step2);

% Then, minimize the objective function:

tic;
[Estimates.step2,llh.step2,exitFlag.step2] = fmincon(objFunStep2, ...
    startValues.step2, [], [], [], [], lb, [], [], options);
computingTime.step2 = toc;

% The results are stored as in the first step.

% Now consider the third step, FIML. Start by declaring the estimates from
% the first two steps to be the starting values for the third step:

startValuesStep3 = [Estimates.step2, Estimates.step1];

% Declare the objective function:

objFunStep3 = @(estimates) likelihoodStep3(Data, Settings, Param, estimates);

% The lower bound for all parameter is zero, except for $\mu_C$ which is
% unbounded. $\mu_C$ corresponds to the second-last entry in the list of
% parameters:

lb = zeros(size(startValuesStep3));
lb(length(startValuesStep3) - 1) = -inf;

% Store the negative log-likelihood at the true parameter values:

llhTruth.step3 = objFunStep3(Param.truth.step3);

% Obtain the estimates subject to the constraints |lb|:

tic;
[Estimates.step3, llh.step3, exitFlag.step3] = fmincon(objFunStep3,...
    startValuesStep3, [], [], [], [], lb, [], [], options);
computingTime.step3 = toc;

% Compute the standard errors by requesting two output arguments, and store
% these in |Estimates.se|

[~,Estimates.se] = likelihoodStep3(Data, Settings, Param, Estimates.step3);

% which concludes the estimation of the synthetic sample.
