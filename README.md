# 3D printer torture test - bayesian optimization

finds the best printer settings for the bridge test. you measure the area under
the bridge yourself (image it, plot the sag, integrate), and keep those areas +
the 9 settings that made each print in an excel file. this reads that excel and
uses bayesian optimization to tell you what settings to print next so the area
gets as big as possible. bigger area = flatter bridge = better print.

its a loop: it suggests settings -> you print + measure -> you add the row to the
excel -> run it again. keep going till the area stops going up.

## setup (once)

install the two packages. in the rstudio console (bottom left panel) type:

```r
install.packages(c("readxl", "DiceKriging"))
```

if it asks for a "mirror" just pick the top one. lots of red text is normal.

## running it

1. put your data in Raw_Dataset.xlsx. one row per print: the 9 settings, then the
   area in the last column. keep the headers how they are. blank area = that row
   gets skipped, so half finished rows are fine.

2. open bayesian_optimization.R and check this line near the top points at your
   excel (forward slashes, not backslashes):

   ```r
   DATA_XLSX <- "C:/Users/Nikol/Downloads/Raw_Dataset.xlsx"
   ```

3. run it. in the console:

   ```r
   setwd("C:/Users/Nikol/printer-bo")   # first time only, tells R the folder
   source("bayesian_optimization.R")
   ```

it prints a PRINT THESE NEXT block and writes the output files (below). print
those settings, measure the area, add the row to the excel, run it again. when
the suggestions stop beating your best, it also prints a "plain best guess" set at
the bottom, thats your final answer.

heads up: it cant do anything with just 1 or 2 prints. it needs like 5+ before the
suggestions mean anything. if theres not enough it'll just tell you to add more.

## the output (lands in the printer-bo folder)

- **bo_suggestion.txt** - readable summary of the last run. settings to print
  next + what area the model expects + the final-answer pick.
- **bo_history.csv** - a log, one row every time you run it. tracks the best area
  over the trials. this is the one to pull results/plots from.
- **next_settings.csv** - just the suggested settings, easy to copy.

## the knobs

everything you'd touch is in bounds.csv or in the marked block at the top of the
script. in the script look for the `# <- CHANGE` tags.

- **bounds.csv** - the 9 settings and the min/max to try for each. rows have to be
  in the same order as the columns in the excel. `integer` col is 1 for whole
  numbers (temp, speed), 0 for decimals (layer height). if it suggests something
  your printer cant do, fix the range here.
- **DATA_XLSX** (in the script) - where your excel is.
- **XI** (in the script) - how bold it is. bigger = riskier settings. 0.01 is fine.
- **N_CAND** (in the script) - how many combos it checks. more = slower.

## files

- **bayesian_optimization.R** - the thing you run.
- **Raw_Dataset.xlsx** - your data.
- **bounds.csv** - settings + ranges.
- output files get written each run, see above.

## notes

- the excel is the source of truth, just keep adding rows and it always reads the
  latest.
- infill density is a fraction, 0.2 = 20%.
- each print is expensive so this is built to get a good answer in like 15-25
  prints, not hundreds. thats the whole point of doing it this way.
