%% likelihoodStep3.m
% This function computes the full information likelihood. This step only
% involves taking the product of the likelihood contributions from the
% first two steps. Here we will also go over the computation of standard
% errors. The function |likelihoodStep3| requires the structures |Data|,
% |Settings|, and |Param|, and the vector |estimates| as inputs.
% The arguments returned include the negative log likelihood
% function |ll|, a vector of standard errors |se|, a vector of the
% likelihood contributions |likeCont|, and the covariance matrix
% |covariance|.

function [ ll, se, likeCont, covariance] = likelihoodStep3(data, Settings, Param, estimates)

% Create the transition probability matrix based on the estimates for |mu|
% and |sigma| which are stored as the last two elements in |estimates|.
% Then retrieve the vectors of likelihood contributions from the first two
% steps and compute the negative log likelihood function of the third step:

Param = markov(Param, Settings, estimates(end - 1), estimates(end));
[~, likeCont1] = likelihoodStep1(data, Settings, estimates(end - 1:end));
[~, likeCont2] = likelihoodStep2(data, Settings, Param, estimates(1:end - 2));
ll = -sum(log(likeCont1) + log(likeCont2));

% This completes the construction of the full information negative log
% likelihood function. When only one output argument is requested, then the
% function is done.
if(nargout==1)
    return;
end

% When three output arguments are requested, the function returns the
% likelihood contributions, which are simply the element-by-element product
% of the likelihood contributions vectors from the first two steps. In this
% case, we return no standard errors, i.e. we set |se=[]|.
if(nargout==3)
    se = [];
    likeCont = likeCont1 .* likeCont2;
    return;
end

% Now, consider the case, when exactly two output arguments are
% requested. In this case, we want to compute the standard errors. As
% discussed in the paper, standard errors are computed using
% the outer-product-of-the-gradient estimator of the information matrix.
% When two output arguments are requested when calling |likelihootStep3.m|,
% the function will return standard errors in addition to the log
% likelihood function. When three output arguments are requested, the
% function also returns the likelihood contributions.
% Define the matrix of perturbations, which is simply a diagonal matrix
% with |Settings.fdStep| on each diagonal element.

epsilon = eye(length(estimates)) * Settings.fdStep;

% Next, get the likelihood contributions at the parameter values in
% |estimates|:

likeCont = likeCont1 .* likeCont2;

% Now, given the likelihood contribution $\ell(\theta) \equiv
% \ell(\theta_j, \theta_{-j})$  we compute for each  parameter $\theta_j$
% the positively and negatively perturbed likelihood contributions
% $\ell(\theta_j+\epsilon,\theta_{-j})$ and
% $\ell(\theta_j-\epsilon,\theta_{-j})$. The gradients of the negative log
% likelihood contributions are then computed using central finite
% differences:
%
% \begin{equation}
% \frac{\partial \log \left(\ell \left(
% \theta \right) \right)}{\partial \theta_j} = \frac{\partial \log \left(
% \ell \left(\theta \right) \right)}{\partial \ell \left(\theta \right)}
% \cdot \frac{d \ell \left(\theta \right))}{d \theta_j} \approx
% \frac{\partial \log \left(\ell \left(\theta \right) \right)}{\partial
% \ell \left(\theta \right)} \cdot \frac{ \ell \left(
% \theta_j+\epsilon,\theta_{-j} \right) - \ell \left(
% \theta_j-\epsilon,\theta_{-j} \right))}{2\epsilon}
% \end{equation}
%
% The matrix of gradient contributions |gradCont| has
% $(\check t  - 1)\cdot \check r $ rows and one column for each
% parameter with respect to which we are differentiating the logged
% likelihood contributions.

gradCont = zeros(Settings.rCheck*(Settings.tCheck - 1), length(estimates));

for j = 1:length(estimates)
    [~, ~, likeContribPlus] = likelihoodStep3(data, Settings, Param, estimates + epsilon(j, :) );
    [~, ~, likeContribMinus] = likelihoodStep3(data, Settings, Param, estimates - epsilon(j, :) );
    gradCont(:, j) = (likeContribPlus - likeContribMinus) / (2 * Settings.fdStep) ./ likeCont;
end

% We now have the matrix |gradCont| where each column is the score with
% respect to an estimable parameter. This matrix is used to compute the
% |Hessian| (full information matrix). We take the sum  of the
% outer-product of the market specific gradients over all markets. A market
% specific gradient is a row in |gradCont|. Looping over all rows, in each
% iteration we compute the outer product of a market specific gradient and
% add them all up:

Hessian = zeros(length(estimates));
for iX=1:size(gradCont, 1)
    Hessian = Hessian + gradCont(iX, :)' * gradCont(iX, :);
end

% The covariance matrix can be obtained from inverting the Hessian. The
% standard errors are the square roots of the diagonal entries of the
% covariance matrix.

covariance = inv(Hessian);
se = sqrt(diag(covariance))';

% This concludes |likelihoodStep3|.
end
