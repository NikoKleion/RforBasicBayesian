# bayesian_optimization.R
# THIS IS THE MAIN THING. it reads your excel dataset (the 9 settings + the area),
# runs Bayesian Optimization on it, and tells you the next settings to print so the
# area gets bigger. run it again every time you add a new print to the excel.
#
# it uses a Gaussian Process + Expected Improvement, which is the same method the
# rpubs tutorial walks through (rpubs.com/Argaadya/bayesian-optimization).
#
# you dont need any of the other scripts in this folder to use this. this one only
# needs your excel file.

# ================== THE ONE LINE YOU HAVE TO SET ==================
# point this at your excel dataset. forward slashes "/", not backslashes "\"
DATA_XLSX <- "C:/Users/Nikol/Downloads/Raw_Dataset.xlsx"
# =================================================================

# if R cant find the files, tell it which folder this script is in (delete the #):
# setwd("C:/Users/Nikol/printer-bo")   # <- CHANGE to wherever this folder is

# ---- a couple optional knobs, fine to leave alone ----
BOUNDS <- "bounds.csv"   # the settings + their allowed ranges
XI     <- 0.01           # exploration. bigger = riskier settings. 0.01 is fine
N_CAND <- 20000          # how many random combos it checks. more = slower
# -------------------------------------------------------

# need these two packages
for (p in c("readxl", "DiceKriging")) {
  if (!requireNamespace(p, quietly = TRUE)) {
    stop("run this once in the console: install.packages(c(\"readxl\", \"DiceKriging\"))")
  }
}
library(DiceKriging)

# read the settings + their ranges
bounds <- read.csv(BOUNDS, stringsAsFactors = FALSE)
bounds$integer <- as.logical(bounds$integer)

# read your excel. the column with "area" in its name is the output, the rest are settings
df <- as.data.frame(readxl::read_excel(DATA_XLSX))
# print(head(df))   # uncomment to see what got read in

area_col <- grep("area", names(df), ignore.case = TRUE)[1]
if (is.na(area_col)) stop("couldnt find an 'Output Area' column in the excel")

y <- suppressWarnings(as.numeric(df[[area_col]]))
X <- df[, -area_col, drop = FALSE]
if (ncol(X) != nrow(bounds)) {
  stop(sprintf("excel has %d setting columns but bounds.csv has %d, they need to match", ncol(X), nrow(bounds)))
}
names(X) <- bounds$name

# only keep prints that actually have an area filled in
keep <- !is.na(y)
X <- X[keep, , drop = FALSE]
y <- y[keep]

cat(sprintf("read %d print(s) from the excel. best area so far: %.2f mm^2\n",
            length(y), if (length(y)) max(y) else NA))

# bayesian optimization cant model 9 settings from one or two prints. it needs a few.
if (length(y) < 4) {
  stop(sprintf(paste0("only %d print(s) in the excel with an area. ",
       "add a few more rows (settings + their measured area) and run this again. ",
       "about 5+ prints is where it starts giving good suggestions."), length(y)))
}

# put every setting on a 0-1 scale so temp and layer height are comparable
normalize <- function(d) {
  as.data.frame(mapply(function(col, lo, hi) (col - lo) / (hi - lo),
                       d[bounds$name], bounds$lower, bounds$upper))
}
# round whole-number settings and keep everything inside its allowed range
snap <- function(d) {
  for (i in seq_len(nrow(bounds))) {
    v <- pmin(pmax(d[[bounds$name[i]]], bounds$lower[i]), bounds$upper[i])
    if (bounds$integer[i]) v <- round(v)
    d[[bounds$name[i]]] <- v
  }
  d
}
Xn <- normalize(X)

# the model. this is the "learns settings -> area" part. the nugget lets it deal
# with two prints not measuring exactly the same. if it struggles on little data
# it retries with a fixed tiny nugget so you still get an answer.
gp <- tryCatch(
  km(design = Xn, response = y, covtype = "matern5_2", nugget.estim = TRUE, control = list(trace = FALSE)),
  error = function(e) km(design = Xn, response = y, covtype = "matern5_2", nugget = 1e-6, control = list(trace = FALSE))
)
# gp <- km(design = Xn, response = y, covtype = "gauss", nugget.estim = TRUE)  # tried gauss, matern was better

