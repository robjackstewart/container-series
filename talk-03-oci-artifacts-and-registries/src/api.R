library(plumber)

model_path <- Sys.getenv("MODEL_PATH", unset = "model.rds")

load_model <- function(path) {
  tryCatch(readRDS(path), error = function(e) NULL)
}

model <- load_model(model_path)

model_metadata <- function(model_object) {
  summary_object <- summary(model_object)

  list(
    formula = Reduce(paste, deparse(formula(model_object))),
    coefficients = as.list(coef(model_object)),
    sigma = unname(summary_object$sigma),
    r_squared = unname(summary_object$r.squared),
    adjusted_r_squared = unname(summary_object$adj.r.squared),
    observations = stats::nobs(model_object),
    generated_from = model_path
  )
}

#* Health endpoint
#* @get /health
function() {
  list(
    status = if (is.null(model)) "degraded" else "ok",
    model_loaded = !is.null(model),
    model_path = model_path,
    timestamp = format(Sys.time(), tz = "UTC", usetz = TRUE)
  )
}

#* Model metadata endpoint
#* @get /model-info
function(res) {
  if (is.null(model)) {
    res$status <- 503
    return(list(
      error = "Model not available. Run train_model.R to generate model.rds.",
      model_path = model_path
    ))
  }

  model_metadata(model)
}

#* Prediction endpoint
#* @param value Numeric value to score with the linear model.
#* @get /predict
function(value = NULL, res) {
  if (is.null(model)) {
    res$status <- 503
    return(list(
      error = "Model not available. Run train_model.R to generate model.rds.",
      model_path = model_path
    ))
  }

  if (is.null(value) || identical(value, "")) {
    res$status <- 400
    return(list(error = "Query parameter 'value' is required, for example /predict?value=12.5"))
  }

  numeric_value <- suppressWarnings(as.numeric(value))
  if (is.na(numeric_value)) {
    res$status <- 400
    return(list(error = "Query parameter 'value' must be numeric."))
  }

  prediction <- tryCatch(
    stats::predict(model, newdata = data.frame(x = numeric_value)),
    error = function(e) e
  )

  if (inherits(prediction, "error")) {
    res$status <- 500
    return(list(error = paste("Prediction failed:", conditionMessage(prediction))))
  }

  list(
    input = numeric_value,
    prediction = unname(as.numeric(prediction)),
    model = "linear-regression",
    timestamp = format(Sys.time(), tz = "UTC", usetz = TRUE)
  )
}
