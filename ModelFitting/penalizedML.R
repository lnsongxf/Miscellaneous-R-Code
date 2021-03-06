#---------------------------------------------------------------------------------#
# A standard regression model via penalized likelihood.  See the standardlm.R     #
# code for comparison. Here the penalty is specified (via lambda argument) but    # 
# one would typically estimate via cross-validation or some other fashion. Two    #
# penalties are possible with the function.  One using the (squared) L2 norm (aka #
# ridge regression, tikhonov regularization), another using the L1 norm (aka      #
# lasso) which has the possibility of penalizing coefficients to zero, and thus   #
# can serve as a model selection procedure. I have a more technical appraoch to   # 
# the lasso in the lasso.R file.                                                  #
#                                                                                 #
# Note that both L2 and L1 approaches can be seen as maximum a posteriori (MAP)   #
# estimates for a Bayesian regression with a specific prior on the coefficients.  #
# The L2 approach is akin to a normal prior with zero mean, while L1 is akin to   #
# a zero mean Laplace prior.  See the Bayesian scripts for ways to implement.     #
#---------------------------------------------------------------------------------#


##############
# Data Setup #
##############
set.seed(123)  # ensures replication

# predictors and response
N = 100 # sample size
k = 2   # number of desired predictors
X = matrix(rnorm(N*k), ncol=k)  
y = -.5 + .2*X[,1] + .1*X[,2] + rnorm(N, sd=.5)  # increasing N will get estimated values closer to these

dfXy = data.frame(X,y)



#############
# Functions #
#############
# A maximum likelihood approach
penalML = function(par, X, y, lambda=.1, type='L2'){
  # arguments- par: parameters to be estimated; X: predictor matrix with
  # intercept column; y: response, lambda: penalty coefficient; type: penalty
  # approach
  
  # setup
  beta = par[-1]                               # coefficients
  sigma2 = par[1]                              # error variance
  sigma = sqrt(sigma2)
  N = nrow(X)
  
  # linear predictor
  LP = X%*%beta                                # linear predictor
  mu = LP                                      # identity link in the glm sense
  
  # calculate likelihood
  L = dnorm(y, mean=mu, sd=sigma, log=T)       # log likelihood
  
  PL = switch(type,
              'L2' = -sum(L) + lambda*crossprod(beta[-1]),   # the intercept is not penalized
              'L1' = -sum(L) + lambda*sum(abs(beta[-1]))
              )
}


# glmnet style approach that will put the lambda coefficient on equivalent
# scale; Uses a different objective function.  Note that glmnet is actually
# 'elasticnet' and mixes both L1 and L2 penalties

penalML2 = function(par, X, y, lambda=.1, type='L2'){
  # arguments- par: parameters to be estimated; X: predictor matrix with
  # intercept column; y: response, lambda: penalty coefficient; type: penalty
  # approach
  
  # setup
  beta = par                                   # coefficients
  N = nrow(X)
  
  # linear predictor
  LP = X%*%beta                                # linear predictor
  mu = LP                                      # identity link in the glm sense
  
  obj = switch(type,
               'L2' = .5*crossprod(y-X%*%beta)/N + lambda*crossprod(beta[-1]),
               'L1' = .5*crossprod(y-X%*%beta)/N + lambda*sum(abs(beta[-1]))
  )
}



##############################
### Obtain Model Estimates ###
##############################
### Setup for use with optim
X = cbind(1, X)

# initial values; note we'd normally want to handle the sigma differently as it's
# bounded by zero, but we'll ignore for demonstration; also sigma2 is not required
# for the LS approach
init = c(1, rep(0, ncol(X)));  names(init)=c('sigma2', 'intercept','b1', 'b2')

optlmpenalMLL2 = optim(par=init, fn=penalML, X=X, y=y, lambda=1, control=list(reltol=1e-12))
optlmpenalMLL1 = optim(par=init, fn=penalML, X=X, y=y, lambda=1, type='L1', control=list(reltol=1e-12))

parspenalMLL2 = optlmpenalMLL2$par
parspenalMLL1 = optlmpenalMLL1$par



##################
### Comparison ###
##################
### compare to lm
modlm = lm(y~., dfXy)

round(rbind(parspenalMLL2,
            parspenalMLL1, 
            modlm = c(summary(modlm)$sigma^2, coef(modlm))), 4)

### compare to glmnet; setting alpha to 0 and 1 is equivalent L2 and L1 respectively; you also wouldn't want to specify lambda normally, and rather let it come about as part of the estimation procedure.  We do so here just for demonstration.
library(glmnet)
glmnetL2 = glmnet(X[,-1], y, alpha=0, lambda=.01, standardize=F)
glmnetL1 = glmnet(X[,-1], y, alpha=1, lambda=.01, standardize=F)


round(rbind(t(as.matrix(coef(glmnetL2))), 
            functionoutput=optim(par=init[-1], fn=penalML2, X=X, y=y, 
                                 lambda=.01, control=list(reltol=1e-12))$par), 
      4)

round(rbind(t(as.matrix(coef(glmnetL1))), 
            functionoutput=optim(par=init[-1], fn=penalML2, X=X, y=y, 
                                 lambda=.01, type='L1', control=list(reltol=1e-12))$par), 
      4)

