rank_metrics <- function(y, probability) {
  if (length(y) != length(probability) || any(!is.finite(probability)) || any(probability < 0 | probability > 1)) {
    stop("One finite probability in [0,1] is required per observation.")
  }
  if (!all(y %in% 0:1) || length(unique(y)) != 2) stop("Both binary classes are required.")
  n1 <- sum(y == 1); n0 <- sum(y == 0)
  auc <- (sum(rank(probability, ties.method = "average")[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
  order_p <- order(probability, decreasing = TRUE)
  p <- probability[order_p]; ys <- y[order_p]
  ends <- c(which(diff(p) != 0), length(p))
  tp <- cumsum(ys)[ends]; fp <- ends - tp
  recall <- tp / n1; precision <- tp / ends
  ap <- sum(diff(c(0, recall)) * precision)
  list(auc = auc, average_precision = ap,
       curve = data.frame(threshold = p[ends], recall = recall, precision = precision, false_positive_rate = fp / n0))
}

f1_threshold <- function(y, probability) {
  curve <- rank_metrics(y, probability)$curve
  f1 <- 2 * curve$precision * curve$recall / pmax(curve$precision + curve$recall, 1e-15)
  curve$threshold[which.max(f1)]
}

classification_metrics <- function(y, probability, threshold) {
  p <- pmin(pmax(probability, 1e-12), 1 - 1e-12)
  prediction <- as.integer(probability >= threshold)
  tp <- sum(y == 1 & prediction == 1); fp <- sum(y == 0 & prediction == 1)
  tn <- sum(y == 0 & prediction == 0); fn <- sum(y == 1 & prediction == 0)
  rank <- rank_metrics(y, probability)
  c(auc = rank$auc, average_precision = rank$average_precision,
    brier = mean((y - p)^2), log_loss = -mean(y * log(p) + (1-y) * log1p(-p)),
    accuracy = mean(y == prediction), balanced_accuracy = (tp/(tp+fn) + tn/(tn+fp))/2,
    precision = if (tp + fp > 0) tp/(tp+fp) else 0, recall = tp/(tp+fn),
    f1 = 2*tp / (2*tp+fp+fn), threshold = threshold, tp = tp, fp = fp, tn = tn, fn = fn)
}

cost_metrics <- function(y, prediction, positive_only = FALSE) {
  prediction <- pmax(prediction, 1e-10)
  result <- c(mae = mean(abs(y-prediction)), rmse = sqrt(mean((y-prediction)^2)),
              mean_observed = mean(y), mean_predicted = mean(prediction))
  if (positive_only) result <- c(result, mean_gamma_deviance = mean(2*((y-prediction)/prediction - log(y/prediction))))
  result
}
