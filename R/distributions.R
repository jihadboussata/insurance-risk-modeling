# Working marginal likelihoods. Repeated policies mean rows are not iid replicates.
fit_counts <- function(x) {
  mu <- mean(x)
  if (mu <= 0) stop("Positive mean claim count required.")
  opt <- optimize(function(log_size) -sum(dnbinom(x, size = exp(log_size), mu = mu, log = TRUE)),
                  interval = c(-10, 20))
  size <- exp(opt$minimum)
  ll <- c(sum(dpois(x, mu, log = TRUE)), -opt$objective)
  data.frame(model = c("Poisson", "Negative binomial"), mean = mu, size = c(NA, size),
             log_likelihood = ll, aic = 2*c(1,2)-2*ll, bic = log(length(x))*c(1,2)-2*ll)
}

positive_fits <- function(x) {
  if (any(x <= 0)) stop("Positive-cost fits require strictly positive annual aggregate costs.")
  safe <- function(log_par, density) {
    ll <- density(exp(log_par))
    if (any(!is.finite(ll))) 1e100 else -sum(ll)
  }
  fits <- list(exponential = c(rate = 1/mean(x)),
    lognormal = c(meanlog = mean(log(x)), sdlog = sqrt(mean((log(x)-mean(log(x)))^2))))
  gamma <- optim(log(c(mean(x)^2/var(x), mean(x)/var(x))), safe,
                 density = function(p) dgamma(x, shape=p[1], rate=p[2], log=TRUE), method="L-BFGS-B",lower=c(-12,-30),upper=c(12,30))
  weibull <- optim(log(c(1, mean(x))), safe,
                   density = function(p) dweibull(x, shape=p[1], scale=p[2], log=TRUE), method="L-BFGS-B",lower=c(-12,-30),upper=c(12,30))
  lomax <- optim(log(c(1.5, mean(x)/2)), safe,
                 density = function(p) log(p[1])-log(p[2])-(p[1]+1)*log1p(x/p[2]), method="L-BFGS-B",lower=c(-12,-30),upper=c(12,30))
  if (any(c(gamma$convergence, weibull$convergence, lomax$convergence) != 0)) stop("A marginal MLE did not converge.")
  fits$gamma <- setNames(exp(gamma$par), c("shape","rate"))
  fits$weibull <- setNames(exp(weibull$par), c("shape","scale"))
  fits$lomax <- setNames(exp(lomax$par), c("shape","scale"))
  fits
}

log_density <- function(x, name, p) {
  switch(name, exponential = dexp(x, rate=p[1], log=TRUE),
    lognormal = dlnorm(x, meanlog=p[1], sdlog=p[2], log=TRUE),
    gamma = dgamma(x, shape=p[1], rate=p[2], log=TRUE),
    weibull = dweibull(x, shape=p[1], scale=p[2], log=TRUE),
    lomax = log(p[1])-log(p[2])-(p[1]+1)*log1p(x/p[2]))
}

model_cdf <- function(x, name, p) {
  switch(name, exponential = pexp(x, rate=p[1]),
    lognormal = plnorm(x, meanlog=p[1], sdlog=p[2]),
    gamma = pgamma(x, shape=p[1], rate=p[2]),
    weibull = pweibull(x, shape=p[1], scale=p[2]),
    lomax = -expm1(-p[1]*log1p(x/p[2])))
}
