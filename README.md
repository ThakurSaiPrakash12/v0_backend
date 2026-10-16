# Khel Club Tournament Management System — Walkover Support

This update adds support for recording a Walkover in a match. A referee can select the winning team, and the result is saved in the database and displayed in the tournament fixtures.

## 1. How scoring currently works

The referee enters the scores from the match screen in `src/screen/referee/match/Match.js`. The frontend sends the score to the backend through `POST /update-score`, which is handled in `routes/score/score_core.py`.

The backend parses the submitted score and saves the values against the two teams in the `Score` table. When the referee finalizes a match, the backend compares the scores and sets `winner_team_id` to the winning team's ID. It also marks the match as final.

The frontend uses `POST /update-match-status/` to update the match status when needed. The fixtures page gets the match details from `GET /get-match-fixtures`, which returns information such as the teams, round, pool, status, winner, and result.

For knockout matches, `update_successor_match()` assigns the winning team to the appropriate slot in the next match using the predecessor references. The backend also uses Socket.IO events on the `/scores` namespace to send score updates to connected clients, including the match overlay.

## 2. Walkover implementation

### Backend changes

I added an `outcome` column to the `Match` model in `models.py`:

\`\`\`python
outcome = db.Column(db.String(30), nullable=True, default=None)
\`\`\`

This keeps the match outcome separate from the numeric scores. A Walkover can now be stored as `walkover` without assigning an artificial score such as `11-0`.

The new endpoint is:

`POST /matches/<match_id>/walkover`

It accepts the tournament ID and the winning team's ID. Before recording the result, the backend checks that the required fields are present, the match exists, both teams are assigned, and the selected winner belongs to that match.

Once validated, the match is marked with:

- `outcome = 'walkover'`
- `status = 'completed'`
- `is_final = True`
- `winner_team_id` set to the selected team

The route also handles bracket progression when the match has a successor. The result is committed to the database, and a Socket.IO event is sent so connected clients can receive the update.

I also updated the `/score/match` response to include `outcome`. This allows the referee screen to retrieve the saved outcome when the match is opened again.

### Successor match handling

The existing successor update logic created score entries whenever both teams were assigned. I changed it to check whether a score entry already exists for each team before inserting one. This helps prevent duplicate records when the successor update is called more than once.

The helper now supports an `auto_commit` option so a route can control the transaction when it needs to save the match result and bracket update together.

### Frontend changes

The referee match screen includes a Walkover action with a confirmation dialog. The referee selects the winning team and confirms the result.

The referee fixtures display a Walkover badge and highlight the winning team. The public tournament fixtures should provide the same indication so that spectators can identify matches decided by Walkover.

The fixture data mapping also needs to preserve the `outcome` and `winner_team_id` fields so the correct result is displayed.

## 3. Database changes

The new `outcome` field must exist in MySQL before running the updated backend. The original database dump does not include this column.

The migration script is located at:

`migrations/001_add_outcome_column.sql`

Its SQL is:

\`\`\`sql
ALTER TABLE \`match\`
ADD COLUMN \`outcome\` VARCHAR(30) NULL DEFAULT NULL
AFTER \`winner_team_id\`;
\`\`\`

### Setting up the database

First, import the provided SQL dump into the database you intend to use:

\`\`\`bash
mysql -u <user> -p <database_name> < dump-test-202512221924.sql
\`\`\`

Then apply the migration:

\`\`\`bash
mysql -u <user> -p <database_name> < migrations/001_add_outcome_column.sql
\`\`\`

Run these commands from the directory containing the relevant files, or provide the correct file paths.

To check that the column exists and inspect recorded outcomes, run:

\`\`\`sql
SHOW COLUMNS FROM \`match\` LIKE 'outcome';

SELECT id, match_name, winner_team_id, outcome, status, is_final
FROM \`match\`
WHERE outcome IS NOT NULL;
\`\`\`

Apply the migration once to a database that does not already contain the column. If the column is already present, check the schema before running the migration again.

## 4. Assumptions

The implementation follows these rules:

1. Both teams must be assigned before a Walkover can be recorded.
2. The selected winner must be one of the teams in the match.
3. Recording a Walkover completes and finalizes the match.
4. A Walkover is stored as an outcome rather than an invented numeric score.
5. Completed matches should not be modified accidentally.
6. A Walkover and a bye are different situations. A Walkover is recorded for a match with two assigned teams; a bye generally means a team advances without playing an opponent.

## 5. Possible improvements

There are a few areas that could be developed further:

- **Support more outcomes:** A shared outcome-handling endpoint could support Walkovers, forfeits, and byes without duplicating the same validation logic.
- **Keep a result history:** Store who changed a result, when it was changed, and why. This would make corrections easier to review.
- **Improve the match overlay:** Show a dedicated Walkover message instead of relying only on the score display.
- **Test bracket progression:** Add automated tests for advancing winners through a knockout bracket, including cases where a Walkover decides the match.
- **Add a reset workflow:** Provide an authorized way to correct a result entered by mistake, including any necessary changes to successor matches.
- **Improve integration testing:** Test the API, database migration, and frontend together using an isolated test database.

The main goal of this change is to support Walkovers without disrupting normal scoring or treating a Walkover as a regular scored match.