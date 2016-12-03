%% randomDiscr.m

%{
  This function randomly draws realizations from discrete probability
  distributions using the inverse cumulative distribution function method. The
  idea is to first draw a realization from a uniform distribution and then map
  that draw, a probability, into the corresponding mass point of the discrete
  distribution. This function is written to draw one realization each from
  |K| distributions at a time. Each of the |K| distributions is assumed to be
  defined over |M| points.

  The function takes as input a matrix |P| which is of dimension |M| times |K|.
  In this matrix, each column corresponds to a probability mass function.

%}
function iX = randomDiscr(P)
	M = size(P, 1);
	K = size(P, 2);
	U = ones(M, 1) * rand(1, K); % % Draw uniform random variables
	cdf = cumsum(P); % % Compute CDF
	iX = 1 + sum(U > cdf); % % Find mass point that corresponds to U
% The result is a vector |iX| of length |K| with realizations from the discrete
% distributions described by |P|.
end
