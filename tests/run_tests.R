source("R/data.R"); source("R/metrics.R"); source("R/distributions.R")
near <- function(x,y,tol=1e-9) stopifnot(abs(x-y)<tol)
# Known ranking, ties and threshold behavior.
near(rank_metrics(c(0,0,1,1),c(.1,.2,.8,.9))$auc,1)
near(rank_metrics(c(0,1,0,1),rep(.5,4))$auc,.5)
near(rank_metrics(c(0,1,0,1),rep(.5,4))$average_precision,.5)
near(f1_threshold(c(0,0,1,1),c(.1,.2,.6,.8)),.6)
near(cost_metrics(c(2,5),c(2,5),TRUE)[["mean_gamma_deviance"]],0)
# A policy first observed in train or validation cannot reappear in test.
fake <- data.frame(ID=c(1,1,2,2,3),renewal_year=c(2016,2017,2017,2018,2018))
parts <- policy_split(fake)
stopifnot(identical(parts$train,1L),identical(parts$validation,3L),identical(parts$test,5L))
for(a in c("train","validation")) stopifnot(!any(fake$ID[parts[[a]]] %in% fake$ID[parts$test]))
# Imputation may not see held-out values.
fake_features <- as.data.frame(setNames(rep(list(c(1,3,NA,10000)),4),
  c("age_decades","experience_decades","vehicle_age","log_power")))
imputed <- impute_from_training(fake_features,1:3)
near(imputed$data$vehicle_age[3],2)
# MLE parameters actually normalize the same PMF used in diagnostics.
fit <- fit_counts(c(rep(0,60),rep(1,20),rep(2,10),rep(4,10)))
near(fit$mean[1],.8)
near(sum(dnbinom(0:10000,size=fit$size[2],mu=fit$mean[2])),1,1e-7)
stopifnot(inherits(try(validate_formula(claim ~ Value_vehicle),silent=TRUE),"try-error"))
stopifnot(inherits(try(validate_formula(claim ~ N_claims_year),silent=TRUE),"try-error"))
validate_formula(claim ~ age_decades + log_power)
cat("All insurance protocol, predictor-availability and metric checks passed.\n")
