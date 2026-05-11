set.seed(42)

sample_size <- 200
x <- seq(0, 100, length.out = sample_size)
y <- 2 * x + stats::rnorm(sample_size, mean = 0, sd = 8)

training_data <- data.frame(x = x, y = y)
model <- stats::lm(y ~ x, data = training_data)

saveRDS(model, file = "model.rds")

cat("Saved trained model to model.rds\n")
cat("Training rows:", nrow(training_data), "\n")
print(summary(model))
