%% markov.m
%{
This function computes the transition probability matrix |transMat| and the  
ergodic distribution |ergDist| of the demand process. If this function is  
called using only |Param| and |Settings| as inputs, then |Param.demand.transMat| is   
computed using the true values of the demand process parameters $(\mu,\sigma)$ 
that are stored in |Param.truth.step1|. This is used in \textbf{example.m} when  
we generate synthetic data on the number of consumers in each market. In this  
case, we will also compute the ergodic distribution |Param.demand.ergDist|.  
Alternatively, if the function is called with the additional inputs |mu|  
and |sigma|, then these parameter values will be used to compute  
|Param.demand.transMat|. In this case, |Param.demand.ergDist| will not be  
computed. 
%}
function Param = markov(Param, Settings, mu, sigma)

% The code starts with extracting the relevant variables from the 
% |Settings| structure for convenience. If only two input arguments are 
% passed to the function, then the true values for $(\mu,\sigma)$ are used. 

cCheck = Settings.cCheck;
logGrid = Settings.logGrid;
d = Settings.d;

if nargin == 2
    mu = Param.demand.mu;
    sigma = Param.demand.sigma;
end

% 
% The transition probability matrix is computed according to the method 
% outlined by \cite{el1986Tauchen}, which is used to discretize a 
% continuous (and bounded) stochastic process.  We use the standard 
% convention for transition probability matrices. That is, for a transition 
% probability matrix $\Pi$, each entry $\Pi_{i,j}$ gives the probability of 
% transitioning from state $i$ (row) to state $j$ (column). The 
% transition matrix is of dimension $\check c \times \check c$. The idea of 
% the Tauchen method is intuitive - we assumed the growth of $C$ to be 
% normally distributed with parameters |mu| and |sigma|. Since this is a 
% continuous distribution, while the state space is discrete, we treat a 
% transition to a neighborhood around $c_{[j]}$ as a transition to 
% $c_{[j]}$ itself. These neighborhoods span from one mid-point between two 
% nodes on |logGrid| to the next mid-point, i.e. $\left[\log 
% c_{[j]}-\frac{d}{2},\log c_{[j]}+\frac{d}{2}\right]$. Transitions to the 
% end-points of |logGrid| follow the same logic. Distinguishing between transitions 
% to interior points ($j=2,\ldots,\check c -1$) and transitions to 
% end-points ($j=1$ or $j=\check c$), we have three cases. 

transMat = NaN(cCheck, cCheck);

% \begin{equation}
% \Pi_{i,j}=Pr\left[ C'=c_{[j]} |C=c_{[i]}\right] = \Phi\left(\frac{\log
% c_{[j]} - \log c_{[i]} +\frac{d}{2}-\mu}{\sigma}\right)-
% \Phi\left(\frac{\log c_{[j]} - \log c_{[i]}
% -\frac{d}{2}-\mu}{\sigma}\right) 
% \end{equation}

for jX = 2:cCheck-1
    transMat(:,jX) =  normcdf((logGrid(jX)-logGrid'+d/2-mu)/sigma) - normcdf((logGrid(jX)-logGrid'-d/2-mu)/sigma);
end

%
% \begin{equation}
% \Pi_{i,1}=Pr\left[ C'=c_{[1]} |C=c_{[i]}\right] = \Phi\left(\frac{\log
% c_{[1]} - \log c_{[i]} +\frac{d}{2}-\mu}{\sigma}\right) 
% \end{equation}

transMat(:,1) = normcdf((logGrid(1)-logGrid'+d/2-mu)/sigma);

% \begin{equation} \Pi_{i,1}=Pr\left[ C'=c_{[\check c ]} |C=c_{[i]}\right]
% = 1-\Phi\left(\frac{\log c_{[\check c ]} - \log c_{[i]}
% -\frac{d}{2}-\mu}{\sigma}\right) \end{equation}

transMat(:,cCheck) = 1 - normcdf((logGrid(cCheck)-logGrid'-d/2-mu)/sigma);

% This completes the construction of the transition matrix |transMat|,
% which we now store in the |Param| structure.

Param.demand.transMat = transMat;

% Next, we compute the ergodic distribution of the demand process 
% |ergDist|.  The ergodic distribution is only computed for the true 
% parameter values, i.e. when the number of input arguments equals two. The 
% ergodic distribution is the eigenvector of the transpose of the transition matrix with 
% eigenvalue equal to 1 after normalizing it such that its entries sum to  
% unity. The 
% \url{http://en.wikipedia.org/wiki/Perron%E2%80%93Frobenius_theorem#Stochastic_matrices}{Perron-Frobenius Theorem} 
% guarantees that such an eigenvector exists and that all 
% eigenvalues are not greater than 1 in absolute value. We store the 
% eigenvectors of the transition matrix as columns in |eigenVecs|, in 
% decreasing order of eigenvalues from left to right. The eigenvector 
% with  unit eigenvalue is normalized by dividing each element by the sum 
% of elements in the vector, so that it sums to 1 and thus is the ergodic 
% distribution, stored as |ergDist|. Finally, we store |ergDist| in the 
% |Param| structure.  

if nargin == 2
[eigenVecs, eigenVals] = eigs(transMat');
Param.demand.ergDist = eigenVecs(:,1) / sum(eigenVecs(:,1));

% We conclude by checking for two numerical problems that may arise. 
% Firstly, confirm that the greatest eigenvalue is sufficiently close to 1 
% and return an error if it is not. Secondly, due to approximation errors, 
% it may be the case that not all elements in the eigenvector are of the 
% same sign (one of them may be just under or above zero). This will 
% undesirably result in an ergodic distribution with a negative entry. 

if abs(max(eigenVals(:)-1)) > 1e-5
    error('Warning: highest eigenvalue not sufficiently close to 1')
end
 
signDummy = eigenVecs(:,1)>0;
if sum(signDummy)~=0 && sum(signDummy)~=cCheck
    error('Not all elements in relevant eigenvector are of same sign');
end
 
end
