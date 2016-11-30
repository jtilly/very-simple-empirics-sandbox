%% lgwt.m
% Gauss Legendre Integration: Written by Greg von Winckel - 02/25/2004
% http://www.mathworks.com/matlabcentral/fileexchange/4540-legendre-gauss-quadrature-weights-and-nodes
function [x,w] = lgwt(N, a, b)
% This function is for computing definite integrals using Legendre-Gauss
% Quadrature. It computes the Legendre-Gauss nodes and weights on an
% interval |[a,b]| with truncation order |N|
%
% Suppose you have a continuous function $f(x)$ which is defined on |[a,b]|
% which you can evaluate at any $x$ in |[a,b]|. Simply evaluate it at all
% of the values contained in the |x| vector to obtain a vector $f(x)$. Then
% compute the definite integral using |sum(f .* w)|;
N = N - 1;
N1 = N + 1;
N2 = N + 2;
xu = linspace(-1, 1, N1)';
y = cos( (2*(0:N)'+1) * pi / (2*N+2) ) + 0.27/N1 * sin(pi*xu*N/N2);
L = NaN(N1, N2);
Lp = NaN(N1, N2);
y0 = 2;
while max(abs(y-y0)) > eps
    L(:, 1) = 1;
    L(:, 2) = y;
    for k = 2:N1
        L(:, k+1) = ( (2*k-1)*y .* L(:,k)-(k-1)*L(:,k-1) ) / k;
    end
    Lp = N2*( L(:,N1)-y.*L(:,N2) )./(1-y.^2);
    y0 = y;
    y = y0-L(:,N2) ./ Lp;
end
x = (a*(1-y) + b*(1+y)) / 2;
w = (b-a) ./ ((1-y.^2) .* Lp.^2) * (N2/N1)^2;
end
