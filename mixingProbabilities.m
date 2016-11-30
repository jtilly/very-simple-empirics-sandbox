%% mixingProbabilities.m
%{
This function computes the mixing probability for a market with |N| 
firms, demand state |C|, and cost shock |W|, where the post-survival 
value function is given by |vS|. The inputs |N|, |C|, and |W| are all of 
the same size and describe one market each. They can be a vector or a scalar valued.  
The function returns the mixing probabilities |aS| which is a vector (or 
scalar) of the same size as the inputs |N|, |C|, and |W|. 
%}

function aS = mixingProbabilities(N, C, W, vS)

%{
The function will solve 
(\ref{indifference}) for $a_S$ using \textsc{Matlab's} |roots| function. 
For the |roots| function to work, we need to transform 
(\ref{indifference}) into polynomial form, which is given by 
\begin{equation}  
\sum_{n'=0}^{n_E-1} 
\underbrace{\left[\sum_{i=0}^{n'} \underbrace{ \underbrace{(-1)^{n'-i}}_{\textbf{signCoef}} 
\underbrace{\frac{(n_E-1)!}{i!(n_E-1-n')!(n'-i)!}}_{\textbf{nCk}} 
\underbrace{\left(-\exp(w) + v_S(i + 1,c) 
\right)}_{\textbf{continuationValue}}}_{\textbf{matCoef}} \right]}_{\textbf{vecCoef}} a_S^{n'} =0, 
\end{equation} 
where the relevant \textsc{Matlab} variables are marked in bold font. 

 Preallocate a vector of zeros with the survival strategies that will 
subsequently be filled and then loop over each element in |N|. 
%}

aS = zeros(size(N));
for iX=1:length(N)

% Store the post-entry number of active firms in a scalar |nE|. Preallocate 
% the matrix |matCoef| to store the coefficients of the polynomial above. 
% Then assemble the coefficients by looping from |nE-1| to |0|. 

    nE = N(iX);
    matCoef = zeros(nE);
    for jX=(nE - 1):-1:0
        signCoef = (-1) .^ (jX - (0:jX));
        nCk = factorial(nE - 1) / factorial(nE - 1 - jX) ./ (factorial(0:jX) .* factorial(jX - (0:jX)));
        continuationValue = (-exp(W(iX)) + vS(1:(jX + 1), C(iX)))';
        matCoef(nE-jX, 1:(jX + 1)) = signCoef .* nCk .* continuationValue;
    end

    vecCoef = sum(matCoef, 2);

% We then compute the candidate values for the mixing probabilities using 
% |roots|, and nullify (|[]|) all values that are smaller than 0 or larger than 1. 
% When the only root is really close to 0 or to 1, \textsc{Matlab} may 
% return a couple of undesired complex roots as a bonus. We nullify these candidates as well.  
% Finally, we pick the remaining root (which we know exists and is unique). 

    mixprobcand = roots(vecCoef);
    mixprobcand( mixprobcand<0 | mixprobcand>1 ) = [];
    mixprobcand(real(mixprobcand) ~= mixprobcand) = [];
    if(length(mixprobcand) ~= 1)
       error('The number of roots between 0 and 1 is not equal to 1.'); 
    end
    aS(iX) = mixprobcand;

end
% This concludes \textbf{mixingProbabilities}.
end