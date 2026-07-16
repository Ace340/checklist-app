# Completion state is derived from logs, not stored on duties

A duty's "done" state is not a boolean on the duty itself — it is derived from completion logs. "Done for today" means a `CompletionLog` exists for that duty within the **current business day**; "done this week" (for weekly duties) means a log exists within the **current Monday-start week**. Accordingly, `TaskItem.isCompleted` and `TaskItem.completedAt` are removed from the model.

This is what makes "reset" possible. The business day does not end at midnight — closings land anywhere from 11pm to 2am depending on traffic — so a business day is ended by an explicit **"finish day"** action that closes the current day and opens the next. Because state is derived, finishing the day costs nothing: the new business day simply has no logs yet, so every duty reads as undone automatically, while every previous day's history stays intact forever in the logs. A completion is attributed to the business day it occurred in (a log written at 1:30am Sunday belongs to Saturday's business day), so business-day membership cannot be derived from the log's wall-clock timestamp alone — a log must carry an explicit reference to the business day it belongs to.

## Rejected: a stored `isCompleted` boolean

The obvious path is a boolean on each duty, flipped back to `false` on reset. Rejected because it creates two competing sources of truth — the boolean versus the `CompletionLog` audit trail — that disagree across day boundaries, and flipping the boolean on reset destroys exactly the evidence of yesterday's work that the `CompletionLog` exists to preserve. Deriving state from the log we already keep collapses the two into a single source of truth and makes reset free.
