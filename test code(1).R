# Load the data
rm(list = ls())
library(glmnet)
data <- read.csv("./birpanel.csv")
data$stateres <- as.factor(data$stateres)
data$mplbir <- as.factor(data$mplbir)
data$year <- as.factor(data$year)
#cigar has na
data$cigar[data$cigar == 99] <- NA
a=mean(data$cigar[-which(is.na(data$cigar))])
data$cigar[which(is.na(data$cigar))]<-a
#set dummy
install.packages('fastDummies')
library('fastDummies')
data <- dummy_cols(data, select_columns = c('stateres', 'mplbir','year'))
data=data[,-c(1,2,3,6,13)]

## moving forward selection
dat=data
library(leaps)
# we can write a function to help us calculate the predicted value
predict.regsubsets=function(object,newdata,id,...){
  form=as.formula(object$call[[2]])
  mat=model.matrix(form,newdata)
  coefi=coef(object,id=id)
  xvars=names(coefi)
  mat[,xvars]%*%coefi
}

k=5
set.seed(123)
folds=sample(1:k,nrow(dat),replace=TRUE) # this divides the sample into 5 folds
cv.errors=matrix(NA,k,125, dimnames=list(NULL, paste(1:125)))
cv.errors

for(j in 1:k){
  best.fit=regsubsets(dbirwt~.,data=dat[folds!=j,],nvmax=125,method="forward")
  for(i in 1:125){
    pred=predict(best.fit,dat[folds==j,],id=i)
    cv.errors[j,i]=mean( (dat$dbirwt[folds==j]-pred)^2)
  }
}
cv.errors
mean.cv.errors=apply(cv.errors,2,mean)
mean.cv.errors
par(mfrow=c(1,1))
plot(mean.cv.errors,type='b')
reg.fwd=regsubsets(dbirwt~.,data=dat,nvmax=125,method="forward")
coef(reg.fwd,124)



##lasso
dat=data
lambdas <- seq(0, 5, length.out = 500)
X <- as.matrix(dat[,-c(5)])
Y <- dat[,c(5)]
set.seed(123)
lasso_model <- cv.glmnet(X, Y, alpha = 1, lambda = lambdas)
plot(lasso_model)
plot(lasso_model$glmnet.fit, "lambda", label = TRUE)
lasso_lse <- lasso_model$lambda.1se
lasso_best <- glmnet(X, Y, alpha = 1, lambda = lasso_lse)
coef.df <- data.frame(variable = rownames(coef(lasso_best)), 
                      coef = as.numeric(coef(lasso_best)))
coef.df[coef.df$coef != 0, ]
coef.df[coef.df$coef == 0, ]

## IV
dat=data
#delete the smoke，hsgrad
dat <- subset(dat, select = -c(smoke, hsgrad))
summary(dat)


#set iv
iv <- dat$dmeduc
# set endogenous explanatory variable
en <- dat$cigar
# set y
y <- dat$dbirwt

#method 1
#Durbin-Wu-Hausman test
install.packages("aod")
library(aod)
fit1 <- lm(en ~ iv + dat$male + dat$gestat  + dat$agesq + dat$black)
fit2 <- lm(y ~ en + iv + dat$male + dat$gestat + dat$agesq + dat$black)
install.packages("tseries")
library(tseries)
install.packages("lmtest")
library(lmtest)
#dwtest(fit2, fit1, alternative="greater")
str(dat)
# IV estimate
install.packages("ivpack")
library(ivpack)
iviv.fit <- ivivreg(y ~ en | iv, data=dat, method="B2SLS")
summary(iviv.fit)

install.packages("ivpack")
write.csv(dat, file = "dat.csv", row.names = FALSE)
install.packages("haven")
library(haven)
write_dta(dat, "98765.dta")


# fit IV model
library(lmtest)
ivreg_fit <- ivreg(dbirwt ~ cigar | dmeduc, data = dat)
summary(ivreg_fit)

#  Durbin-Wu-Hausman 
ivreg_test <- ivreg(dbirwt ~ cigar | dmeduc, data = dat)
ols_fit <- lm(dbirwt ~ cigar, data = dat)
dwtest(ols_fit, ivreg_test, alternative = "greater")


# method 2
install.packages("AER")
library(AER) 
ivreg <- iv2sls(formula = dbirwt ~ cigar | dmeduc ~ mplbir + agesq + black + adeqcode2 + adeqcode3 + novisit + pretri2 + pretri3 + male + year + married + somecoll + collgrad,
                data = data)
summary(ivreg) 