# make a big pile of random legal setting combos and score them
cand <- as.data.frame(lapply(seq_len(nrow(bounds)), function(i) {
  v <- runif(N_CAND, bounds$lower[i], bounds$upper[i])
  if (bounds$integer[i]) v <- round(v)
  v
}))
names(cand) <- bounds$name

pr  <- predict(gp, newdata = normalize(cand), type = "UK", checkNames = FALSE)
mu  <- pr$mean   # models guess of the area
sdv <- pr$sd     # how unsure it is

# expected improvement: favors combos likely to beat your record, or that are worth a gamble
y_best <- max(y)
z  <- (mu - y_best - XI) / sdv
ei <- (mu - y_best - XI) * pnorm(z) + sdv * dnorm(z)
ei[sdv <= 0] <- 0

next_set  <- snap(cand[which.max(ei), , drop = FALSE])   # print this next
pred_best <- snap(cand[which.max(mu), , drop = FALSE])    # the safe pick, for the very end

best_i   <- which.max(ei)
exp_area <- mu[best_i]          # what the model expects at the suggested settings
exp_sd   <- sdv[best_i]         # how unsure it is about that
stamp    <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

# ---- print to the console ----
show <- function(d) for (nm in bounds$name) cat(sprintf("  %-28s %s\n", nm, format(d[[nm]])))

cat("\n=== PRINT THESE NEXT ===\n")
show(next_set)
cat(sprintf("\nmodel expects around %.1f mm^2 here (+/- %.1f)\n", exp_area, exp_sd))

cat("\n--- only for the very end, when nothing improves anymore ---\n")
cat("plain best guess, no experimenting:\n")
show(pred_best)
cat(sprintf("predicts around %.1f mm^2\n\n", max(mu)))

# ---- output file 1: a readable summary of THIS run (overwritten each time) ----
txt <- c(
  "BAYESIAN OPTIMIZATION - next print suggestion",
  paste("run on:", stamp),
  sprintf("based on %d measured prints. best area so far: %.2f mm^2", length(y), y_best),
  "",
  "PRINT THESE SETTINGS NEXT:",
  sprintf("  %-28s %s", bounds$name, format(as.numeric(unlist(next_set[1, bounds$name])))),
  "",
  sprintf("the model expects about %.1f mm^2 here, give or take %.1f", exp_area, exp_sd),
  "",
  "final-answer pick (best guess, no experimenting) - use once nothing improves:",
  sprintf("  %-28s %s", bounds$name, format(as.numeric(unlist(pred_best[1, bounds$name])))),
  sprintf("predicts about %.1f mm^2", max(mu))
)
writeLines(txt, "bo_suggestion.txt")

# ---- output file 2: a running log, one row added every run, tracks your progress ----
log_row <- data.frame(run_time = stamp, prints_used = length(y),
                      best_area_so_far = round(y_best, 3),
                      predicted_area = round(exp_area, 3),
                      predicted_sd = round(exp_sd, 3), stringsAsFactors = FALSE)
for (nm in bounds$name) log_row[[nm]] <- as.numeric(next_set[[nm]])   # the settings it suggested
log_file <- "bo_history.csv"
write.table(log_row, log_file, sep = ",", append = file.exists(log_file),
            col.names = !file.exists(log_file), row.names = FALSE)

# ---- output file 3: just the suggested settings on their own, easy to copy ----
write.csv(next_set, "next_settings.csv", row.names = FALSE)

cat("saved 3 files in this folder:\n")
cat("  bo_suggestion.txt  - readable summary of this suggestion\n")
cat("  bo_history.csv     - running log, one row per run, tracks the best area over time\n")
cat("  next_settings.csv  - just the settings, easy to copy\n")
cat("print these settings, measure the area, add the row to the excel, then run this again.\n")
