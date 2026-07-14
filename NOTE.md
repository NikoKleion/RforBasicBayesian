# Note from Niko

Hey Noah,

Quick heads up before you run this, its important.

Right now the Excel (Raw_Dataset.xlsx) only has the one baseline print in it, the
182.93 one. Bayesian optimization genuinely can't suggest anything off a single
print. Its trying to work out how all 9 settings push the area around, and one row
tells it basically nothing about 9 knobs. It needs a handful first, like 5 or more
prints, before the suggestions actually mean anything. If you run it now it'll just
stop and tell you to add more data.

So just keep adding your measured trials into Raw_Dataset.xlsx, one row each (the
9 settings + the area). Once there are about 5 or more prints in there, run
bayesian_optimization.R and it'll start suggesting settings.

After that its just the loop: run bayesian_optimization.R, it tells you what to
print next, you print it + measure the area + add the row to the Excel, then run it
again. Keep going until the area stops climbing. The README has the full walk
through.

- Niko
