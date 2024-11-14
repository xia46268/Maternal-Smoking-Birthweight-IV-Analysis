# Load the necessary libraries
rm(list = ls())
library(glmnet)
library(fastDummies)
library(leaps)
library(aod)
library(tseries)
library(lmtest)
library(ivpack)
library(haven)
library(AER)

# 1. Data Loading and Preprocessing -----------------------------------------
data <- read.csv("./birpanel.csv")

# Convert variables to factors
data$stateres <- as.factor(data$stateres)
data$mplbir <- as.factor(data$mplbir)
data$year <- as.factor(data$year)

# Handle missing values in 'cigar'
data$cigar[data$cigar == 99] <- NA
mean_cigar <- mean(data$cigar, na.rm = TRUE)
data$cigar[is.na(data$cigar)] <- mean_cigar

# Create dummy variables for categorical columns
data <- dummy_cols(data, select_columns = c('stateres', 'mplbir', 'year'))
data <- data[ , -c(1, 2, 3, 6, 13)]  # Remove ID and redundant columns

# 2. Moving Forward Selection ----------------------------------------------
dat <- data

predict.regsubsets <- function(object, newdata, id, ...) {
  form <- as.formula(object$call[[2]])
  mat <- model.matrix(form, newdata)
  coefi <- coef(object, id = id)
  xvars <- names(coefi)
  mat[, xvars] %*% coefi
}

set.seed(123)
k <- 5
folds <- sample(1:k, nrow(dat), replace = TRUE)
cv.errors <- matrix(NA, k, 125, dimnames = list(NULL, paste(1:125)))

for (j in 1:k) {
  best.fit <- regsubsets(dbirwt ~ ., data = dat[folds != j, ], nvmax = 125, method = "forward")
  for (i in 1:125) {
    pred <- predict(best.fit, dat[folds == j, ], id = i)
    cv.errors[j, i] <- mean((dat$dbirwt[folds == j] - pred)^2)
  }
}

mean.cv.errors <- apply(cv.errors, 2, mean)
plot(mean.cv.errors, type = 'b', main = "Cross-Validation Errors", xlab = "Number of Variables", ylab = "CV Error")
reg.fwd <- regsubsets(dbirwt ~ ., data = dat, nvmax = 125, method = "forward")
coef(reg.fwd, 124)

# 3. LASSO Model ------------------------------------------------------------
lambdas <- seq(0, 5, length.out = 500)
X <- as.matrix(dat[ , -5])
Y <- dat$dbirwt

set.seed(123)
lasso_model <- cv.glmnet(X, Y, alpha = 1, lambda = lambdas)
plot(lasso_model, main = "LASSO Model")
plot(lasso_model$glmnet.fit, "lambda", label = TRUE, main = "Coefficients vs Lambda")

lasso_lse <- lasso_model$lambda.1se
lasso_best <- glmnet(X, Y, alpha = 1, lambda = lasso_lse)
coef.df <- data.frame(variable = rownames(coef(lasso_best)), coef = as.numeric(coef(lasso_best)))
non_zero_coef <- coef.df[coef.df$coef != 0, ]

# 4. IV Regression Analysis -------------------------------------------------
# Prepare data for IV analysis
dat <- subset(dat, select = -c(smoke, hsgrad))

# First-stage regression
fit1 <- lm(cigar ~ dmeduc + male + gestat + agesq + black, data = dat)
fit2 <- lm(dbirwt ~ cigar + dmeduc + male + gestat + agesq + black, data = dat)

# IV regression using ivreg from 'AER' package
ivreg_fit <- ivreg(dbirwt ~ cigar | dmeduc, data = dat)
summary(ivreg_fit)

# Durbin-Wu-Hausman Test
ols_fit <- lm(dbirwt ~ cigar, data = dat)
dwtest(ols_fit, ivreg_fit, alternative = "greater")

# Save processed data for further use
write.csv(dat, file = "dat.csv", row.names = FALSE)
write_dta(dat, "processed_data.dta")
