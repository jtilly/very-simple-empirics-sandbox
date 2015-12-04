%% randomDiscr.m

%{ 
  This function generates realizations for each of |K| discrete random 
  variables using the inverse CDF method. Each of the |K| random variables 
  has support |1,2,...,M| and is characterized by the probability mass 
  function |P(:,k)|. This function draws realizations from the Markov chain 
  that governs the demand process. 
%}
function iX = randomDiscr(P)
% 1,2,...,M is the support
M = size(P, 1); 
% number of variables
K = size(P, 2); 
% Draw |K| realizations from $U[0,1]$ and duplicate each realization |M| times 
% to create the matrix |U|, which is of dimension |M|$\times$|K|. 
U = ones(M, 1) * rand(1, K);
% Compute the cumulative distribution function.
cdf = cumsum(P);
% Obtain the smallest element in the support of each of the |K| 
% random variables for which the CDF just exceeds the realization of U. 
iX = 1 + sum(U > cdf);
% The result is a vector |iX| of length |K| with realizations from the 
% collection of discrete random variables governed by |P|.
end
